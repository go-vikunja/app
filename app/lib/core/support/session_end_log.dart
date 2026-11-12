import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'session_end_log.g.dart';

final _log = Logger('SessionEndLog');

/// The last end of each account's session, for the support details: why
/// and where it ended and when. Kept across a new sign-in, forgotten at
/// sign-out. Never the failure's message or code.
final class SessionEndLog {
  new(this._store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  static String keyFor(String accountId) => 'support.lastSessionEnd.$accountId';

  final PreferencesStore _store;
  final DateTime Function() _now;

  /// Never throws; a failure is logged with its type only.
  Future<void> record(
    String accountId,
    SessionEndReason reason, {
    required AppPart part,
  }) async {
    try {
      await _store.setString(
        keyFor(accountId),
        jsonEncode({
          'reason': reason.name,
          'part': part.name,
          'at': _now().toUtc().toIso8601String(),
        }),
      );
    } on Object catch (error) {
      _log.warning('Could not note a session end: ${error.runtimeType}');
    }
  }

  /// Null without one or for one it cannot read.
  Future<SessionEndRecord?> read(String accountId) async {
    final raw = await _store.getString(keyFor(accountId));
    if (raw == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded case {
      'reason': final String reason,
      'part': final String part,
      'at': final String at,
    }) {
      final when = DateTime.tryParse(at)?.toUtc();
      final reasonName = _name(reason);
      final partName = _name(part);
      if (when == null || reasonName.isEmpty || partName.isEmpty) return null;
      return SessionEndRecord(reason: reasonName, part: partName, at: when);
    }
    return null;
  }

  Future<void> forget(String accountId) => _store.remove(keyFor(accountId));

  static String _name(String raw) => raw.replaceAll(_notALetter, '');

  static final _notALetter = RegExp('[^a-zA-Z]');
}

@immutable
final class SessionEndRecord {
  const new({required this.reason, required this.part, required this.at});

  /// A [SessionEndReason] name, or a newer version's own, letters only.
  final String reason;

  /// An [AppPart] name, or a newer version's own, letters only.
  final String part;

  /// UTC.
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is SessionEndRecord &&
      other.reason == reason &&
      other.part == part &&
      other.at == at;

  @override
  int get hashCode => Object.hash(reason, part, at);

  @override
  String toString() => 'SessionEndRecord($reason, $part, $at)';
}

@Riverpod(keepAlive: true)
SessionEndLog sessionEndLog(Ref ref) => SessionEndLog(
  ref.watch(preferencesStoreProvider),
  now: ref.watch(clockProvider),
);

/// What a container's session managers and guest sessions hand an ended
/// session to: noted with this container's part, unless the account was
/// signed out meanwhile (the wiper must find nothing to forget later).
Future<void> Function(String accountId, SessionEnded failure)
sessionEndRecorder(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  final log = ref.watch(sessionEndLogProvider);
  final part = ref.watch(appPartProvider);
  return (accountId, failure) async {
    try {
      if (await registry.find(accountId) == null) return;
      await log.record(accountId, failure.reason, part: part);
      // Sign-out removes the account before the wiper forgets the record,
      // so a record written in between is caught here.
      if (await registry.find(accountId) == null) await log.forget(accountId);
    } on Object catch (error) {
      _log.warning('Could not note a session end: ${error.runtimeType}');
    }
  };
}
