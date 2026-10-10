import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'clock_tick_provider.g.dart';

/// "Now" for everything on screen that depends on the time of day: re-read
/// when the app comes back to the foreground and every minute while it is in
/// front, so due-date sections and relative labels never freeze. Backgrounded,
/// nothing ticks.
@Riverpod(keepAlive: true)
class ClockTick extends _$ClockTick {
  static const period = Duration(minutes: 1);

  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final lifecycle = AppLifecycleListener(
      onResume: _tick,
      onShow: _start,
      onHide: _stop,
      onPause: _stop,
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _stop();
    });
    if (WidgetsBinding.instance.lifecycleState
        case null || AppLifecycleState.resumed || AppLifecycleState.inactive) {
      _start();
    }
    return clock();
  }

  void _tick() {
    _tickNow();
    _start();
  }

  void _start() => _timer ??= Timer.periodic(period, (_) => _tickNow());

  void _tickNow() => state = ref.read(clockProvider)();

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
