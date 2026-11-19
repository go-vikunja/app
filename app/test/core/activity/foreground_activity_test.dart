import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/activity/foreground_activity.dart';

void main() {
  late List<String> syncs;
  late ForegroundActivity activity;
  late DateTime now;
  Completer<void>? gate;

  setUp(() {
    syncs = [];
    gate = null;
    now = DateTime.utc(2026, 11, 19, 9);
    activity = ForegroundActivity(
      syncActive: () async {
        syncs.add('active');
        await gate?.future;
      },
      syncInactive: () async => syncs.add('inactive'),
      clock: () => now,
    );
  });

  test('start and resume sync at once, a tick once five minutes have '
      'passed, however far apart the ticks are', () async {
    activity.onForeground(timed: false);
    await pumpEventQueue();
    expect(syncs, ['active', 'inactive']);

    final started = now;
    for (final minutes in [1, 3, 4]) {
      now = started.add(Duration(minutes: minutes));
      activity.onForeground(timed: true);
    }
    await pumpEventQueue();
    expect(syncs, hasLength(2));

    now = started.add(const Duration(minutes: 5));
    activity.onForeground(timed: true);
    await pumpEventQueue();
    expect(syncs, hasLength(4));

    activity.onForeground(timed: false);
    await pumpEventQueue();
    expect(syncs, hasLength(6));
  });

  test('a resume restarts the count of ticks', () async {
    for (var tick = 1; tick <= 4; tick++) {
      activity.onForeground(timed: true);
    }
    activity.onForeground(timed: false);
    await pumpEventQueue();
    syncs.clear();

    activity.onForeground(timed: true);
    await pumpEventQueue();
    expect(syncs, isEmpty);
  });

  test('runs never overlap', () async {
    gate = Completer<void>();
    activity
      ..onForeground(timed: false)
      ..onForeground(timed: false);
    await pumpEventQueue();
    expect(syncs, ['active']);

    gate!.complete();
    await pumpEventQueue();
    expect(syncs, ['active', 'inactive']);
  });

  test(
    'a failure of the active account does not keep the others waiting',
    () async {
      ForegroundActivity(
        syncActive: () async => throw StateError('offline'),
        syncInactive: () async => syncs.add('inactive'),
      ).onForeground(timed: false);
      await pumpEventQueue();

      expect(syncs, ['inactive']);
    },
  );
}
