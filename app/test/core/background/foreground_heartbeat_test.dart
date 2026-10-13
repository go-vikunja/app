import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/foreground_heartbeat.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  late DateTime now;
  late MemoryPreferencesStore preferences;
  late List<void Function(Timer)> ticks;
  late List<_FakePeriodicTimer> timers;
  late ForegroundHeartbeat heartbeat;

  setUp(() {
    now = monday;
    preferences = MemoryPreferencesStore();
    ticks = [];
    timers = [];
    heartbeat = ForegroundHeartbeat(
      runLog: BackgroundRunLog(preferences),
      now: () => now,
      createPeriodic: (period, callback) {
        expect(period, const Duration(seconds: 30));
        ticks.add(callback);
        return _add(timers);
      },
    );
  });

  Future<DateTime?> lastBeat() async {
    await pumpEventQueue();
    return await BackgroundRunLog(preferences).lastHeartbeat();
  }

  test('beats on resume and every 30 s, whatever the sync does, until '
      'paused', () async {
    heartbeat.resume();
    expect(await lastBeat(), monday);

    for (var tick = 1; tick <= 10; tick++) {
      now = monday.add(Duration(seconds: 30 * tick));
      ticks.single(timers.single);
    }
    expect(await lastBeat(), monday.add(const Duration(minutes: 5)));

    heartbeat.pause();
    expect(timers.single.isActive, isFalse);
    expect(heartbeat.isBeating, isFalse);
  });

  test('a second resume keeps the one timer', () async {
    heartbeat
      ..resume()
      ..resume();

    expect(timers, hasLength(1));
  });
}

_FakePeriodicTimer _add(List<_FakePeriodicTimer> timers) {
  final timer = _FakePeriodicTimer();
  timers.add(timer);
  return timer;
}

final class _FakePeriodicTimer implements Timer {
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}
