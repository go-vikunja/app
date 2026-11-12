import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';

typedef LinkShareRenewal = Future<LinkShareToken> Function(String token);
typedef LinkShareAuthentication = Future<LinkShareAuth> Function(String hash);
typedef LinkShareEndedHandler = Future<void> Function(SessionEnded failure);

final _log = Logger('LinkShareSession');

/// Keeps a link-share guest's token valid, without a refresh token: the
/// token is renewed through `POST /user/token` once half of its lifetime
/// (72 h on a default server) has passed, and the old one stays valid, so
/// concurrent renewals are only de-duplicated. An expired token is replaced
/// by authenticating again with the stored hash, which shares the
/// sign-in limit of 10 requests a minute and IP: a 429 blocks it for its
/// `Retry-After`, and with `maxAuthentications` a short-lived isolate
/// tries it at most that often. A share that needs its password, or that
/// is gone, ends the session: the account needs the link opened again.
final class LinkShareSession implements AccessTokenSource {
  new({
    required this.accountId,
    required this._store,
    required this._renew,
    required this._authenticate,
    required this._onEnded,
    this._clock = DateTime.now,
    this._maxAuthentications,
  });

  /// A token with less left is not sent any more.
  static const expiryMargin = Duration(seconds: 60);

  /// After a renewal failed, the old token is used this long before the
  /// next try, so a server that keeps refusing costs no request per call.
  static const renewalBackoff = Duration(minutes: 5);
  static const maxRetryAfter = Duration(minutes: 10);

  /// `service.jwtttl` of a default server, for a token without `iat`.
  static const defaultLifetime = Duration(hours: 72);

  static const _passwordRequired = 13001;
  static const _wrongPassword = 13002;

  final String accountId;
  final LinkShareStore _store;
  final LinkShareRenewal _renew;
  final LinkShareAuthentication _authenticate;
  final LinkShareEndedHandler _onEnded;
  final DateTime Function() _clock;
  final int? _maxAuthentications;

  LinkShareToken? _token;
  Duration _serverClockOffset = Duration.zero;
  Future<LinkShareToken>? _renewing;
  Future<LinkShareToken>? _authenticating;
  Future<void>? _pendingWrite;
  DateTime? _renewalBlockedUntil;
  DateTime? _authenticationBlockedUntil;
  int _authentications = 0;
  SessionEnded? _ended;
  bool _retired = false;

  DateTime get _serverNow => _clock().add(_serverClockOffset);

  @override
  Future<String> validAccessToken() async {
    try {
      final token = await _current();
      if (token == null || _isExpired(token)) {
        return (await _authenticateOnce()).jwt;
      }
      if (!_pastHalfLife(token) || _renewalBlocked) return token.jwt;
      try {
        return (await _renewOnce(token)).jwt;
      } on SessionEnded {
        rethrow;
      } on VikunjaFailure catch (failure) {
        _log.info('Renewal of guest $accountId failed: $failure');
        if (_isExpired(token)) rethrow;
        return token.jwt;
      }
    } on _Retired {
      throw const SessionEnded(SessionEndReason.expired);
    }
  }

  /// A 401 code 11 comes from the server's token check, which renewal goes
  /// through too, so only a newer token or a new authentication helps.
  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    try {
      final current = await _current();
      if (current != null &&
          current.jwt != rejectedToken &&
          !_isExpired(current)) {
        return current.jwt;
      }
      final stored = await _readStored();
      if (stored != null &&
          stored.jwt != rejectedToken &&
          !_isExpired(stored)) {
        return (_token = stored).jwt;
      }
      return (await _authenticateOnce(rejectedToken: rejectedToken)).jwt;
    } on _Retired {
      return null;
    }
  }

  /// A request answered that the share is gone.
  void noteGone(LinkShareGone failure) {
    if (_retired || _ended != null) return;
    unawaited(_end(failure).then<void>((_) {}, onError: (Object _) {}));
  }

  /// A token the guest sign-in has just stored.
  void adopt(LinkShareToken token, {required DateTime receivedAt}) {
    if (_retired) return;
    _learnClockOffset(token, receivedAt);
    _token = token;
    _ended = null;
  }

  /// Completes once no renewal or authentication is on its way and no
  /// token write is pending: an authentication whose token is dropped
  /// costs another one from the shared limit.
  Future<void> settle() async {
    for (final pending in <Future<Object?>?>[
      _renewing,
      _authenticating,
      _pendingWrite,
    ]) {
      if (pending == null) continue;
      try {
        await pending;
      } on Object {
        // Only completion matters here.
      }
    }
  }

  /// After sign-out or a new sign-in: hands out nothing more and writes no
  /// token, once a write that has already started is done.
  Future<void> retire() async {
    _retired = true;
    _token = null;
    final writing = _pendingWrite;
    if (writing == null) return;
    try {
      await writing;
    } on Object {
      // Only completion matters here.
    }
  }

  Future<LinkShareToken?> _current() async {
    _ensureUsable();
    if (_token case final token?) return token;
    final stored = await _readStored();
    return _token ??= stored;
  }

  /// Null when only the hash is stored, or the token cannot be read.
  Future<LinkShareToken?> _readStored() async {
    final stored = await _store.read(accountId);
    _ensureUsable();
    if (stored == null) {
      throw await _end(const SessionEnded(SessionEndReason.expired));
    }
    final jwt = stored.token;
    if (jwt == null) return null;
    final claims = LinkShareClaims.tryParse(jwt);
    return claims == null ? null : LinkShareToken(jwt, claims);
  }

  Future<LinkShareToken> _renewOnce(LinkShareToken token) =>
      _renewing ??= _renewFrom(token).whenComplete(() => _renewing = null);

  Future<LinkShareToken> _renewFrom(LinkShareToken token) async {
    // Another isolate may have renewed it already.
    final stored = await _readStored();
    if (stored != null && !_pastHalfLife(stored)) return _token = stored;
    final sentAt = _clock();
    try {
      final fresh = await _renew(token.jwt);
      _ensureUsable();
      return await _keep(fresh, receivedAt: sentAt);
    } on LinkShareGone catch (failure) {
      throw await _end(failure);
    } on VikunjaFailure {
      _renewalBlockedUntil = _clock().add(renewalBackoff);
      rethrow;
    }
  }

  Future<LinkShareToken> _authenticateOnce({String? rejectedToken}) =>
      _authenticating ??= _authenticateAgain(rejectedToken)
          .whenComplete(() => _authenticating = null);

  Future<LinkShareToken> _authenticateAgain(String? rejectedToken) async {
    final storedShare = await _store.read(accountId);
    _ensureUsable();
    if (storedShare == null) {
      throw await _end(const SessionEnded(SessionEndReason.expired));
    }
    // Another isolate may have authenticated already.
    if (storedShare.token case final jwt? when jwt != rejectedToken) {
      if (LinkShareClaims.tryParse(jwt) case final claims?) {
        final stored = LinkShareToken(jwt, claims);
        if (!_isExpired(stored)) return _token = stored;
      }
    }
    _ensureMayAuthenticate();
    _authentications++;
    final sentAt = _clock();
    try {
      final auth = await _authenticate(storedShare.hash);
      _ensureUsable();
      _log.info('Guest $accountId authenticated again');
      return await _keep(auth.token, receivedAt: sentAt);
    } on LinkShareGone catch (failure) {
      throw await _end(failure);
    } on RateLimited catch (failure) {
      final wait = switch (failure.retryAfter) {
        final retryAfter? when retryAfter < maxRetryAfter => retryAfter,
        null => const Duration(seconds: 60),
        _ => maxRetryAfter,
      };
      _authenticationBlockedUntil = _clock().add(wait);
      rethrow;
    } on VikunjaFailure catch (failure) {
      if (failure.code == _passwordRequired || failure.code == _wrongPassword) {
        throw await _end(
          SessionEnded(
            SessionEndReason.expired,
            code: failure.code,
            message: failure.message,
          ),
        );
      }
      rethrow;
    }
  }

  void _ensureMayAuthenticate() {
    if (_authenticationBlockedUntil case final until?) {
      final now = _clock();
      if (now.isBefore(until)) {
        throw RateLimited(retryAfter: until.difference(now));
      }
      _authenticationBlockedUntil = null;
    }
    final max = _maxAuthentications;
    if (max != null && _authentications >= max) {
      throw const TokenRejected(
        message: 'the token has expired and this isolate authenticated already',
      );
    }
  }

  /// [retire] waits for the write, so nothing may be awaited between the
  /// check and recording it.
  Future<LinkShareToken> _keep(
    LinkShareToken token, {
    required DateTime receivedAt,
  }) async {
    _ensureUsable();
    _learnClockOffset(token, receivedAt);
    _token = token;
    final write = _writeToken(token.jwt);
    _pendingWrite = write;
    try {
      await write;
    } on Object catch (error) {
      // The token works from memory; the next start authenticates again.
      _log.warning(
        'Could not store the token of guest $accountId: ${error.runtimeType}',
      );
    } finally {
      if (identical(_pendingWrite, write)) _pendingWrite = null;
    }
    return token;
  }

  /// The token carries the hash, so it is written only next to it. A
  /// sign-out in another isolate can delete the hash between the check and
  /// the write; it deletes the hash first, so the check after the write
  /// sees that and takes the token back.
  Future<void> _writeToken(String jwt) async {
    if (await _store.read(accountId) == null) return;
    await _store.writeToken(accountId, jwt);
    if (await _store.read(accountId) == null) await _store.delete(accountId);
  }

  Future<SessionEnded> _end(SessionEnded failure) async {
    if (_retired) throw const _Retired();
    _ended = failure;
    _token = null;
    _log.warning('Session of guest $accountId ended: $failure');
    try {
      await _onEnded(failure);
    } on Object catch (error, stackTrace) {
      _log.severe('Could not flag guest $accountId', error, stackTrace);
    }
    return failure;
  }

  void _ensureUsable() {
    if (_retired) throw const _Retired();
    if (_ended case final ended?) throw ended;
  }

  bool get _renewalBlocked {
    final until = _renewalBlockedUntil;
    if (until == null) return false;
    if (_clock().isBefore(until)) return true;
    _renewalBlockedUntil = null;
    return false;
  }

  void _learnClockOffset(LinkShareToken token, DateTime receivedAt) {
    if (token.claims.issuedAt case final issuedAt?) {
      _serverClockOffset = issuedAt.difference(receivedAt);
    }
  }

  bool _isExpired(LinkShareToken token) =>
      token.claims.expiresAt.difference(_serverNow) < expiryMargin;

  bool _pastHalfLife(LinkShareToken token) {
    final expiresAt = token.claims.expiresAt;
    final lifetime = switch (token.claims.issuedAt) {
      final issuedAt? => expiresAt.difference(issuedAt),
      null => defaultLifetime,
    };
    return expiresAt.difference(_serverNow) < lifetime ~/ 2;
  }
}

/// One [LinkShareSession] per guest account for this isolate.
final class LinkShareSessions {
  new({
    required this._store,
    required this._gateway,
    required this._connectionFor,
    required this._markNeedsReauth,
    this._onSessionEnded,
    this._clock = DateTime.now,
    this._maxAuthentications,
  });

  final LinkShareStore _store;
  final LinkShareGateway _gateway;
  final Future<ServerConnection?> Function(String accountId) _connectionFor;
  final Future<void> Function(String accountId) _markNeedsReauth;
  final Future<void> Function(String accountId, SessionEnded failure)?
  _onSessionEnded;
  final DateTime Function() _clock;
  final int? _maxAuthentications;
  final _sessions = <String, LinkShareSession>{};

  LinkShareSession forAccount(String accountId) =>
      _sessions.putIfAbsent(accountId, () => _create(accountId));

  /// The retired session stays registered, so a late request finds one
  /// that hands out nothing, until [signedIn] replaces it.
  Future<void> retire(String accountId) => forAccount(accountId).retire();

  /// See [LinkShareSession.settle], for every guest.
  Future<void> settle() =>
      Future.wait([for (final session in _sessions.values) session.settle()]);

  /// For a token the guest sign-in has just stored.
  LinkShareSession signedIn(
    String accountId,
    LinkShareToken token, {
    required DateTime receivedAt,
  }) {
    final previous = _sessions[accountId];
    final session = _sessions[accountId] = _create(accountId);
    if (previous != null) unawaited(previous.retire());
    session.adopt(token, receivedAt: receivedAt);
    return session;
  }

  LinkShareSession _create(String accountId) {
    Future<ServerConnection> connection() async =>
        await _connectionFor(accountId) ??
        (throw const SessionEnded(SessionEndReason.expired));
    return LinkShareSession(
      accountId: accountId,
      store: _store,
      renew: (token) async => await _gateway.renew(await connection(), token),
      authenticate: (hash) async =>
          await _gateway.authenticate(await connection(), hash),
      onEnded: (failure) async {
        await _markNeedsReauth(accountId);
        await _onSessionEnded?.call(accountId, failure);
      },
      clock: _clock,
      maxAuthentications: _maxAuthentications,
    );
  }
}

final class _Retired implements Exception {
  const new();
}
