import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('SessionDiagnostics');

/// Why the app treats an account's session as ended.
enum SessionEndCause {
  /// 16002: the server does not know the refresh token (any more).
  refreshRejected,

  /// 16003: the session was idle longer than the server allows.
  sessionExpired,

  accountDisabled,
  accountLocked,

  /// Secure storage held no tokens for the account.
  missingTokens,

  /// Secure storage refused to read the account's tokens at app starts
  /// for longer than a day without a good read in between.
  storageUnreadable,

  /// A sign-out retired the session on this device but could not remove
  /// the account.
  signOutFailed,

  /// A guest's share is gone: deleted, never there, or link sharing off.
  shareGone,

  /// A guest's share asked for a password the app did not have, or for
  /// the right one.
  sharePasswordNeeded;

  static SessionEndCause of(SessionEndReason reason) => switch (reason) {
    SessionEndReason.invalidRefreshToken => refreshRejected,
    SessionEndReason.linkShareGone => shareGone,
    SessionEndReason.expired => sessionExpired,
    SessionEndReason.accountDisabled => accountDisabled,
    SessionEndReason.accountLocked => accountLocked,
  };

  /// This device ended the session, not the server.
  bool get onDevice => switch (this) {
    missingTokens || storageUnreadable || signOutFailed => true,
    refreshRejected ||
    sessionExpired ||
    accountDisabled ||
    accountLocked ||
    shareGone ||
    sharePasswordNeeded => false,
  };
}

/// What became of an ended session.
enum SessionEndResolution {
  /// The sign-in that replaced it found the old tokens still working: the
  /// app had ended a session that was alive.
  wasAlive,

  /// The server refused the old refresh token but still listed its
  /// session: the answer to a refresh was lost, or storage lost the
  /// rotated tokens. The orphan was revoked.
  orphanRevoked,

  /// The server refused the old token and no longer had its session: it
  /// was deleted there, or it expired.
  goneOnServer,

  /// No old tokens were left on the device.
  noTokens,

  /// The checks could not reach a verdict (offline, no session id, old
  /// tokens that could not be read).
  unknown,

  /// The stored tokens worked again without a new sign-in
  /// (`SessionManagers.tryRestore`).
  restored,
}

/// What is known about the refresh token an account last sent: the
/// earliest send whose answer was never stored, when the server may have
/// rotated it (`sentAt`, by `sentBy`), and when the server refused it.
typedef RefreshMarker = ({
  String token,
  DateTime? sentAt,
  AppPart? sentBy,
  DateTime? refusedAt,
});

/// The last ended session of an account, without secrets: tokens appear
/// only as a [tokenFingerprint]. The support details keep their own,
/// shorter record (`SessionEndLog`).
@immutable
final class SessionEndDiagnosis {
  const new({
    required this.at,
    required this.cause,
    required this.part,
    this.code,
    this.failedToken,
    this.rotatedAwayToken,
    this.lostRefreshAt,
    this.lostRefreshPart,
    this.resolution,
  });

  final DateTime at;
  final SessionEndCause cause;
  final AppPart part;
  final int? code;

  /// The fingerprint of the refresh token the server refused or that was
  /// missing.
  final String? failedToken;

  /// The fingerprint of the refresh token storage still held when the
  /// session ended, although a refresh had rotated it away: its successor
  /// could not be stored. The server refuses it as well.
  final String? rotatedAwayToken;

  /// When a refresh with [failedToken] had been sent without its answer
  /// ever being stored, and by which part of the app: the server most
  /// likely rotated it then.
  final DateTime? lostRefreshAt;
  final AppPart? lostRefreshPart;

  final SessionEndResolution? resolution;

  SessionEndDiagnosis resolved(SessionEndResolution resolution) =>
      SessionEndDiagnosis(
        at: at,
        cause: cause,
        part: part,
        code: code,
        failedToken: failedToken,
        rotatedAwayToken: rotatedAwayToken,
        lostRefreshAt: lostRefreshAt,
        lostRefreshPart: lostRefreshPart,
        resolution: resolution,
      );

  Map<String, Object?> toJson() => {
    'at': _iso(at),
    'cause': cause.name,
    'part': part.name,
    'code': ?code,
    'failedToken': ?failedToken,
    'rotatedAwayToken': ?rotatedAwayToken,
    if (lostRefreshAt case final lost?) 'lostRefreshAt': _iso(lost),
    'lostRefreshPart': ?lostRefreshPart?.name,
    'resolution': ?resolution?.name,
  };

  static SessionEndDiagnosis? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      if (jsonDecode(raw)
          case {
                'at': final String at,
                'cause': final String cause,
                'part': final String part,
              } &&
              final Map<String, Object?> json) {
        final parsedAt = _parse(at);
        final parsedCause = SessionEndCause.values.asNameMap()[cause];
        final parsedPart = AppPart.values.asNameMap()[part];
        if (parsedAt == null || parsedCause == null || parsedPart == null) {
          return null;
        }
        return SessionEndDiagnosis(
          at: parsedAt,
          cause: parsedCause,
          part: parsedPart,
          code: json['code'] as int?,
          failedToken: json['failedToken'] as String?,
          rotatedAwayToken: json['rotatedAwayToken'] as String?,
          lostRefreshAt: _parse(json['lostRefreshAt'] as String?),
          lostRefreshPart: AppPart.values.asNameMap()[json['lostRefreshPart']],
          resolution: SessionEndResolution.values
              .asNameMap()[json['resolution']],
        );
      }
    } on Object {
      // Falls through: an unreadable record counts as none.
    }
    return null;
  }
}

/// A short SHA-256 prefix of [token], to tell tokens apart in diagnostics
/// without keeping them.
String tokenFingerprint(String token) =>
    sha256.convert(utf8.encode(token)).toString().substring(0, 16);

/// Why sessions ended, kept in the preferences store, which every isolate
/// reads afresh, so that the next ended session can be explained from the
/// device. Never throws: diagnostics must not break what they observe.
///
/// With `accountExists` nothing is noted for an account that is not
/// registered (a registry that cannot be read counts as listing it), and a
/// note written while the account was signed out is taken back: the wiper
/// must find nothing to forget later, as account ids repeat.
final class SessionDiagnostics {
  new(this._store, {this._accountExists});

  static String endKey(String accountId) => 'session.end.$accountId';

  static String refreshInFlightKey(String accountId) =>
      'session.refresh_in_flight.$accountId';

  static String unreadableSinceKey(String accountId) =>
      'session.unreadable_since.$accountId';

  final PreferencesStore _store;
  final Future<bool> Function(String accountId)? _accountExists;

  // Only the app's start check notes failed reads, in the app's own
  // container, so a good read needs noting again only after one there.
  final _readableNoted = <String>{};

  Future<SessionEndDiagnosis?> lastEnd(String accountId) async =>
      SessionEndDiagnosis.tryParse(await _get(endKey(accountId)));

  /// Whether the account's end that no sign-in or restore has resolved yet
  /// happened on this device ([SessionEndCause.onDevice]).
  Future<bool> endedOnDevice(String accountId) async {
    final ended = await lastEnd(accountId);
    return ended != null && ended.resolution == null && ended.cause.onDevice;
  }

  Future<void> recordEnd(String accountId, SessionEndDiagnosis diagnosis) =>
      _setFor(accountId, endKey(accountId), jsonEncode(diagnosis.toJson()));

  Future<RefreshMarker?> refreshMarker(String accountId) async {
    final raw = await _get(refreshInFlightKey(accountId));
    if (raw == null) return null;
    try {
      if (jsonDecode(raw)
          case {'token': final String token} &&
              final Map<String, Object?> json) {
        final sentAt = _parse(json['sentAt'] as String?);
        final refusedAt = _parse(json['refusedAt'] as String?);
        if (sentAt == null && refusedAt == null) return null;
        return (
          token: token,
          sentAt: sentAt,
          sentBy: sentAt == null
              ? null
              : AppPart.values.asNameMap()[json['sentBy']],
          refusedAt: refusedAt,
        );
      }
    } on Object {
      // Falls through: an unreadable marker counts as none.
    }
    return null;
  }

  /// A refresh with [token] is about to be sent.
  Future<void> refreshSent(
    String accountId, {
    required String token,
    required AppPart part,
    required DateTime at,
  }) => _setMarker(accountId, (
    token: token,
    sentAt: at,
    sentBy: part,
    refusedAt: null,
  ));

  /// The server refused [token]; an earlier send whose answer was lost
  /// ([before]) stays named.
  Future<void> refreshRefused(
    String accountId, {
    required String token,
    required DateTime at,
    RefreshMarker? before,
  }) {
    final earlier = before?.token == token ? before : null;
    return _setMarker(accountId, (
      token: token,
      sentAt: earlier?.sentAt,
      sentBy: earlier?.sentBy,
      refusedAt: earlier?.refusedAt ?? at,
    ));
  }

  /// The answer for [token] is stored, or its send never reached the
  /// server. Another token's marker stays.
  Future<void> refreshSettled(String accountId, {required String token}) async {
    final marker = await refreshMarker(accountId);
    if (marker != null && marker.token != token) return;
    await _remove(refreshInFlightKey(accountId));
  }

  /// When secure storage first failed to read this account's tokens since
  /// the last good read; [at] is noted if none is yet.
  Future<DateTime?> noteUnreadable(String accountId, DateTime at) async {
    try {
      final since = _parse(await _get(unreadableSinceKey(accountId)));
      if (since != null) return since;
      await _setFor(accountId, unreadableSinceKey(accountId), _iso(at));
      return null;
    } finally {
      // Last, so that a good read noted while this ran is noted again.
      _readableNoted.remove(accountId);
    }
  }

  /// A good read of the account's tokens ends a run of failures; after the
  /// first, only one since a failed read costs a write.
  Future<void> noteReadable(String accountId) async {
    if (!_readableNoted.add(accountId)) return;
    if (!await _remove(unreadableSinceKey(accountId))) {
      _readableNoted.remove(accountId);
    }
  }

  /// Sign-out: the account's entries go with it.
  Future<void> forget(String accountId) async {
    await _remove(endKey(accountId));
    await _remove(refreshInFlightKey(accountId));
    await _remove(unreadableSinceKey(accountId));
  }

  Future<void> _setMarker(String accountId, RefreshMarker marker) => _setFor(
    accountId,
    refreshInFlightKey(accountId),
    jsonEncode({
      'token': marker.token,
      if (marker.sentAt case final sentAt?) 'sentAt': _iso(sentAt),
      'sentBy': ?marker.sentBy?.name,
      if (marker.refusedAt case final refusedAt?) 'refusedAt': _iso(refusedAt),
    }),
  );

  Future<void> _setFor(String accountId, String key, String value) async {
    // A registry that cannot be read once must not cost an end's record:
    // an older, resolved one would stand in for it.
    if (await _exists(accountId) == false) return;
    await _set(key, value);
    // Sign-out removes the account before the wiper forgets its notes, so
    // a note written in between is taken back here.
    if (await _exists(accountId) == false) await forget(accountId);
  }

  /// Null when the registry could not be read.
  Future<bool?> _exists(String accountId) async {
    final accountExists = _accountExists;
    if (accountExists == null) return true;
    try {
      return await accountExists(accountId);
    } on Object catch (error) {
      _log.info('Could not look up the account: ${error.runtimeType}');
      return null;
    }
  }

  Future<String?> _get(String key) async {
    try {
      return await _store.getString(key);
    } on Object catch (error) {
      _log.info('Could not read a session note: ${error.runtimeType}');
      return null;
    }
  }

  Future<void> _set(String key, String value) async {
    try {
      await _store.setString(key, value);
    } on Object catch (error) {
      _log.info('Could not write a session note: ${error.runtimeType}');
    }
  }

  Future<bool> _remove(String key) async {
    try {
      await _store.remove(key);
      return true;
    } on Object catch (error) {
      _log.info('Could not remove a session note: ${error.runtimeType}');
      return false;
    }
  }
}

String _iso(DateTime moment) => moment.toUtc().toIso8601String();

DateTime? _parse(String? raw) =>
    raw == null ? null : DateTime.tryParse(raw)?.toUtc();
