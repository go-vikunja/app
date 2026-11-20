import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

typedef Clock = DateTime Function();
typedef Sleep = Future<void> Function(Duration duration);
typedef RefreshCall = Future<TokenSet> Function(String refreshToken);
typedef SessionEndedHandler = Future<void> Function(SessionEnded failure);
typedef RefreshGate = bool Function();

/// Why a refresh was put off without an answer from the server; the
/// [NetworkFailure] that carries it is transient for every caller (D59).
enum RefreshDeferred {
  /// Too little of the background run is left for its answer to arrive.
  cutoff,

  /// A sibling isolate won the rotation and has not stored its tokens yet.
  race,
}

/// How long a token request may take in a background run, so that a
/// rotation's answer arrives before the OS ends the run (D59). Open until
/// [answerWithin] sets when answers must be in; [closeNow] when the OS
/// stops the run.
final class RefreshCutoff {
  new({
    this._clock = DateTime.now,
    this.connectTimeout = Duration.zero,
    this.minimumTokenTimeout = Duration.zero,
    this.maximumTokenTimeout = const Duration(seconds: 60),
  });

  final Clock _clock;

  /// Part of every token request's time: the native adapters bound a
  /// request by the connect and the receive timeout together.
  final Duration connectTimeout;

  /// No refresh starts with less time for its answer.
  final Duration minimumTokenTimeout;
  final Duration maximumTokenTimeout;

  DateTime? _answersBy;
  bool _closed = false;

  /// On this cutoff's own clock, which may differ from the caller's.
  void answerWithin(Duration duration) => _answersBy = _clock().add(duration);

  void closeNow() => _closed = true;

  /// The receive timeout of a token request sent now.
  Duration get tokenTimeout {
    final answersBy = _answersBy;
    if (answersBy == null) return maximumTokenTimeout;
    final left = answersBy.difference(_clock()) - connectTimeout;
    return left < maximumTokenTimeout ? left : maximumTokenTimeout;
  }

  bool get allowsRefresh => !_closed && tokenTimeout >= minimumTokenTimeout;
}

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
///
/// A closed `mayStartRefresh` gate fails a refresh before it is sent, as
/// deferred ([RefreshDeferred.cutoff]): a background run closes it when too
/// little time is left for the answer (D59). Storage that refuses to read
/// fails a call as a [NetworkFailure] whose cause is the
/// [SecureStorageUnreadable]: the tokens are kept for a later try (D24).
final class SessionManager implements AccessTokenSource {
  new({
    required this.accountId,
    required this._tokenStore,
    required this._refresh,
    required this._onSessionEnded,
    this._clockOffsets,
    this._diagnostics,
    this._part = AppPart.app,
    this._mayStartRefresh,
    this._clock = DateTime.now,
    this._sleep = _delay,
    this._refreshes = true,
  });

  static const refreshMargin = Duration(seconds: 60);
  static const maxRetryAfter = Duration(minutes: 10);
  static const serverErrorRetryDelay = Duration(seconds: 2);

  /// How long to keep looking for the tokens of a sibling isolate that won a
  /// rotation race: it still has to receive the response and write storage,
  /// which a cold engine on a slow network can take seconds for. Waiting is
  /// cheap, a session ended for nothing is not.
  static const raceRecheckDelays = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  static final Duration raceRecheckWindow = raceRecheckDelays.reduce(
    (a, b) => a + b,
  );

  static const settleWriteRetryDelay = Duration(milliseconds: 250);
  static const settleWriteRetries = 3;

  static const _spentRefreshTokensKept = 8;

  // The offset includes the response latency, so it jitters by about a
  // second; smaller changes are not worth a preferences write.
  static const _clockOffsetSaveThreshold = Duration(seconds: 5);

  final String accountId;
  final TokenStore _tokenStore;
  final RefreshCall _refresh;
  final SessionEndedHandler _onSessionEnded;
  final ServerClockOffsets? _clockOffsets;
  final SessionDiagnostics? _diagnostics;
  final AppPart _part;
  final RefreshGate? _mayStartRefresh;
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

  /// The latest refresh tokens the server took or refused here. Storage
  /// can still hold one whose successor it failed to store, and none of
  /// them brings an ended session back.
  final _spentRefreshTokens = <String>{};
  bool _retired = false;
  int _epoch = 0;

  /// The diagnostics' marker for the token being sent, as it was before
  /// this send, or the one this send wrote once a server error kept it;
  /// whether this send wrote a new one that a failure proving the send
  /// never reached the server takes back.
  RefreshMarker? _markerBefore;
  RefreshMarker? _markerWritten;
  bool _sendMarked = false;

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
  /// made; the refresh's outcome is its caller's. Rotated tokens that could
  /// not be stored are written again a few times, as they die with the
  /// isolate.
  Future<void> settle() async {
    for (final pending in <Future<Object?>?>[_inFlight, _pendingWrite]) {
      if (pending == null) continue;
      try {
        await pending;
      } on Object {
        // Only completion matters here.
      }
    }
    for (
      var retry = 0;
      retry <= settleWriteRetries && _unpersisted != null;
      retry++
    ) {
      if (_retired) return;
      if (retry > 0) await _sleep(settleWriteRetryDelay * retry);
      try {
        await _storeKeptTokens(_epoch);
      } on Object {
        // Logged by the write; the session's outcome is not settle's.
      }
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
    if (_ended != null) await _reviveIfReplaced(epoch);
    _ensureUsable(epoch);
    if (_session case final session?) return session;
    final stored = await _readStored(epoch);
    return _session ??= _Session.fromStored(stored);
  }

  /// Another isolate may have stored tokens that work after this manager
  /// ended the session: a rotation it stored late, or a restore in a
  /// background run (D59). Only storage that names a refresh token this
  /// manager has neither seen refused nor rotated away brings the session
  /// back.
  Future<void> _reviveIfReplaced(int epoch) async {
    if (_retired || epoch != _epoch) return;
    final StoredTokens? stored;
    try {
      stored = await _tokenStore.read(accountId);
    } on Object {
      return;
    }
    if (stored == null || _spentRefreshTokens.contains(stored.refreshToken)) {
      return;
    }
    if (_retired || epoch != _epoch || _ended == null) return;
    _log.info('Account $accountId has new tokens since its session ended');
    _ended = null;
    _session = _Session.fromStored(stored);
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
  /// When they do not, only a refusal without any sign of a race ends the
  /// session: after a race the winner holds a live session, and the next
  /// call finds its tokens. A race refused once more after the window has
  /// passed is no race: no winner ever stored anything.
  Future<_Session> _recoverLostRotation(
    String lostRefreshToken,
    int epoch,
    VikunjaFailure failure,
  ) async {
    var usedRefreshToken = lostRefreshToken;
    var raced = failure is RefreshRaceLost;
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
        raced = raced || retryFailure is RefreshRaceLost;
      }
    }
    if (raced && !_refusedBeforeWindow(usedRefreshToken)) {
      _log.warning(
        'Account $accountId lost a refresh race and the winner has not '
        'stored its tokens yet',
      );
      throw const NetworkFailure(
        NetworkProblem.timeout,
        cause: RefreshDeferred.race,
      );
    }
    _log.warning('Refresh token of account $accountId was already used');
    throw await _end(
      SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: failure.code,
        message: failure.message,
      ),
      epoch,
      failedRefreshToken: usedRefreshToken,
    );
  }

  bool _refusedBeforeWindow(String refreshToken) {
    final before = _markerBefore;
    final refusedAt = before?.refusedAt;
    return before?.token == tokenFingerprint(refreshToken) &&
        refusedAt != null &&
        _clock().difference(refusedAt) > raceRecheckWindow;
  }

  Future<_Session> _rotate(String refreshToken, int epoch) async {
    _ensureMayStartRefresh();
    await _noteRefreshSent(refreshToken);
    final TokenSet fresh;
    try {
      fresh = await _callRefresh(refreshToken, epoch);
      _noteSpent(refreshToken);
    } on _NoConnection {
      await _forgetUnreachedSend(refreshToken);
      // Not a verdict on the session: the registry was unreadable or the
      // account is being removed.
      throw const UnexpectedResponse(
        null,
        message: 'no server connection is stored for the account',
      );
    } on VikunjaFailure catch (failure) {
      if (failure is RateLimited) _blockRefreshes(failure.retryAfter);
      if (_neverProcessed(failure)) await _forgetUnreachedSend(refreshToken);
      if (failure is! SessionEnded && failure is! RefreshRaceLost) rethrow;
      // Noted before the re-reads, which a run the OS ends may cut short.
      await _noteRefused(refreshToken);
      if (failure is! SessionEnded || _lostRotation(failure)) rethrow;
      // The answer is about the session this token belongs to; a sibling
      // isolate may have stored a new sign-in meanwhile.
      final stored = await _readStored(epoch);
      if (stored.refreshToken == refreshToken) {
        throw await _end(failure, epoch, failedRefreshToken: refreshToken);
      }
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
      // The server may have rotated before failing, so the send stays
      // noted whatever becomes of the retry, and a refusal of the retry
      // keeps naming it.
      _sendMarked = false;
      _markerBefore ??= _markerWritten;
      await _sleep(serverErrorRetryDelay);
      // SQLite servers answer the loser of a rotation race with a 500 instead
      // of 16004, so a sibling may have stored the rotated tokens meanwhile.
      final stored = await _readStored(epoch);
      if (stored.refreshToken != refreshToken) throw const RefreshRaceLost();
      _ensureMayStartRefresh();
      try {
        return await _refresh(refreshToken);
      } on SessionEnded catch (refused) {
        if (refused.reason != SessionEndReason.invalidRefreshToken) rethrow;
        // The 500 may have been that loser's answer, or the server rotated
        // before failing: a race, not yet a dead session.
        throw const RefreshRaceLost(message: 'refused after a server error');
      }
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
      await _noteRefreshSettled(usedRefreshToken);
      return _session = _Session.fromStored(stored);
    }
    final replacedRefreshToken =
        _unpersisted?.replacedRefreshToken ?? usedRefreshToken;
    _learnClockOffset(fresh.issuedAt.difference(receivedAt));
    try {
      await _writeTokens(fresh, epoch);
      _unpersisted = null;
      await _noteRefreshSettled(usedRefreshToken);
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
      await _diagnostics?.refreshSettled(
        accountId,
        token: tokenFingerprint(unpersisted.replacedRefreshToken),
      );
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
    final StoredTokens? stored;
    try {
      stored = await _tokenStore.read(accountId);
    } on SecureStorageUnreadable catch (error) {
      // Like a network error for every caller: the tokens may still be
      // there, so they are kept and tried again later. As a VikunjaFailure
      // it passes the transport's retries and error mapping unchanged.
      throw NetworkFailure(NetworkProblem.unreachable, cause: error);
    }
    await _diagnostics?.noteReadable(accountId);
    return await _resolveStored(stored, epoch);
  }

  /// When an earlier write failed and storage still holds the refresh token
  /// that was rotated away, the unpersisted tokens stand in for it.
  Future<StoredTokens> _resolveStored(StoredTokens? stored, int epoch) async {
    _ensureUsable(epoch);
    if (stored == null) {
      throw await _end(
        const SessionEnded(SessionEndReason.invalidRefreshToken),
        epoch,
        cause: SessionEndCause.missingTokens,
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

  Future<SessionEnded> _end(
    SessionEnded failure,
    int epoch, {
    String? failedRefreshToken,
    SessionEndCause? cause,
  }) async {
    if (_retired || epoch != _epoch) throw const _Retired();
    _ended = failure;
    final rotatedAway = _unpersisted?.replacedRefreshToken;
    if (rotatedAway != null) _noteSpent(rotatedAway);
    if (failedRefreshToken != null) _noteSpent(failedRefreshToken);
    _session = null;
    _unpersisted = null;
    _log.warning('Session of account $accountId ended: $failure');
    await _recordEnd(failure, failedRefreshToken, cause, rotatedAway);
    try {
      await _onSessionEnded(failure);
    } on Object catch (error, stackTrace) {
      _log.severe('Could not flag account $accountId', error, stackTrace);
    }
    return failure;
  }

  /// Storage may still hold [rotatedAway], which another isolate's restore
  /// must not send: the server refuses it, and its refusal would replace
  /// this record.
  Future<void> _recordEnd(
    SessionEnded failure,
    String? failedRefreshToken,
    SessionEndCause? cause,
    String? rotatedAway,
  ) async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    final failedToken = failedRefreshToken == null
        ? null
        : tokenFingerprint(failedRefreshToken);
    final before = _markerBefore?.token == failedToken ? _markerBefore : null;
    await diagnostics.recordEnd(
      accountId,
      SessionEndDiagnosis(
        at: _clock(),
        cause: cause ?? SessionEndCause.of(failure.reason),
        part: _part,
        code: failure.code,
        failedToken: failedToken,
        rotatedAwayToken: rotatedAway == null
            ? null
            : tokenFingerprint(rotatedAway),
        lostRefreshAt: before?.sentAt,
        lostRefreshPart: before?.sentBy,
      ),
    );
    if (failedToken != null) {
      await diagnostics.refreshSettled(accountId, token: failedToken);
    }
  }

  /// Notes the refresh about to be sent, unless the token was sent before
  /// without its answer being stored, or was refused: the earliest such
  /// send is the one the server may have rotated, and a refused token
  /// rotates no more. What was noted before is kept for this send's
  /// verdict.
  Future<void> _noteRefreshSent(String refreshToken) async {
    _markerBefore = null;
    _markerWritten = null;
    _sendMarked = false;
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    final token = tokenFingerprint(refreshToken);
    final marker = await diagnostics.refreshMarker(accountId);
    if (marker?.token == token) {
      _markerBefore = marker;
      return;
    }
    final sentAt = _clock();
    await diagnostics.refreshSent(
      accountId,
      token: token,
      part: _part,
      at: sentAt,
    );
    _markerWritten = (
      token: token,
      sentAt: sentAt,
      sentBy: _part,
      refusedAt: null,
    );
    _sendMarked = true;
  }

  /// A send that never reached the server, or that it answered without
  /// looking at the token, cannot have rotated it.
  Future<void> _forgetUnreachedSend(String refreshToken) async {
    if (!_sendMarked) return;
    _sendMarked = false;
    await _diagnostics?.refreshSettled(
      accountId,
      token: tokenFingerprint(refreshToken),
    );
  }

  Future<void> _noteRefused(String refreshToken) async {
    _sendMarked = false;
    await _diagnostics?.refreshRefused(
      accountId,
      token: tokenFingerprint(refreshToken),
      at: _clock(),
      before: _markerBefore,
    );
  }

  Future<void> _noteRefreshSettled(String refreshToken) async {
    _markerBefore = null;
    _sendMarked = false;
    await _diagnostics?.refreshSettled(
      accountId,
      token: tokenFingerprint(refreshToken),
    );
  }

  void _noteSpent(String refreshToken) {
    _spentRefreshTokens
      ..remove(refreshToken)
      ..add(refreshToken);
    if (_spentRefreshTokens.length > _spentRefreshTokensKept) {
      _spentRefreshTokens.remove(_spentRefreshTokens.first);
    }
  }

  void _ensureMayStartRefresh() {
    if (_mayStartRefresh?.call() ?? true) return;
    throw const NetworkFailure(
      NetworkProblem.timeout,
      cause: RefreshDeferred.cutoff,
    );
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

  /// Answers the server or something in front of it gave without rotating
  /// the token, and requests that never left the device.
  static bool _neverProcessed(VikunjaFailure failure) => switch (failure) {
    RateLimited() || OAuthFailure() => true,
    UnexpectedResponse(:final statusCode?) =>
      statusCode >= 400 && statusCode < 500,
    final NetworkFailure network => neverReachedServer(network),
    _ => false,
  };

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
    this._clearNeedsReauth,
    this._diagnostics,
    this._part = AppPart.app,
    this._mayStartRefresh,
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
  final Future<void> Function(String accountId)? _clearNeedsReauth;
  final SessionDiagnostics? _diagnostics;
  final AppPart _part;
  final RefreshGate? _mayStartRefresh;
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

  /// An account marked `needsReauth` whose storage now holds another
  /// refresh token than the one that ended it (a sibling isolate stored its
  /// rotation after this one gave up), or that could not read storage
  /// before; never one whose storage still holds the token a refresh had
  /// rotated away when it ended. A refresh tests the stored tokens, and the
  /// mark is cleared when the server takes them. One another isolate
  /// restored already is only unmarked here. Never throws.
  Future<bool> tryRestore(String accountId) async {
    final clearNeedsReauth = _clearNeedsReauth;
    final diagnostics = _diagnostics;
    if (!_refreshes || clearNeedsReauth == null || diagnostics == null) {
      return false;
    }
    try {
      final ended = await diagnostics.lastEnd(accountId);
      if (ended == null) return false;
      if (ended.resolution == SessionEndResolution.restored) {
        await clearNeedsReauth(accountId);
        return true;
      }
      if (ended.resolution != null) return false;
      final stored = await _tokenStore.read(accountId);
      if (stored == null) return false;
      final storedToken = tokenFingerprint(stored.refreshToken);
      if (storedToken == ended.rotatedAwayToken) return false;
      final retry = switch (ended.cause) {
        SessionEndCause.storageUnreadable => true,
        SessionEndCause.refreshRejected =>
          ended.failedToken != null && ended.failedToken != storedToken,
        _ => false,
      };
      if (!retry) return false;
      // A live manager may have a refresh of these tokens on its way, whose
      // answer must not be dropped; an ended one takes new tokens itself.
      await forAccount(accountId).refreshNow();
      await diagnostics.noteReadable(accountId);
      await diagnostics.recordEnd(
        accountId,
        ended.resolved(SessionEndResolution.restored),
      );
      await clearNeedsReauth(accountId);
      _log.info('The session of account $accountId works again');
      return true;
    } on Object catch (error) {
      _log.info(
        'The session of account $accountId stays ended: ${error.runtimeType}',
      );
      return false;
    }
  }

  SessionManager _create(String accountId) => SessionManager(
    accountId: accountId,
    tokenStore: _tokenStore,
    clockOffsets: _clockOffsets,
    diagnostics: _diagnostics,
    part: _part,
    mayStartRefresh: _mayStartRefresh,
    refresh: (refreshToken) async {
      final connection = await _connectionFor(accountId);
      if (connection == null) throw const _NoConnection();
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

/// The registry names no server for the account, so no refresh was sent.
final class _NoConnection implements Exception {
  const new();
}
