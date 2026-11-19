import 'dart:async';

import 'package:logging/logging.dart';

final _log = Logger('ForegroundActivity');

/// The activity sync while the app is in front, riding on the foreground
/// sync's ticks: on start, on resume and on the first tick at least [every]
/// after its last run. The ticks come one to five minutes apart, so that
/// is about every five minutes. The active account's inbox shows what
/// arrives; the other accounts get OS notifications. Runs never overlap;
/// errors are logged.
final class ForegroundActivity {
  new({
    required this._syncActive,
    required this._syncInactive,
    DateTime Function()? clock,
    this.every = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now;

  final Future<void> Function() _syncActive;
  final Future<void> Function() _syncInactive;
  final DateTime Function() _clock;
  final Duration every;
  DateTime? _lastRunAt;
  Future<void>? _running;

  /// [timed] for a timer tick, false for the start and a resume.
  void onForeground({required bool timed}) {
    final now = _clock();
    final sinceLastRun = switch (_lastRunAt) {
      final at? => now.difference(at),
      null => null,
    };
    if (timed &&
        sinceLastRun != null &&
        !sinceLastRun.isNegative &&
        sinceLastRun < every) {
      return;
    }
    _lastRunAt = now;
    _running ??= _sync().whenComplete(() => _running = null);
  }

  Future<void> _sync() async {
    for (final (what, sync) in [
      ('active', _syncActive),
      ('inactive', _syncInactive),
    ]) {
      try {
        await sync();
      } on Object catch (error) {
        _log.info(
          'Activity sync of the $what account failed: ${error.runtimeType}',
        );
      }
    }
  }
}
