import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';

final _log = Logger('ForegroundSync');

typedef TimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Keeps one account fresh while the app is in front: an incremental sync
/// [wait] after the last run ended, whoever started that run, and one on
/// resume when the last run is older than [interval].
///
/// The wait is [interval] after a run during which the account's data was
/// written (the run found something new, or the user or the outbox wrote),
/// and doubles up to [maxInterval] with every run that wrote nothing. A
/// write while a longer wait runs shortens it to [interval] after the last
/// run. Failures of reach or load, a [NetworkFailure], a [ServerFailure]
/// (5xx) or [RateLimited] (429), double the wait up to [maxInterval] as
/// well, a 429 waiting at least its Retry-After, also on resume; writes do
/// not shorten that wait, only a completed run ends it.
///
/// No second run starts while one is in progress: the timer waits for its
/// end, which starts the next wait. `onForeground` hears the start, every
/// resume and every tick of the timer (`timed`), whether a sync runs or
/// not.
final class ForegroundSyncScheduler {
  new({
    required this._engine,
    required this._clock,
    Stream<void>? dataWrites,
    this._createTimer = Timer.new,
    this._onForeground,
    this.interval = const Duration(seconds: 60),
    this.maxInterval = const Duration(minutes: 5),
  }) : _wait = interval,
       _resumeAfter = interval {
    _subscription = _engine.status.listen(_onStatus);
    _writes = dataWrites?.listen((_) => _onDataWrite());
  }

  final SyncEngine _engine;
  final DateTime Function() _clock;
  final TimerFactory _createTimer;
  final void Function({required bool timed})? _onForeground;
  final Duration interval;
  final Duration maxInterval;

  late final StreamSubscription<SyncStatus> _subscription;
  StreamSubscription<void>? _writes;
  Duration _wait;
  Duration _resumeAfter;
  DateTime? _lastRunEndedAt;
  var _wasRunning = false;
  var _wrote = false;
  var _backingOff = false;
  var _active = false;
  var _disposed = false;
  Timer? _timer;

  /// The wait before the next timed run; grows while runs find nothing new
  /// and while the server is out of reach or overloaded.
  Duration get wait => _wait;

  /// The app is in front; the first timed run is [wait] from now.
  void start() {
    if (_disposed) return;
    _active = true;
    _onForeground?.call(timed: false);
    _arm(_wait);
  }

  /// The app came back to the front: a run when the last one is older than
  /// [interval] (or a 429's Retry-After), or seems to lie ahead because the
  /// clock was set back, otherwise the timer continues where the pause left
  /// it. A resume without a pause before it (a dialog, the notification
  /// shade) changes nothing, so the wait after a failure holds.
  void onResume() {
    if (_disposed || _active) return;
    _active = true;
    _onForeground?.call(timed: false);
    if (_engine.currentStatus is SyncRunning) return;
    final sinceLastRun = _sinceLastRun();
    if (sinceLastRun == null ||
        sinceLastRun.isNegative ||
        sinceLastRun >= _resumeAfter) {
      _log.fine('Syncing on resume');
      _runNow();
    } else {
      _arm(_wait - sinceLastRun);
    }
  }

  /// The app left the front: nothing runs until [onResume].
  void onPause() {
    _active = false;
    _cancelTimer();
  }

  void dispose() {
    _disposed = true;
    onPause();
    unawaited(_subscription.cancel());
    unawaited(_writes?.cancel());
  }

  void _onStatus(SyncStatus status) {
    final running = status is SyncRunning;
    if (_wasRunning && !running) {
      _lastRunEndedAt = _clock();
      _afterRun(status);
      if (_active) _arm(_wait);
    } else if (!_wasRunning && !running && _lastRunEndedAt == null) {
      // The replayed status: when the last run ended before this scheduler
      // existed, as far as the engine remembers.
      _lastRunEndedAt = switch (status) {
        SyncIdle(:final lastSyncedAt) => lastSyncedAt,
        SyncFailed(:final lastSyncedAt) => lastSyncedAt,
        _ => null,
      };
    }
    _wasRunning = running;
  }

  void _afterRun(SyncStatus status) {
    switch (status) {
      case SyncIdle():
        _wait = _wrote || _backingOff ? interval : _doubled(_wait);
        _backingOff = false;
        _resumeAfter = interval;
      case SyncFailed(failure: RateLimited(:final retryAfter)):
        _backOff(retryAfter: retryAfter);
      case SyncFailed(failure: NetworkFailure() || ServerFailure()):
        _backOff();
      case _:
        break;
    }
    _wrote = false;
  }

  void _backOff({Duration? retryAfter}) {
    _backingOff = true;
    final doubled = _doubled(_wait);
    _wait = retryAfter != null && retryAfter > doubled
        ? _capped(retryAfter)
        : doubled;
    _resumeAfter = retryAfter != null && retryAfter > interval
        ? _capped(retryAfter)
        : interval;
  }

  void _onDataWrite() {
    if (_disposed) return;
    _wrote = true;
    if (_backingOff || _wait <= interval) return;
    _wait = interval;
    // Without a timer a run is under way or about to start; its end arms
    // the next wait.
    if (!_active || _timer == null) return;
    final sinceLastRun = _sinceLastRun();
    _arm(
      sinceLastRun == null || sinceLastRun.isNegative
          ? interval
          : interval - sinceLastRun,
    );
  }

  Duration? _sinceLastRun() => switch (_lastRunEndedAt) {
    final endedAt? => _clock().difference(endedAt),
    null => null,
  };

  Duration _doubled(Duration wait) => _capped(wait * 2);

  Duration _capped(Duration wait) => wait > maxInterval ? maxInterval : wait;

  void _onTimer() {
    _timer = null;
    if (!_active) return;
    _onForeground?.call(timed: true);
    // Started by someone else; its end arms the next wait.
    if (_engine.currentStatus is SyncRunning) return;
    _log.fine('Timed sync after $_wait');
    _runNow();
  }

  /// An account without a completed first run belongs to the first-sync
  /// screen; the timer looks again later.
  void _runNow() {
    if (needsFirstSync(_engine.currentStatus)) {
      _arm(_wait);
      return;
    }
    // The status stream reports the outcome.
    unawaited(_engine.refresh().then<void>((_) {}, onError: (Object _) {}));
  }

  void _arm(Duration duration) {
    _cancelTimer();
    _timer = _createTimer(
      duration.isNegative ? Duration.zero : duration,
      _onTimer,
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
