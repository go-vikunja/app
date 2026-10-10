import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler.dart';

import '../../helpers/sync_fakes.dart';

final class FakeTimer implements Timer {
  new(this.duration, this._callback);

  final Duration duration;
  final void Function() _callback;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }
}

final class FakeTimers {
  final created = <FakeTimer>[];

  Timer create(Duration duration, void Function() callback) {
    final timer = FakeTimer(duration, callback);
    created.add(timer);
    return timer;
  }

  List<FakeTimer> get active => [
    for (final timer in created)
      if (timer.isActive) timer,
  ];

  void fire() => active.single.fire();
}

void main() {
  const minute = Duration(seconds: 60);
  final start = DateTime.utc(2026, 10, 10, 12);
  late DateTime current;
  late FakeTimers timers;
  late FakeSyncEngine engine;

  setUp(() {
    current = start;
    timers = FakeTimers();
  });

  ForegroundSyncScheduler buildScheduler({SyncStatus? status}) {
    engine = FakeSyncEngine(
      initialStatus: status ?? SyncIdle(lastSyncedAt: start),
      clock: () => current,
    );
    final scheduler = ForegroundSyncScheduler(
      engine: engine,
      clock: () => current,
      createTimer: timers.create,
    );
    addTearDown(scheduler.dispose);
    return scheduler;
  }

  Duration pendingWait() => timers.active.single.duration;

  test('syncs a minute after the start and a minute after each run '
      'ends', () async {
    buildScheduler().start();
    expect(pendingWait(), minute);
    expect(engine.refreshCalls, 0);

    timers.fire();
    await pumpEventQueue();

    expect(engine.refreshCalls, 1);
    expect(engine.fullResyncCalls, 0);
    expect(engine.currentStatus, isA<SyncIdle>());
    expect(pendingWait(), minute);

    timers.fire();
    await pumpEventQueue();
    expect(engine.refreshCalls, 2);
  });

  test('a run started elsewhere restarts the countdown', () async {
    buildScheduler().start();
    final armedAtStart = timers.active.single;

    await engine.refresh();
    await pumpEventQueue();

    expect(armedAtStart.isActive, isFalse);
    expect(pendingWait(), minute);
    expect(engine.refreshCalls, 1);
  });

  test('never starts a second run; the running one ends the wait', () async {
    buildScheduler().start();
    final gate = Completer<void>();
    engine.onRefresh = () => gate.future;
    final running = engine.refresh();
    await pumpEventQueue();

    timers.fire();
    await pumpEventQueue();
    expect(engine.refreshCalls, 1);
    expect(timers.active, isEmpty);

    gate.complete();
    await running;
    await pumpEventQueue();
    expect(pendingWait(), minute);
  });

  test('doubles the wait after network failures up to five minutes and '
      'resets it after a completed run', () async {
    final scheduler = buildScheduler()..start();
    engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    for (final seconds in [120, 240, 300, 300]) {
      timers.fire();
      await pumpEventQueue();
      expect(pendingWait(), Duration(seconds: seconds));
      expect(scheduler.wait, Duration(seconds: seconds));
    }
    expect(engine.refreshCalls, 4);

    engine.onRefresh = null;
    timers.fire();
    await pumpEventQueue();
    expect(pendingWait(), minute);
    expect(scheduler.wait, minute);
  });

  test('other failures keep the wait', () async {
    buildScheduler().start();
    engine.onRefresh = () async => throw const ServerFailure(500);

    timers.fire();
    await pumpEventQueue();

    expect(engine.currentStatus, isA<SyncFailed>());
    expect(pendingWait(), minute);
  });

  group('resume', () {
    test('syncs when the last run ended more than a minute ago', () async {
      final scheduler = buildScheduler(
        status: SyncIdle(
          lastSyncedAt: start.subtract(const Duration(hours: 1)),
        ),
      );
      await pumpEventQueue();

      scheduler.onResume();
      await pumpEventQueue();

      expect(engine.refreshCalls, 1);
      expect(pendingWait(), minute);
    });

    test('within a minute of the last run waits for the rest', () async {
      final scheduler = buildScheduler(
        status: SyncIdle(
          lastSyncedAt: start.subtract(const Duration(seconds: 45)),
        ),
      );
      await pumpEventQueue();

      scheduler.onResume();

      expect(engine.refreshCalls, 0);
      expect(pendingWait(), const Duration(seconds: 15));
    });

    test('during a run leaves it alone; its end starts the wait', () async {
      final scheduler = buildScheduler(
        status: const SyncRunning(
          phase: SyncPhase.tasks,
          done: 1,
          initial: false,
        ),
      );
      await pumpEventQueue();

      scheduler.onResume();
      expect(engine.refreshCalls, 0);
      expect(timers.active, isEmpty);

      engine.emit(SyncIdle(lastSyncedAt: current));
      await pumpEventQueue();
      expect(pendingWait(), minute);
    });

    test('after a failed run retries once a minute has passed', () async {
      final scheduler = buildScheduler()..start();
      engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      timers.fire();
      await pumpEventQueue();
      expect(scheduler.wait, const Duration(seconds: 120));
      scheduler.onPause();

      current = current.add(const Duration(seconds: 90));
      scheduler.onResume();
      await pumpEventQueue();

      expect(engine.refreshCalls, 2);
      expect(pendingWait(), const Duration(seconds: 240));
    });
  });

  test('a resume without a pause before it, like a dialog closing, leaves '
      'the wait after a failure alone', () async {
    final scheduler = buildScheduler()..start();
    engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    timers.fire();
    await pumpEventQueue();
    expect(scheduler.wait, const Duration(seconds: 120));
    final armed = timers.active.single;

    current = current.add(const Duration(seconds: 70));
    scheduler.onResume();
    await pumpEventQueue();

    expect(engine.refreshCalls, 1);
    expect(timers.active.single, same(armed));
  });

  test('pause stops the timer and a run ending while paused arms '
      'nothing', () async {
    final scheduler = buildScheduler()
      ..start()
      ..onPause();
    expect(timers.active, isEmpty);

    await engine.refresh();
    await pumpEventQueue();
    expect(timers.active, isEmpty);

    current = current.add(const Duration(minutes: 2));
    scheduler.onResume();
    await pumpEventQueue();
    expect(engine.refreshCalls, 2);
  });

  test('dispose cancels the timer and ignores everything after', () async {
    final scheduler = buildScheduler()
      ..start()
      ..dispose();
    expect(timers.active, isEmpty);

    await engine.refresh();
    await pumpEventQueue();
    current = current.add(const Duration(hours: 1));
    scheduler
      ..onResume()
      ..start();

    expect(timers.active, isEmpty);
    expect(engine.refreshCalls, 1);
  });

  test('leaves an account without a completed first sync to the first-sync '
      'screen and looks again later', () async {
    buildScheduler(status: const SyncNeverRun()).start();

    timers.fire();
    await pumpEventQueue();

    expect(engine.refreshCalls, 0);
    expect(pendingWait(), minute);
  });
}
