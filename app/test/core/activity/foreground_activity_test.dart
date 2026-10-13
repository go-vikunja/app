import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/activity/foreground_activity.dart';

void main() {
  late List<String> syncs;
  late ForegroundActivity activity;
  Completer<void>? gate;

  setUp(() {
    syncs = [];
    gate = null;
    activity = ForegroundActivity(
      syncActive: () async {
        syncs.add('active');
        await gate?.future;
      },
      syncInactive: () async => syncs.add('inactive'),
    );
  });

  test('start and resume sync at once, the timer every fifth tick', () async {
    activity.onForeground(timed: false);
    await pumpEventQueue();
    expect(syncs, ['active', 'inactive']);

    for (var tick = 1; tick <= 4; tick++) {
      activity.onForeground(timed: true);
    }
    await pumpEventQueue();
    expect(syncs, hasLength(2));

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
