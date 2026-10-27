import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final monday = DateTime.utc(2026, 10, 12, 9);
  final tuesday = DateTime.utc(2026, 10, 13, 9);

  ScheduledNotificationRow row(
    String key, {
    required int osId,
    required int taskId,
    DateTime? at,
  }) => ScheduledNotificationRow(
    key: key,
    osId: osId,
    taskId: taskId,
    kind: 'reminder',
    fireAt: at ?? monday,
    title: 'T',
    body: 'B',
    exact: true,
    hiddenOnLockScreen: false,
    doneNeedsUnlock: false,
  );

  setUp(() => db = testDatabase());

  test('replaceAll makes the table exactly the rows, ordered by time then '
      'key', () async {
    await db.scheduledNotificationsDao.replaceAll([
      row('9:due', osId: 9, taskId: 9),
    ]);

    await db.scheduledNotificationsDao.replaceAll([
      row('2:due', osId: 20, taskId: 2, at: tuesday),
      row('1:reminder:1', osId: 11, taskId: 1),
      row('1:reminder:0', osId: 10, taskId: 1),
    ]);

    expect((await db.scheduledNotificationsDao.all()).map((r) => r.key), [
      '1:reminder:0',
      '1:reminder:1',
      '2:due',
    ]);
    expect(await db.scheduledNotificationsDao.osIds(), {10, 11, 20});
    expect((await db.scheduledNotificationsDao.find('2:due'))!.osId, 20);
    expect(await db.scheduledNotificationsDao.find('9:due'), isNull);
  });

  test('replaceAll leaves the table alone when it changed since the rows '
      'were read', () async {
    await db.scheduledNotificationsDao.replaceAll([
      row('1:due', osId: 5, taskId: 1),
    ]);
    final read = await db.scheduledNotificationsDao.all();
    await db.scheduledNotificationsDao.setSnooze(
      '1:due',
      until: tuesday,
      originalFireAt: monday,
    );

    final written = await db.scheduledNotificationsDao.replaceAll([
      row('2:due', osId: 6, taskId: 2),
    ], sinceRead: read);

    expect(written, isFalse);
    final stored = await db.scheduledNotificationsDao.all();
    expect(stored.map((r) => r.key), ['1:due']);
    expect(stored.single.snoozedUntil, tuesday);

    expect(
      await db.scheduledNotificationsDao.replaceAll([
        row('2:due', osId: 6, taskId: 2),
      ], sinceRead: stored),
      isTrue,
    );
    expect(await db.scheduledNotificationsDao.osIds(), {6});
  });

  test('upsert inserts a row or replaces the one with its key', () async {
    await db.scheduledNotificationsDao.upsert(row('1:due', osId: 5, taskId: 1));
    await db.scheduledNotificationsDao.upsert(
      row('1:due', osId: 5, taskId: 1, at: tuesday),
    );
    await db.scheduledNotificationsDao.upsert(row('2:due', osId: 6, taskId: 2));

    final stored = await db.scheduledNotificationsDao.all();
    expect(stored.map((r) => r.key), ['2:due', '1:due']);
    expect(stored.last.fireAt, tuesday);
  });

  test('watchCount follows the rows', () async {
    final counts = <int>[];
    final subscription = db.scheduledNotificationsDao.watchCount().listen(
      counts.add,
    );
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await db.scheduledNotificationsDao.replaceAll([
      row('1:due', osId: 5, taskId: 1),
      row('2:due', osId: 6, taskId: 2),
    ]);
    await pumpEventQueue();
    await db.scheduledNotificationsDao.deleteAll();
    await pumpEventQueue();

    expect(counts, [0, 2, 0]);
  });

  test('an os id is unique', () async {
    await expectLater(
      db.scheduledNotificationsDao.replaceAll([
        row('1:due', osId: 5, taskId: 1),
        row('2:due', osId: 5, taskId: 2),
      ]),
      throwsA(anything),
    );
  });

  test('a snooze is set and cleared without touching the fire time', () async {
    await db.scheduledNotificationsDao.replaceAll([
      row('1:due', osId: 5, taskId: 1),
    ]);
    final until = monday.add(const Duration(minutes: 10));

    await db.scheduledNotificationsDao.setSnooze(
      '1:due',
      until: until,
      originalFireAt: monday,
    );
    var stored = (await db.scheduledNotificationsDao.find('1:due'))!;
    expect(stored.fireAt, monday);
    expect(stored.snoozedUntil, until);
    expect(stored.snoozeOriginalFireAt, monday);

    await db.scheduledNotificationsDao.clearSnooze('1:due');
    stored = (await db.scheduledNotificationsDao.find('1:due'))!;
    expect(stored.snoozedUntil, isNull);
    expect(stored.snoozeOriginalFireAt, isNull);
  });

  test('rows go by task ids or all at once', () async {
    await db.scheduledNotificationsDao.replaceAll([
      row('1:due', osId: 1, taskId: 1),
      row('1:reminder:0', osId: 2, taskId: 1),
      row('2:due', osId: 3, taskId: 2),
      row('-3:due', osId: 4, taskId: -3),
    ]);

    expect(
      (await db.scheduledNotificationsDao.forTasks({1, -3})).map((r) => r.osId),
      unorderedEquals([1, 2, 4]),
    );
    expect(await db.scheduledNotificationsDao.deleteForTasks({1, -3}), 3);
    expect(await db.scheduledNotificationsDao.osIds(), {3});

    expect(await db.scheduledNotificationsDao.deleteAll(), 1);
    expect(await db.scheduledNotificationsDao.all(), isEmpty);
  });
}
