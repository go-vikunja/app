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
/// [interval] after the last run ended, whoever started that run, and one on
/// resume when the last run is older than [interval]. Consecutive network
/// failures double the wait up to [maxInterval]; a completed run resets it.
/// A run in progress is never doubled: the timer waits for its end, which
/// starts the next wait.
final class ForegroundSyncScheduler {
  new({
    required this._engine,
    required this._clock,
    this._createTimer = Timer.new,
    this.interval = const Duration(seconds: 60),
    this.maxInterval = const Duration(minutes: 5),
  }) : _wait = interval {
    _subscription = _engine.status.listen(_onStatus);
  }

  final SyncEngine _engine;
  final DateTime Function() _clock;
  final TimerFactory _createTimer;
  final Duration interval;
  final Duration maxInterval;

  late final StreamSubscription<SyncStatus> _subscription;
  Duration _wait;
  DateTime? _lastRunEndedAt;
  var _wasRunning = false;
  var _active = false;
  var _disposed = false;
  Timer? _timer;

  /// The wait before the next timed run; grows while the server is
  /// unreachable.
  Duration get wait => _wait;

  /// The app is in front; the first timed run is [wait] from now.
  void start() {
    if (_disposed) return;
    _active = true;
    _arm(_wait);
  }

  /// The app came back to the front: a run when the last one is older than
  /// [interval], otherwise the timer continues where the pause left it. A
  /// resume without a pause before it (a dialog, the notification shade)
  /// changes nothing, so the wait after a failure holds.
  void onResume() {
    if (_disposed || _active) return;
    _active = true;
    if (_engine.currentStatus is SyncRunning) return;
    final sinceLastRun = switch (_lastRunEndedAt) {
      final endedAt? => _clock().difference(endedAt),
      null => null,
    };
    if (sinceLastRun == null || sinceLastRun >= interval) {
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
  }

  void _onStatus(SyncStatus status) {
    final running = status is SyncRunning;
    if (_wasRunning && !running) {
      _lastRunEndedAt = _clock();
      _wait = switch (status) {
        SyncIdle() => interval,
        SyncFailed(failure: NetworkFailure()) => _doubled(_wait),
        _ => _wait,
      };
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

  Duration _doubled(Duration wait) =>
      wait * 2 > maxInterval ? maxInterval : wait * 2;

  void _onTimer() {
    _timer = null;
    if (!_active) return;
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
