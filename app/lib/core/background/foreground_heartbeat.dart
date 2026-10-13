import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';

final _log = Logger('ForegroundHeartbeat');

typedef CreatePeriodicTimer = Timer Function(
  Duration period,
  void Function(Timer timer) callback,
);

/// Keeps background runs out while the app is in front: a beat on [resume]
/// and every [interval] until [pause]. On a timer of its own rather than
/// the foreground sync's, which waits for a long run and backs off up to
/// 5 min, longer than the 2 min a background run trusts a beat.
final class ForegroundHeartbeat {
  new({
    required this._runLog,
    DateTime Function()? now,
    this._createPeriodic = Timer.periodic,
    this.interval = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now;

  final BackgroundRunLog _runLog;
  final DateTime Function() _now;
  final CreatePeriodicTimer _createPeriodic;
  final Duration interval;
  Timer? _timer;

  bool get isBeating => _timer != null;

  void resume() {
    if (_timer != null) return;
    _beat();
    _timer = _createPeriodic(interval, (_) => _beat());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _beat() => unawaited(
    _runLog
        .beat(_now())
        .then<void>(
          (_) {},
          onError: (Object error) =>
              _log.info('Heartbeat not written: ${error.runtimeType}'),
        ),
  );
}
