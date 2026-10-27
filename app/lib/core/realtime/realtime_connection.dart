import 'dart:async';
import 'dart:io' show HandshakeException, TlsException, WebSocketException;
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

final _log = Logger('Realtime');

typedef RealtimeTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// `waiting`: for a retry, the end of a rate limit or the network.
/// `unavailable`: given up until a resume (a rejected session, a TLS
/// failure, a run of attempts that never got to `auth.success`) or for as
/// long as this connection lives (a server or proxy that refused the
/// upgrade before any socket of this connection was live).
enum RealtimeState { idle, connecting, live, waiting, unavailable }

enum _GivenUp { untilResume, forGood }

/// The active account's socket while the app is in front. Every pushed
/// notification is stored at once as handled, since the inbox and the
/// badge show it, and one that names a task or project asks for an
/// incremental sync. Each (re)connect catches up with one activity sync,
/// because the server keeps nothing for a socket that was away. The
/// polling stays: the socket carries no task changes and no reads, and
/// any failure only leaves the app where it was before.
final class RealtimeConnection {
  new({
    required this._connector,
    required this._url,
    required this._tokens,
    required this._engine,
    required this._activity,
    this._headers = const {},
    DateTime Function()? clock,
    this._createTimer = Timer.new,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random() {
    _engineStatus = _engine.status.listen(_onSyncStatus);
  }

  static const authTimeout = Duration(seconds: 10);

  /// The session manager refreshes within 60 s of the expiry, so a check
  /// at this interval always finds the new token 40 s or more before the
  /// server closes the socket for the old one.
  static const tokenCheckInterval = Duration(seconds: 20);
  static const syncDebounce = Duration(seconds: 2);
  static const initialBackoff = Duration(seconds: 2);
  static const maxBackoff = Duration(seconds: 60);

  /// A socket that stayed up this long resets the backoff.
  static const stableAfter = Duration(seconds: 60);

  /// Without `Retry-After` a refused upgrade waits out the server's whole
  /// limiter window.
  static const rateLimitWindow = Duration(seconds: 60);

  /// A rate-limited wait adds no backoff step, so a `Retry-After` of 0 (or
  /// a date already past) would retry in a tight loop; the floor doubles
  /// with every 429 in a row. A proxy may also ask for hours.
  static const Duration minRateLimitWait = initialBackoff;
  static const maxRateLimitWait = Duration(minutes: 5);

  /// REST can work where the socket cannot (a system proxy or VPN route
  /// dart:io ignores, a proxy without websockets), so a run of attempts that
  /// never get to `auth.success` stops until the next resume; rate-limited
  /// ones do not count.
  static const maxAttemptsWithoutAuth = 6;

  static const _syncingKinds = {
    'task.comment',
    'task.assigned',
    'task.mentioned',
    'task.created',
    'task.deleted',
    'project.created',
  };

  final RealtimeConnector _connector;
  final Uri _url;
  final Map<String, String> _headers;
  final AccessTokenSource _tokens;
  final SyncEngine _engine;
  final ActivityRepository _activity;
  final DateTime Function() _clock;
  final RealtimeTimerFactory _createTimer;
  final Random _random;
  final _changes = StreamController<RealtimeState>.broadcast(sync: true);
  late final StreamSubscription<SyncStatus> _engineStatus;

  RealtimeState _state = RealtimeState.idle;
  _Link? _link;
  var _active = false;
  var _disposed = false;
  var _offline = false;

  /// A connect, or the refresh after a rejection, is on its way.
  var _attempting = false;
  _GivenUp? _givenUp;

  /// A rejected token got one refresh and reconnect; a second rejection
  /// before an `auth.success` gives up.
  var _recovering = false;

  /// Some socket of this connection got to `auth.success`, so the server
  /// can upgrade.
  var _hasBeenLive = false;
  var _attemptsWithoutAuth = 0;
  var _rateLimitedInARow = 0;
  var _failures = 0;
  Timer? _retry;
  DateTime? _rateLimitedUntil;
  Timer? _syncTimer;
  var _syncAfterRun = false;
  Future<void> _storing = Future.value();

  RealtimeState get state => _state;

  /// Replays the current state on subscription.
  Stream<RealtimeState> get states => Stream.multi((subscriber) {
    final subscription = _changes.stream.listen(subscriber.addSync);
    subscriber
      ..onCancel = subscription.cancel
      ..add(_state);
  });

  /// The app is in front.
  void start() {
    if (_disposed) return;
    _active = true;
    _connect();
  }

  /// The app came back to the front: whatever gave up until now gets
  /// another run of attempts from the shortest wait. A resume without a
  /// pause before it changes nothing.
  void onResume() {
    if (_disposed || _active) return;
    _active = true;
    if (_givenUp == _GivenUp.untilResume) {
      _givenUp = null;
      _recovering = false;
    }
    _attemptsWithoutAuth = 0;
    _rateLimitedInARow = 0;
    _failures = 0;
    _connect();
  }

  /// The app left the front: the socket closes, nothing reconnects until
  /// [onResume].
  void onPause() {
    _active = false;
    _cancelRetry();
    _syncTimer?.cancel();
    _syncTimer = null;
    _syncAfterRun = false;
    if (_link case final link?) _detach(link);
    if (_givenUp == null) _setState(RealtimeState.idle);
  }

  /// No attempt while the sync runs say the server is unreachable; one at
  /// once when they get through again.
  void setOffline({required bool offline}) {
    if (_offline == offline) return;
    _offline = offline;
    if (offline || _rateLimitedUntil != null) return;
    _cancelRetry();
    _connect();
  }

  void dispose() {
    if (_disposed) return;
    onPause();
    _disposed = true;
    _setState(RealtimeState.idle);
    unawaited(_engineStatus.cancel());
    unawaited(_changes.close());
  }

  bool get _wanted => _active && !_disposed;

  void _connect() {
    if (!_wanted || _givenUp != null || _link != null) return;
    if (_attempting) {
      _setState(RealtimeState.connecting);
      return;
    }
    if (_rateLimitedUntil case final until?) {
      final left = until.difference(_clock());
      if (left > Duration.zero) {
        _armRetry(left);
        _setState(RealtimeState.waiting);
        return;
      }
      _rateLimitedUntil = null;
    }
    if (_offline) {
      _cancelRetry();
      _setState(RealtimeState.waiting);
      return;
    }
    _cancelRetry();
    unawaited(_open());
  }

  /// The token comes after the upgrade, so a server that refuses it costs
  /// no refresh; the server waits 30 s for the auth.
  Future<void> _open() async {
    _attempting = true;
    _setState(RealtimeState.connecting);
    RealtimeSocket? socket;
    final String token;
    try {
      socket = await _connector.connect(_url, headers: _headers);
      if (!_wanted) throw const _Abandoned();
      token = await _tokens.validAccessToken();
      if (!_wanted) throw const _Abandoned();
    } on Object catch (error) {
      _attempting = false;
      if (socket != null) unawaited(socket.close());
      if (_wanted) _onOpenFailed(error);
      return;
    }
    _attempting = false;
    _attach(socket, token);
  }

  void _onOpenFailed(Object error) {
    switch (error) {
      case RealtimeUpgradeRefused(statusCode: 429, :final retryAfter):
        _waitOutRateLimit(retryAfter);
      case RealtimeUpgradeRefused(:final statusCode) when statusCode >= 500:
        _retryLater('upgrade answered $statusCode');
      case RealtimeUpgradeRefused(:final statusCode):
        _onRefused('upgrade answered $statusCode');
      case WebSocketException():
        _onRefused('${error.runtimeType}');
      // dart:io's words for a connection lost mid-handshake, as on a network
      // change.
      case HandshakeException(
        message: 'Connection terminated during handshake',
      ):
        _retryLater('handshake terminated');
      // A certificate or protocol this client cannot get past on this
      // network, such as a captive portal's; it never reaches the server's
      // rate limiter.
      case TlsException():
        _giveUp(_GivenUp.untilResume, '${error.runtimeType}');
      case SessionEnded():
        _giveUp(_GivenUp.untilResume, 'session ended');
      // The connection settings refuse the socket before it opens; an edit
      // restarts the connection, otherwise the next resume tries again.
      case CleartextBlockedException() ||
          ConnectionProfileLockedException() ||
          ConnectionProfileIncompleteException() ||
          ConnectionProfilesDamagedException() ||
          ClientCertificateRefusedException():
        _giveUp(_GivenUp.untilResume, '${error.runtimeType}');
      default:
        _retryLater('${error.runtimeType}');
    }
  }

  /// A server or proxy that never upgraded is not asked again. After a
  /// live socket a refusal is taken as passing, like a reverse proxy that
  /// answers 404 while the server restarts.
  void _onRefused(String why) {
    if (_hasBeenLive) {
      _retryLater(why);
    } else {
      _giveUp(_GivenUp.forGood, why);
    }
  }

  void _attach(RealtimeSocket socket, String token) {
    final link = _link = _Link(socket, token);
    link.subscription = socket.messages.listen(
      (message) => _onMessage(link, message),
      // The socket's done follows its error.
      onError: (Object _) {},
      onDone: () => _onDone(link),
    );
    socket.authenticate(token);
    link.authTimer = _createTimer(authTimeout, () => _onAuthTimeout(link));
  }

  void _onMessage(_Link link, RealtimeMessage message) {
    if (!identical(_link, link)) return;
    switch (message) {
      case RealtimeAuthSucceeded():
        _onAuthenticated(link);
      case RealtimeError(code: RealtimeError.invalidToken):
        final rejected = link.pendingToken ?? link.token;
        _detach(link);
        unawaited(_recoverFromRejection(rejected, 'token rejected'));
      case RealtimeError(:final code, :final event):
        _log.fine('Server error $code${event == null ? '' : ' for $event'}');
      case RealtimeNotification(:final notification):
        _onNotification(notification);
      case RealtimeUnknown():
        break;
    }
  }

  void _onAuthenticated(_Link link) {
    link.authTimer?.cancel();
    if (link.pendingToken case final token?) {
      link
        ..token = token
        ..pendingToken = null;
      _log.fine('Re-authenticated');
      return;
    }
    if (link.liveSince != null) return;
    link.liveSince = _clock();
    _recovering = false;
    _hasBeenLive = true;
    _attemptsWithoutAuth = 0;
    _rateLimitedInARow = 0;
    link.socket.subscribe(RealtimeSocket.notificationCreated);
    _setState(RealtimeState.live);
    _armTokenCheck(link);
    unawaited(_catchUp());
  }

  Future<void> _catchUp() async {
    try {
      await _activity.refresh();
    } on Object catch (error) {
      _log.fine('Catch-up after connecting failed: ${error.runtimeType}');
    }
  }

  void _onDone(_Link link) {
    if (!identical(_link, link)) return;
    final code = link.socket.closeCode;
    final reason = link.socket.closeReason;
    _detach(link);
    if (code == 1008 && reason == 'session revoked') {
      unawaited(
        _recoverFromRejection(
          link.pendingToken ?? link.token,
          'session revoked',
        ),
      );
    } else {
      _retryLater(
        'closed with ${code ?? 'no close frame'}',
        afterLive: link.liveSince != null,
      );
    }
  }

  void _onAuthTimeout(_Link link) {
    if (!identical(_link, link)) return;
    _detach(link);
    _retryLater('no auth.success', afterLive: link.liveSince != null);
  }

  /// The manager hands out a newer token when it has one and refreshes
  /// otherwise; a session that really ended ends there, which takes this
  /// connection down with the account's other providers.
  Future<void> _recoverFromRejection(String rejected, String why) async {
    if (_recovering) {
      _giveUp(_GivenUp.untilResume, '$why again');
      return;
    }
    _recovering = true;
    _attempting = true;
    _setState(RealtimeState.connecting);
    _log.fine('Checking the session: $why');
    String? newer;
    try {
      newer = await _tokens.refreshAfterRejection(rejected);
    } on Object catch (error) {
      _log.fine('Session check failed: ${error.runtimeType}');
    }
    _attempting = false;
    if (_disposed) return;
    if (newer == null) {
      _giveUp(_GivenUp.untilResume, why);
      return;
    }
    _connect();
  }

  void _armTokenCheck(_Link link) {
    link.tokenTimer = _createTimer(
      tokenCheckInterval,
      () => unawaited(_checkToken(link)),
    );
  }

  /// Re-authenticates the open socket when the session's token changed,
  /// whoever refreshed it.
  Future<void> _checkToken(_Link link) async {
    if (!identical(_link, link)) return;
    if (link.pendingToken == null) {
      try {
        final token = await _tokens.validAccessToken();
        if (identical(_link, link) &&
            link.pendingToken == null &&
            token != link.token) {
          // The server re-authenticates only within the socket's session;
          // a new sign-in of the account needs a socket of its own.
          if (_sessionOf(token) != _sessionOf(link.token)) {
            _log.fine('Reconnecting for a new session');
            _detach(link);
            _connect();
            return;
          }
          _log.fine('Re-authenticating with a refreshed token');
          link
            ..pendingToken = token
            ..socket.authenticate(token)
            ..authTimer = _createTimer(authTimeout, () => _onAuthTimeout(link));
        }
      } on Object catch (error) {
        _log.fine('No token to check: ${error.runtimeType}');
      }
    }
    if (identical(_link, link)) _armTokenCheck(link);
  }

  static String? _sessionOf(String token) =>
      JwtClaims.tryParse(token)?.sessionId;

  void _onNotification(ServerNotification notification) {
    _log.fine('Notification ${notification.id} (${notification.name})');
    _storing = _storing.then((_) => _store(notification));
    if (_syncingKinds.contains(notification.name)) _requestSync();
  }

  Future<void> _store(ServerNotification notification) async {
    try {
      await _activity.receive(notification);
    } on Object catch (error) {
      _log.fine(
        'Notification ${notification.id} not stored: ${error.runtimeType}',
      );
    }
  }

  void _requestSync() {
    _syncTimer?.cancel();
    _syncTimer = _createTimer(syncDebounce, _syncNow);
  }

  void _syncNow() {
    _syncTimer = null;
    if (_disposed) return;
    // A run that began before the change may have missed it.
    if (_engine.currentStatus is SyncRunning) {
      _syncAfterRun = true;
      return;
    }
    _runSync();
  }

  void _onSyncStatus(SyncStatus status) {
    if (!_syncAfterRun || status is SyncRunning || _disposed) return;
    _syncAfterRun = false;
    _runSync();
  }

  void _runSync() {
    _log.fine('Syncing after a notification');
    // The engine's status reports the outcome.
    unawaited(_engine.refresh().then<void>((_) {}, onError: (Object _) {}));
  }

  /// [afterLive]: a socket that got to `auth.success` dropped; its attempt
  /// did not fail.
  void _retryLater(String why, {bool afterLive = false}) {
    if (!afterLive && ++_attemptsWithoutAuth >= maxAttemptsWithoutAuth) {
      _giveUp(_GivenUp.untilResume, '$why, $_attemptsWithoutAuth in a row');
      return;
    }
    var nominal = initialBackoff * pow(2, min(_failures, 8)).toInt();
    if (nominal > maxBackoff) nominal = maxBackoff;
    _failures++;
    final spread = nominal * (0.25 * _random.nextDouble());
    final delay = _random.nextBool() ? nominal + spread : nominal - spread;
    _log.fine('Reconnecting in ${delay.inMilliseconds} ms: $why');
    _armRetry(delay);
    _setState(RealtimeState.waiting);
  }

  void _waitOutRateLimit(Duration? retryAfter) {
    var wait = retryAfter ?? rateLimitWindow;
    final floor =
        minRateLimitWait * pow(2, min(_rateLimitedInARow++, 8)).toInt();
    if (wait < floor) wait = floor;
    if (wait > maxRateLimitWait) wait = maxRateLimitWait;
    final delay = wait + wait * (0.25 * _random.nextDouble());
    _log.fine('Upgrade rate-limited, retrying in ${delay.inSeconds} s');
    _rateLimitedUntil = _clock().add(delay);
    _armRetry(delay);
    _setState(RealtimeState.waiting);
  }

  void _giveUp(_GivenUp givenUp, String why) {
    _givenUp = givenUp;
    _cancelRetry();
    _log.fine('Unavailable (${givenUp.name}): $why');
    _setState(RealtimeState.unavailable);
  }

  void _armRetry(Duration delay) {
    _retry?.cancel();
    _retry = _createTimer(delay, () {
      _retry = null;
      _rateLimitedUntil = null;
      _connect();
    });
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void _detach(_Link link) {
    if (identical(_link, link)) _link = null;
    if (link.liveSince case final since?
        when _clock().difference(since) >= stableAfter) {
      _failures = 0;
    }
    link.close();
  }

  void _setState(RealtimeState state) {
    if (_state == state || _changes.isClosed) return;
    _state = state;
    _log.fine('State ${state.name}');
    _changes.add(state);
  }
}

final class _Abandoned implements Exception {
  const new();
}

final class _Link {
  new(this.socket, this.token);

  final RealtimeSocket socket;

  /// The token the socket was authenticated with.
  String token;

  /// A re-auth waiting for its `auth.success`.
  String? pendingToken;
  DateTime? liveSince;
  StreamSubscription<RealtimeMessage>? subscription;
  Timer? authTimer;
  Timer? tokenTimer;

  void close() {
    authTimer?.cancel();
    tokenTimer?.cancel();
    unawaited(socket.close());
    unawaited(subscription?.cancel());
  }
}
