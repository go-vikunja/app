import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

typedef Clock = DateTime Function();
typedef Sleep = Future<void> Function(Duration duration);
typedef RefreshCall = Future<TokenSet> Function(String refreshToken);
typedef SessionEndedHandler = Future<void> Function(SessionEnded failure);

final _log = Logger('SessionManager');

Future<void> _delay(Duration duration) => Future<void>.delayed(duration);

/// Keeps one account's tokens valid. Works without a widget tree, so
/// background isolates use it the same way as the UI.
///
/// Vikunja rotates the refresh token on every refresh and has no grace period
/// for the old one, so a refresh must never run twice with the same token and
/// its result must be persisted before anything uses it.
///
/// With `refreshes` false the manager never calls the server: it hands out
/// the stored access token while it is valid and otherwise fails the
/// request as a rejected token, so that a short-lived isolate (a
/// notification action, D26 and architecture §5.8) leaves the rotation to
/// the app; a token a sibling isolate stored meanwhile is still adopted.
final class SessionManager implements AccessTokenSource {
  new({
    required this.accountId,
    required this._tokenStore,
    required this._refresh,
    required this._onSessionEnded,
    this._clockOffsets,
    this._clock = DateTime.now,
    this._sleep = _delay,
    this._refreshes = true,
  });

  static const refreshMargin = Duration(seconds: 60);
  static const maxRetryAfter = Duration(minutes: 10);
  static const serverErrorRetryDelay = Duration(seconds: 2);

  /// How long to keep looking for the tokens of a sibling isolate that won a
  /// rotation race: it still has to receive the response and write storage.
  static const raceRecheckDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  // The offset includes the response latency, so it jitters by about a
  // second; smaller changes are not worth a preferences write.
  static const _clockOffsetSaveThreshold = Duration(seconds: 5);

  final String accountId;
  final TokenStore _tokenStore;
  final RefreshCall _refresh;
  final SessionEndedHandler _onSessionEnded;
  final ServerClockOffsets? _clockOffsets;
  final Clock _clock;
  final Sleep _sleep;
  final bool _refreshes;

  _Session? _session;
  Duration _serverClockOffset = Duration.zero;
  bool _clockOffsetLearned = false;
  Future<void>? _clockOffsetLoad;
  Duration? _savedClockOffset;
  Future<_Session>? _inFlight;
  Future<void>? _pendingWrite;
  _Unpersisted? _unpersisted;
  Future<void>? _keptWrite;
  DateTime? _refreshBlockedUntil;
  SessionEnded? _ended;
  bool _retired = false;
  int _epoch = 0;

  DateTime get _serverNow => _clock().add(_serverClockOffset);

  @override
  Future<String> validAccessToken() async {
    final epoch = _epoch;
    try {
      await _storeKeptTokens(epoch);
      final session = await _currentSession(epoch);
      if (!_expiresSoon(session)) return session.accessToken;
      if (!_refreshes) return await _withoutRefresh(session, epoch);
      try {
        return (await _refreshFrom(session)).accessToken;
      } on VikunjaFailure catch (failure) {
        // The token still works for a moment; the next call tries again.
        if (_isTransient(failure) && !_isExpired(session)) {
          return session.accessToken;
        }
        rethrow;
      }
    } on _Retired {
      throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    }
  }

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    final epoch = _epoch;
    try {
      await _storeKeptTokens(epoch);
      final session = await _currentSession(epoch);
      if (session.accessToken != rejectedToken) return session.accessToken;
      if (!_refreshes) {
        final stored = await _readStored(epoch);
        if (stored.accessToken == rejectedToken) return null;
        return (_session = _Session.fromStored(stored)).accessToken;
      }
      return (await _refreshFrom(session)).accessToken;
    } on _Retired {
      return null;
    }
  }

  /// Rotates the tokens now, however long the access token still lasts: a
  /// session the server ended (a password change ends every session of the
  /// user) shows only on a refresh, while its access token keeps working
  /// until it expires. Throws like a refresh, [SessionEnded] once the
  /// session is gone; without `refreshes` it does nothing.
  Future<void> refreshNow() async {
    final epoch = _epoch;
    try {
      final session = await _currentSession(epoch);
      if (!_refreshes) return;
      await _refreshFrom(session);
    } on _Retired {
      throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    }
  }

  /// The stored token while it lasts; afterwards the request fails like a
  /// rejected token, which the outbox retries later from an isolate that
  /// refreshes. A sibling's newer token in storage is taken instead.
  Future<String> _withoutRefresh(_Session snapshot, int epoch) async {
    final stored = await _readStored(epoch);
    final session = stored.refreshToken == snapshot.refreshToken
        ? snapshot
        : _session = _Session.fromStored(stored);
    if (!_isExpired(session)) return session.accessToken;
    throw const TokenRejected(
      message: 'the access token has expired and this isolate does not refresh',
    );
  }

  /// Tokens that were just persisted by a new sign-in. [receivedAt] is the
  /// local time the token response arrived, for the server clock offset.
  Future<void> adoptPersisted(
    TokenSet tokens, {
    required DateTime receivedAt,
  }) async {
    if (_retired) return;
    final offset = tokens.issuedAt.difference(receivedAt);
    _learnClockOffset(offset);
    _session = _Session.fromTokenSet(tokens);
    _ended = null;
    _unpersisted = null;
    await _track(_saveClockOffset(offset));
  }

  /// Completes once no refresh is on its way and no token write is pending,
  /// so the isolate may end without abandoning a rotation the server has
  /// made; tokens a refresh could not store get one more try. The refresh's
  /// outcome is its caller's.
  Future<void> settle() async {
    for (final pending in <Future<Object?>?>[_inFlight, _pendingWrite]) {
      if (pending == null) continue;
      try {
        await pending;
      } on Object {
        // Only completion matters here.
      }
    }
    try {
      await _storeKeptTokens(_epoch);
    } on Object {
      // Only completion matters here.
    }
  }

  /// After sign-out or replacement by a new sign-in. Waits only for a storage
  /// write that has already started, so the caller can wipe storage
  /// afterwards; a refresh still on the network is abandoned and its result
  /// discarded, however long the server takes.
  Future<void> retire() async {
    _retired = true;
    _epoch++;
    _session = null;
    _unpersisted = null;
    final writing = _pendingWrite;
    if (writing == null) return;
    try {
      await writing;
    } on Object {
      // Only completion matters here.
    }
  }

  Future<_Session> _currentSession(int epoch) async {
    _ensureUsable(epoch);
    if (_session case final session?) return session;
    final stored = await _readStored(epoch);
    return _session ??= _Session.fromStored(stored);
  }

  Future<_Session> _refreshFrom(_Session snapshot) {
    final epoch = _epoch;
    return _inFlight ??= _refreshExclusively(
      snapshot.refreshToken,
      epoch,
    ).whenComplete(() => _inFlight = null);
  }

  // Background isolates of this process (sync, notification actions) refresh
  // the same accounts. RandomAccessFile.lock cannot serialise them: POSIX
  // record locks belong to the whole process, so a second isolate acquires a
  // lock the first one still holds (verified on the macOS host VM by
  // test/core/auth/file_lock_isolates_test.dart; Android and iOS use the same
  // fcntl locks). Instead, storage is read again before every refresh and
  // after a lost rotation race, and newer tokens found there are adopted.
  Future<_Session> _refreshExclusively(String snapshot, int epoch) async {
    try {
      await _keptWrite;
    } on Object {
      // The retry below meets the same failure.
    }
    await _retryUnpersistedWrite(epoch);
    var refreshToken = snapshot;
    final stored = await _readStored(epoch);
    if (stored.refreshToken != refreshToken) {
      if (_adoptable(stored) case final adopted?) return _session = adopted;
      refreshToken = stored.refreshToken;
    }
    _ensureNotRateLimited();
    try {
      return await _rotate(refreshToken, epoch);
    } on VikunjaFailure catch (failure) {
      if (!_lostRotation(failure)) rethrow;
      return await _recoverLostRotation(refreshToken, epoch, failure);
    }
  }

  /// 16004 says a sibling won the race; 16002 can mean the same when the
  /// sibling finished first. Either way its tokens should show up in storage.
  Future<_Session> _recoverLostRotation(
    String lostRefreshToken,
    int epoch,
    VikunjaFailure failure,
  ) async {
    var usedRefreshToken = lostRefreshToken;
    for (final delay in [Duration.zero, ...raceRecheckDelays]) {
      if (delay > Duration.zero) await _sleep(delay);
      final stored = await _readStored(epoch);
      if (stored.refreshToken == usedRefreshToken) continue;
      if (_adoptable(stored) case final adopted?) return _session = adopted;
      usedRefreshToken = stored.refreshToken;
      try {
        return await _rotate(usedRefreshToken, epoch);
      } on VikunjaFailure catch (retryFailure) {
        // Lost again: a third refresher may still be writing.
        if (!_lostRotation(retryFailure)) rethrow;
      }
    }
    _log.warning('Refresh token of account $accountId was already used');
    throw await _end(
      SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: failure.code,
        message: failure.message,
      ),
      epoch,
    );
  }

  Future<_Session> _rotate(String refreshToken, int epoch) async {
    final TokenSet fresh;
    try {
      fresh = await _callRefresh(refreshToken, epoch);
    } on RateLimited catch (failure) {
      _blockRefreshes(failure.retryAfter);
      rethrow;
    } on SessionEnded catch (failure) {
      if (_lostRotation(failure)) rethrow;
      // The answer is about the session this token belongs to; a sibling
      // isolate may have stored a new sign-in meanwhile.
      final stored = await _readStored(epoch);
      if (stored.refreshToken == refreshToken) throw await _end(failure, epoch);
      if (_adoptable(stored) case final adopted?) return _session = adopted;
      return await _rotate(stored.refreshToken, epoch);
    }
    return await _persist(
      fresh,
      usedRefreshToken: refreshToken,
      receivedAt: _clock(),
      epoch: epoch,
    );
  }

  Future<TokenSet> _callRefresh(String refreshToken, int epoch) async {
    try {
      return await _refresh(refreshToken);
    } on ServerFailure catch (failure) {
      _log.info('Refresh failed with $failure, retrying once');
      await _sleep(serverErrorRetryDelay);
      // SQLite servers answer the loser of a rotation race with a 500 instead
      // of 16004, so a sibling may have stored the rotated tokens meanwhile.
      final stored = await _readStored(epoch);
      if (stored.refreshToken != refreshToken) throw const RefreshRaceLost();
      return await _refresh(refreshToken);
    }
  }

  Future<_Session> _persist(
    TokenSet fresh, {
    required String usedRefreshToken,
    required DateTime receivedAt,
    required int epoch,
  }) async {
    final StoredTokens? read;
    try {
      read = await _tokenStore.read(accountId);
    } on Object catch (error) {
      _ensureUsable(epoch);
      // Storage may hold a newer sign-in, so the tokens are not written now;
      // the write at the next call compares with storage first.
      _log.severe(
        'Could not read the tokens of account $accountId before storing the '
        'rotated ones: ${error.runtimeType}',
      );
      _learnClockOffset(fresh.issuedAt.difference(receivedAt));
      _unpersisted = _Unpersisted(
        fresh,
        replacedRefreshToken:
            _unpersisted?.replacedRefreshToken ?? usedRefreshToken,
      );
      return _session = _Session.fromTokenSet(fresh);
    }
    final stored = await _resolveStored(read, epoch);
    if (stored.refreshToken != usedRefreshToken) {
      // A new sign-in replaced the session while this refresh was in flight;
      // the tokens just received belong to the superseded session.
      return _session = _Session.fromStored(stored);
    }
    final replacedRefreshToken =
        _unpersisted?.replacedRefreshToken ?? usedRefreshToken;
    _learnClockOffset(fresh.issuedAt.difference(receivedAt));
    try {
      await _writeTokens(fresh, epoch);
      _unpersisted = null;
    } on _Retired {
      rethrow;
    } on Object catch (error) {
      // The server has already invalidated the stored refresh token, so the
      // new one is used from memory and written again at the next call.
      // Only the type is logged: platform errors can echo values.
      _log.severe(
        'Could not store the rotated tokens of account $accountId: '
        '${error.runtimeType}',
      );
      _unpersisted = _Unpersisted(
        fresh,
        replacedRefreshToken: replacedRefreshToken,
      );
    }
    return _session = _Session.fromTokenSet(fresh);
  }

  Future<void> _retryUnpersistedWrite(int epoch) async {
    final unpersisted = _unpersisted;
    if (unpersisted == null) return;
    // Drops the unpersisted tokens when storage holds newer ones.
    await _readStored(epoch);
    if (!identical(_unpersisted, unpersisted)) return;
    try {
      await _writeTokens(unpersisted.tokens, epoch);
      if (identical(_unpersisted, unpersisted)) _unpersisted = null;
    } on _Retired {
      rethrow;
    } on Object catch (error) {
      _log.warning(
        'Still cannot store the tokens of account $accountId: '
        '${error.runtimeType}',
      );
    }
  }

  /// Tokens a refresh could not store are written at the next call, not
  /// only before the next refresh: until then storage holds the refresh
  /// token the server has invalidated, and a sibling isolate that refreshes
  /// with it ends the session.
  Future<void> _storeKeptTokens(int epoch) {
    if (_unpersisted == null || _inFlight != null) return Future.value();
    return _keptWrite ??= _tryKeptWrite(epoch)
        .whenComplete(() => _keptWrite = null);
  }

  Future<void> _tryKeptWrite(int epoch) async {
    try {
      await _retryUnpersistedWrite(epoch);
    } on _Retired {
      rethrow;
    } on SessionEnded {
      rethrow;
    } on Object catch (error) {
      _log.warning(
        'Could not read the tokens of account $accountId to store the kept '
        'ones: ${error.runtimeType}',
      );
    }
  }

  /// [retire] waits for this write, so nothing may be awaited between the
  /// retirement check and recording the write.
  Future<void> _writeTokens(TokenSet tokens, int epoch) {
    if (_retired || epoch != _epoch) throw const _Retired();
    return _track(_storeTokensThenClockOffset(tokens));
  }

  Future<void> _storeTokensThenClockOffset(TokenSet tokens) async {
    await _tokenStore.write(accountId, tokens);
    if (_clockOffsetLearned) await _saveClockOffset(_serverClockOffset);
  }

  Future<void> _track(Future<void> write) async {
    _pendingWrite = write;
    try {
      await write;
    } finally {
      if (identical(_pendingWrite, write)) _pendingWrite = null;
    }
  }

  Future<StoredTokens> _readStored(int epoch) async {
    await (_clockOffsetLoad ??= _loadClockOffset());
    return await _resolveStored(await _tokenStore.read(accountId), epoch);
  }

  /// When an earlier write failed and storage still holds the refresh token
  /// that was rotated away, the unpersisted tokens stand in for it.
  Future<StoredTokens> _resolveStored(StoredTokens? stored, int epoch) async {
    _ensureUsable(epoch);
    if (stored == null) {
      throw await _end(
        const SessionEnded(SessionEndReason.invalidRefreshToken),
        epoch,
      );
    }
    final unpersisted = _unpersisted;
    if (unpersisted == null) return stored;
    if (stored.refreshToken == unpersisted.replacedRefreshToken) {
      return unpersisted.asStored;
    }
    _unpersisted = null;
    return stored;
  }

  Future<SessionEnded> _end(SessionEnded failure, int epoch) async {
    if (_retired || epoch != _epoch) throw const _Retired();
    _ended = failure;
    _session = null;
    _unpersisted = null;
    _log.warning('Session of account $accountId ended: $failure');
    try {
      await _onSessionEnded(failure);
    } on Object catch (error, stackTrace) {
      _log.severe('Could not flag account $accountId', error, stackTrace);
    }
    return failure;
  }

  void _ensureUsable(int epoch) {
    if (_retired || epoch != _epoch) throw const _Retired();
    if (_ended case final ended?) throw ended;
  }

  void _ensureNotRateLimited() {
    final until = _refreshBlockedUntil;
    if (until == null) return;
    final now = _clock();
    if (now.isBefore(until)) {
      throw RateLimited(retryAfter: until.difference(now));
    }
    _refreshBlockedUntil = null;
  }

  void _blockRefreshes(Duration? retryAfter) {
    if (retryAfter == null) return;
    final wait = retryAfter > maxRetryAfter ? maxRetryAfter : retryAfter;
    _refreshBlockedUntil = _clock().add(wait);
  }

  void _learnClockOffset(Duration offset) {
    _serverClockOffset = offset;
    _clockOffsetLearned = true;
  }

  Future<void> _loadClockOffset() async {
    final offsets = _clockOffsets;
    if (offsets == null) return;
    try {
      final saved = await offsets.read(accountId);
      _savedClockOffset ??= saved;
      // One learned from a response in this instance is newer.
      if (saved != null && !_clockOffsetLearned) _serverClockOffset = saved;
    } on Object catch (error) {
      _log.info('Could not read the server clock offset: ${error.runtimeType}');
    }
  }

  Future<void> _saveClockOffset(Duration offset) async {
    final offsets = _clockOffsets;
    if (offsets == null) return;
    final saved = _savedClockOffset;
    if (saved != null && (offset - saved).abs() < _clockOffsetSaveThreshold) {
      return;
    }
    try {
      await offsets.write(accountId, offset);
      _savedClockOffset = offset;
    } on Object catch (error) {
      _log.info(
        'Could not store the server clock offset: ${error.runtimeType}',
      );
    }
  }

  _Session? _adoptable(StoredTokens stored) {
    final session = _Session.fromStored(stored);
    return _expiresSoon(session) ? null : session;
  }

  bool _expiresSoon(_Session session) {
    final expiresAt = session.expiresAt;
    return expiresAt == null ||
        expiresAt.difference(_serverNow) < refreshMargin;
  }

  bool _isExpired(_Session session) {
    final expiresAt = session.expiresAt;
    return expiresAt == null || !expiresAt.isAfter(_serverNow);
  }

  static bool _lostRotation(VikunjaFailure failure) =>
      failure is RefreshRaceLost ||
      (failure is SessionEnded &&
          failure.reason == SessionEndReason.invalidRefreshToken);

  static bool _isTransient(VikunjaFailure failure) =>
      failure is NetworkFailure ||
      failure is ServerFailure ||
      failure is RateLimited ||
      failure is UnexpectedResponse;
}

/// One [SessionManager] per account for this isolate. With `refreshes`
/// false none of them ever refreshes (see [SessionManager]).
final class SessionManagers {
  new({
    required this._tokenStore,
    required this._clockOffsets,
    required this._tokenGateway,
    required this._connectionFor,
    required this._markNeedsReauth,
    this._onSessionEnded,
    this._clock = DateTime.now,
    this._sleep = _delay,
    this._refreshes = true,
  });

  final TokenStore _tokenStore;
  final ServerClockOffsets _clockOffsets;
  final TokenGateway _tokenGateway;
  final Future<ServerConnection?> Function(String accountId) _connectionFor;
  final Future<void> Function(String accountId) _markNeedsReauth;
  final Future<void> Function(String accountId, SessionEnded failure)?
  _onSessionEnded;
  final Clock _clock;
  final Sleep _sleep;
  final bool _refreshes;
  final _managers = <String, SessionManager>{};

  SessionManager forAccount(String accountId) =>
      _managers.putIfAbsent(accountId, () => _create(accountId));

  /// The retired manager stays registered, so a late request for this
  /// account (a list or sync call that got 401) finds a manager that hands
  /// out nothing and never writes storage, until [signedIn] replaces it.
  Future<void> retire(String accountId) => forAccount(accountId).retire();

  /// See [SessionManager.settle], for every account.
  Future<void> settle() =>
      Future.wait([for (final manager in _managers.values) manager.settle()]);

  /// For tokens a sign-in has just persisted.
  Future<SessionManager> signedIn(
    String accountId,
    TokenSet tokens, {
    required DateTime receivedAt,
  }) async {
    final previous = _managers[accountId];
    final manager = _managers[accountId] = _create(accountId);
    if (previous != null) unawaited(previous.retire());
    await manager.adoptPersisted(tokens, receivedAt: receivedAt);
    return manager;
  }

  SessionManager _create(String accountId) => SessionManager(
    accountId: accountId,
    tokenStore: _tokenStore,
    clockOffsets: _clockOffsets,
    refresh: (refreshToken) async {
      final connection = await _connectionFor(accountId);
      if (connection == null) {
        throw const SessionEnded(SessionEndReason.invalidRefreshToken);
      }
      return await _tokenGateway.refresh(connection, refreshToken);
    },
    onSessionEnded: (failure) async {
      await _markNeedsReauth(accountId);
      await _onSessionEnded?.call(accountId, failure);
    },
    clock: _clock,
    sleep: _sleep,
    refreshes: _refreshes,
  );
}

final class _Session {
  const new({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory fromTokenSet(TokenSet tokens) => _Session(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresAt: tokens.accessTokenExpiry,
  );

  factory fromStored(StoredTokens stored) => _Session(
    accessToken: stored.accessToken,
    refreshToken: stored.refreshToken,
    expiresAt: JwtClaims.tryParse(stored.accessToken)?.expiresAt,
  );

  final String accessToken;
  final String refreshToken;

  /// Server time. Null when the stored access token cannot be read, which
  /// counts as expired.
  final DateTime? expiresAt;
}

final class _Unpersisted {
  const new(this.tokens, {required this.replacedRefreshToken});

  final TokenSet tokens;
  final String replacedRefreshToken;

  StoredTokens get asStored => StoredTokens(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
  );
}

final class _Retired implements Exception {
  const new();
}
