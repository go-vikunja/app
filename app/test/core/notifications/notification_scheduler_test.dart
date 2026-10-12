import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

import '../../helpers/fake_timers.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  const accountId = 'a1';
  const alice = User(id: 7, username: 'alice');
  const bob = User(id: 8, username: 'bob');
  final monday = DateTime.utc(2026, 10, 12, 9);
  final reminderAt = monday.add(const Duration(hours: 1));
  final dueAt = monday.add(const Duration(hours: 2));
  final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
  final dueId = notificationOsIdFor(accountId, '1:due');
  late AppDatabase db;
  late FakeNotificationGateway gateway;
  late FakeNotificationPreferencesStore preferences;
  late FakeTimers timers;
  late DateTime now;

  Task water({List<TaskReminder>? reminders, bool withDue = true}) =>
      sampleTask(
        id: 1,
        title: 'Water the plants',
        projectId: 7,
        due: withDue ? dueAt : null,
        reminders: reminders ?? [TaskReminder(reminder: reminderAt)],
      ).copyWith(createdBy: alice);

  setUp(() async {
    db = testDatabase();
    gateway = FakeNotificationGateway();
    preferences = FakeNotificationPreferencesStore();
    addTearDown(preferences.dispose);
    timers = FakeTimers();
    now = monday;
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([water()], syncRunId: 'run');
  });

  NotificationScheduler scheduler({int window = 100, AppDatabase? database}) {
    final scheduler = NotificationScheduler(
      accountId: accountId,
      userId: alice.id,
      db: database ?? db,
      gateway: gateway,
      preferences: preferences,
      describe: describeNotificationsWith(AppLocalizationsEn()),
      window: window,
      now: () => now,
      createTimer: timers.create,
    );
    addTearDown(scheduler.dispose);
    return scheduler;
  }

  Future<List<ScheduledNotificationRow>> rows() =>
      db.scheduledNotificationsDao.all();

  test(
    'reconcile schedules the plan, writes the table and is then idle',
    () async {
      final notifications = scheduler();

      await notifications.reconcile();

      expect(gateway.scheduled.map((n) => n.osId), [reminderId, dueId]);
      final reminder = gateway.scheduled.first;
      expect(reminder.fireAt, reminderAt);
      expect(reminder.title, 'Water the plants');
      expect(reminder.body, 'Reminder · Work');
      expect(reminder.exact, isTrue);
      final payload = NotificationPayload.fromJson(reminder.payload);
      expect(payload.accountId, accountId);
      expect(payload.taskId, 1);
      expect(payload.key, '1:reminder:0');
      expect(gateway.scheduled.last.body, 'Due now · Work');
      expect(gateway.cancelled, isEmpty);
      final stored = await rows();
      expect(stored.map((r) => r.key), ['1:reminder:0', '1:due']);
      expect(stored.map((r) => r.osId), [reminderId, dueId]);
      expect(stored.first.kind, 'reminder');
      expect(stored.first.fireAt, reminderAt);
      expect(stored.first.snoozedUntil, isNull);

      gateway.calls.clear();
      await notifications.reconcile();

      expect(gateway.calls, ['capabilities', 'pendingIds']);
    },
  );

  test('without exact alarms the notifications are inexact', () async {
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: false,
    );

    await scheduler().reconcile();

    expect(gateway.scheduled.map((n) => n.exact), [false, false]);
    expect((await rows()).map((r) => r.exact), [false, false]);
  });

  test('exact alarms allowed after the first run reschedules every row '
      'exactly', () async {
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: false,
    );
    final notifications = scheduler();
    await notifications.reconcile();
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: true,
    );
    gateway.calls.clear();

    await notifications.reconcile();

    expect(gateway.calls, [
      'capabilities',
      'pendingIds',
      'cancel $reminderId',
      'cancel $dueId',
      'schedule $reminderId',
      'schedule $dueId',
    ]);
    expect(gateway.pending.values.every((n) => n.exact), isTrue);
    expect((await rows()).map((r) => r.exact), [true, true]);
  });

  test('exact alarms revoked reschedules every row inexactly although '
      'pendingIds still lists them', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    expect(gateway.pending.values.every((n) => n.exact), isTrue);
    // The plugin's pending list is a cache that does not notice the OS
    // dropping the exact alarms.
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: false,
    );
    gateway.calls.clear();

    await notifications.reconcile();

    expect(gateway.calls.where((c) => c.startsWith('schedule')), [
      'schedule $reminderId',
      'schedule $dueId',
    ]);
    expect(gateway.pending.values.every((n) => !n.exact), isTrue);
    expect((await rows()).map((r) => r.exact), [false, false]);
  });

  test('a changed time is rescheduled under the same id, a gone reminder '
      'is cancelled, a new task takes its own id', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    gateway.calls.clear();
    final later = reminderAt.add(const Duration(minutes: 30));
    await db.tasksDao.upsertAll([
      water(reminders: [TaskReminder(reminder: later)], withDue: false),
      sampleTask(
        id: 2,
        title: 'Second',
        projectId: 7,
        due: dueAt,
        assignees: const [alice],
      ).copyWith(createdBy: bob),
    ], syncRunId: 'run');

    await notifications.reconcile();

    final secondId = notificationOsIdFor(accountId, '2:due');
    expect(gateway.calls, [
      'capabilities',
      'pendingIds',
      'cancel $reminderId',
      'cancel $dueId',
      'schedule $reminderId',
      'schedule $secondId',
    ]);
    expect(gateway.pending.keys, unorderedEquals([reminderId, secondId]));
    expect(gateway.pending[reminderId]!.fireAt, later);
    expect((await rows()).map((r) => r.key), ['1:reminder:0', '2:due']);
  });

  test('only the first window entries reach the OS', () async {
    await scheduler(window: 1).reconcile();

    expect(gateway.scheduled.map((n) => n.osId), [reminderId]);
    expect((await rows()).map((r) => r.key), ['1:reminder:0']);
  });

  test('a database change reconciles after the debounce', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    expect(timers.active, isEmpty);

    await db.tasksDao.upsertAll([water(withDue: false)], syncRunId: 'run');
    await pumpEventQueue();
    expect(timers.pendingWait, const Duration(milliseconds: 700));
    expect(gateway.cancelled, isEmpty);

    timers.fireNext();
    await pumpEventQueue();

    expect(gateway.cancelled, [dueId]);
    expect((await rows()).map((r) => r.key), ['1:reminder:0']);
  });

  test("a change of this account's preferences reconciles at once; other "
      "accounts' do not", () async {
    final notifications = scheduler();
    await notifications.reconcile();

    await preferences.write(
      'other',
      const NotificationPreferences(dueDates: false),
    );
    await pumpEventQueue();
    expect(gateway.cancelled, isEmpty);

    await preferences.write(
      accountId,
      const NotificationPreferences(dueDates: false),
    );
    await pumpEventQueue();

    expect(gateway.cancelled, [dueId]);
    expect(timers.active, isEmpty);
  });

  test('without the permission everything is cancelled and the table '
      'emptied', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    gateway.current = const NotificationCapabilities(
      permission: NotificationPermission.denied,
      exactAlarms: true,
    );

    await notifications.reconcile();

    expect(gateway.cancelled, unorderedEquals([reminderId, dueId]));
    expect(gateway.pending, isEmpty);
    expect(await rows(), isEmpty);
  });

  test('with every kind switched off nothing is scheduled', () async {
    await preferences.write(
      accountId,
      const NotificationPreferences(reminders: false, dueDates: false),
    );

    await scheduler().reconcile();

    expect(gateway.scheduled, isEmpty);
    expect(await rows(), isEmpty);
  });

  test('a notification the OS dropped is scheduled again while it is still '
      'wanted', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    gateway.fire(dueId);
    gateway.calls.clear();

    await notifications.reconcile();

    expect(gateway.calls, ['capabilities', 'pendingIds', 'schedule $dueId']);
  });

  test('a snooze brings a fired reminder back at the snoozed time, under '
      'its id', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    now = reminderAt.add(const Duration(minutes: 1));
    gateway.fire(reminderId);
    final until = now.add(const Duration(minutes: 10));
    await db.scheduledNotificationsDao.setSnooze(
      '1:reminder:0',
      until: until,
      originalFireAt: reminderAt,
    );
    gateway.calls.clear();

    await notifications.reconcile();

    expect(gateway.calls, [
      'capabilities',
      'pendingIds',
      'schedule $reminderId',
    ]);
    expect(gateway.pending[reminderId]!.fireAt, until);
    final stored = (await rows()).first;
    expect(stored.key, '1:reminder:0');
    expect(stored.fireAt, until);
    expect(stored.snoozedUntil, until);
    expect(stored.snoozeOriginalFireAt, reminderAt);

    // Once the snooze has fired too, the entry is gone.
    now = until.add(const Duration(minutes: 1));
    gateway.fire(reminderId);
    await notifications.reconcile();
    expect((await rows()).map((r) => r.key), ['1:due']);
  });

  test('a snooze written by another scheduler during a run is kept, and '
      'the OS ends up with the snoozed time', () async {
    final first = scheduler();
    final second = scheduler();
    await first.reconcile();
    now = reminderAt.add(const Duration(minutes: 1));
    gateway.fire(reminderId);
    final until = now.add(const Duration(minutes: 10));
    final gate = Completer<void>();
    var pendingCalls = 0;
    gateway.beforeCall = (call) => call == 'pendingIds' && ++pendingCalls == 1
        ? gate.future
        : Future.value();

    // The first run has read the table (without the snooze) and waits on
    // the OS; the snooze lands and the second scheduler schedules it.
    final run = first.reconcile();
    await pumpEventQueue();
    await db.scheduledNotificationsDao.setSnooze(
      '1:reminder:0',
      until: until,
      originalFireAt: reminderAt,
    );
    await second.reconcile();
    expect(gateway.pending[reminderId]!.fireAt, until);
    gate.complete();
    await run;

    expect(gateway.pending[reminderId]!.fireAt, until);
    final stored = (await rows()).firstWhere((r) => r.key == '1:reminder:0');
    expect(stored.fireAt, until);
    expect(stored.snoozedUntil, until);
    expect(stored.snoozeOriginalFireAt, reminderAt);
    // The first run saw the change at its write and went once more.
    expect(pendingCalls, 3);
  });

  group('snooze', () {
    test('without a row, a fired reminder is taken from the task and '
        'handed to the OS before the reconcile', () async {
      final notifications = scheduler();
      await notifications.reconcile();
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      await notifications.reconcile();
      expect((await rows()).map((r) => r.key), ['1:due']);
      gateway.calls.clear();

      await notifications.snooze(
        key: '1:reminder:0',
        taskId: 1,
        duration: const Duration(minutes: 10),
      );

      final until = now.add(const Duration(minutes: 10));
      expect(gateway.calls.take(2), ['capabilities', 'schedule $reminderId']);
      expect(gateway.pending[reminderId]!.fireAt, until);
      expect(gateway.pending[reminderId]!.title, 'Water the plants');
      expect(gateway.pending[reminderId]!.body, 'Reminder · Work');
      final stored = (await rows()).firstWhere((r) => r.key == '1:reminder:0');
      expect(stored.osId, reminderId);
      expect(stored.fireAt, until);
      expect(stored.snoozedUntil, until);
      expect(stored.snoozeOriginalFireAt, reminderAt);
      expect(stored.exact, isTrue);
    });

    test('a key of a temporary id follows the task to its server id', () async {
      await db.tasksDao.upsertAll([
        water(reminders: [TaskReminder(reminder: reminderAt)], withDue: false),
      ], syncRunId: 'run');
      await db
          .into(db.taskIdRemaps)
          .insert(TaskIdRemapRow(localId: -5, serverId: 1, at: now));
      now = reminderAt.add(const Duration(minutes: 1));
      final notifications = scheduler();
      await notifications.reconcile();

      await notifications.snooze(
        key: '-5:reminder:0',
        taskId: -5,
        duration: const Duration(minutes: 10),
      );

      final stored = await rows();
      expect(stored.map((r) => r.key), ['1:reminder:0']);
      expect(stored.single.taskId, 1);
      expect(gateway.pending.keys, [reminderId]);
    });

    test('is ignored for a task that is gone, done or whose time moved '
        'ahead, and for a key that is not one', () async {
      final notifications = scheduler();
      now = reminderAt.add(const Duration(minutes: 1));
      await notifications.reconcile();
      expect((await rows()).map((r) => r.key), ['1:due']);
      gateway.calls.clear();

      await notifications.snooze(
        key: '9:due',
        taskId: 9,
        duration: const Duration(minutes: 10),
      );
      await db.tasksDao.upsertAll([
        water(withDue: false).copyWith(done: true),
      ], syncRunId: 'run');
      await notifications.snooze(
        key: '1:reminder:0',
        taskId: 1,
        duration: const Duration(minutes: 10),
      );
      await db.tasksDao.upsertAll([
        water(reminders: [TaskReminder(reminder: dueAt)], withDue: false),
      ], syncRunId: 'run');
      await notifications.snooze(
        key: '1:reminder:0',
        taskId: 1,
        duration: const Duration(minutes: 10),
      );
      await notifications.snooze(
        key: 'test',
        taskId: 0,
        duration: const Duration(minutes: 10),
      );

      expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);
      expect(await db.scheduledNotificationsDao.find('1:reminder:0'), isNull);
    });
  });

  test('a call during a run makes it look once more', () async {
    final notifications = scheduler();
    final gate = Completer<void>();
    gateway.beforeCall = (call) =>
        call == 'capabilities' && gateway.calls.length == 1
        ? gate.future
        : Future.value();

    final first = notifications.reconcile();
    final second = notifications.reconcile();
    expect(identical(first, second), isTrue);
    await pumpEventQueue();
    expect(gateway.calls, ['capabilities']);

    gate.complete();
    await first;

    expect(gateway.calls.where((c) => c == 'capabilities').length, 2);
  });

  test('dispose stops the triggers', () async {
    final notifications = scheduler();
    await notifications.reconcile();
    await notifications.dispose();

    await db.tasksDao.upsertAll([water(withDue: false)], syncRunId: 'run');
    await preferences.write(
      accountId,
      const NotificationPreferences(dueDates: false),
    );
    await pumpEventQueue();
    await notifications.reconcile();

    expect(timers.active, isEmpty);
    expect(gateway.cancelled, isEmpty);
  });

  test('cancelAll after dispose cancels the ids of the last run even once '
      'the database is closed', () async {
    final closable = AppDatabase(NativeDatabase.memory());
    await closable.projectsDao.upsertAll([sampleProject(id: 7, title: 'W')]);
    await closable.tasksDao.upsertAll([water()], syncRunId: 'run');
    final notifications = scheduler(database: closable);
    await notifications.reconcile();
    await notifications.dispose();
    await closable.close();

    await notifications.cancelAll();

    expect(gateway.cancelled, unorderedEquals([reminderId, dueId]));
    expect(gateway.pending, isEmpty);
  });
}
