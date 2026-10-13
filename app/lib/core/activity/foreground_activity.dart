import 'dart:async';

import 'package:logging/logging.dart';

final _log = Logger('ForegroundActivity');

/// The activity sync while the app is in front, riding on the foreground
/// sync's ticks: on start, on resume and every [ticksPerRun]th tick (about
/// every five minutes). The active account's inbox shows what arrives; the
/// other accounts get OS notifications. Runs never overlap; errors are
/// logged.
final class ForegroundActivity {
  new({
    required this._syncActive,
    required this._syncInactive,
    this.ticksPerRun = 5,
  });

  final Future<void> Function() _syncActive;
  final Future<void> Function() _syncInactive;
  final int ticksPerRun;
  var _ticks = 0;
  Future<void>? _running;

  /// [timed] for a timer tick, false for the start and a resume.
  void onForeground({required bool timed}) {
    if (timed && ++_ticks < ticksPerRun) return;
    _ticks = 0;
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
