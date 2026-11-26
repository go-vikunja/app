import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/berlin.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/trash_fakes.dart';
import '../../helpers/widget_fakes.dart';

// The handler over the real providers: an in-memory database per account,
// the real repository, sender and scheduler, with the clients, the engine
// and the notification plugin faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const alice = User(id: 7, username: 'alice');
  final monday = DateTime.utc(2026, 10, 12, 9);
  final reminderAt = monday.add(const Duration(hours: 1));
  final dueAt = monday.add(const Duration(hours: 2));
  final water = sampleTask(
    id: 1,
    title: 'Water the plants',
    projectId: 7,
    due: dueAt,
    reminders: [TaskReminder(reminder: reminderAt)],
  ).copyWith(createdBy: alice);
  final second = sampleTask(
    id: 2,
    title: 'Second',
    projectId: 7,
    due: dueAt.add(const Duration(hours: 1)),
  ).copyWith(createdBy: alice);
  late DateTime now;
  late AuthFakes auth;
  late List<AppDatabase> opened;
  late RecordingSyncEngine engine;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late FakeNotificationGateway gateway;
  late FakeBackgroundScheduler background;
  late FakeWidgetHost widgets;
  late ProviderContainer container;
  late NotificationActionHandler handler;

  setUp(() {
    now = monday;
    auth = AuthFakes();
    final files = FakeAccountDatabaseFiles();
    opened = [];
    engine = RecordingSyncEngine(SyncIdle(lastSyncedAt: monday));
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    gateway = FakeNotificationGateway();
    background = FakeBackgroundScheduler();
    widgets = FakeWidgetHost();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) {
              final db = AppDatabase(NativeDatabase.memory());
              opened.add(db);
              return db;
            },
          ),
        ),
        syncEngineProvider.overrideWith((ref, accountId) => engine),
        writeClientProvider.overrideWith((ref, accountId) => write),
        readClientProvider.overrideWith((ref, accountId) => read),
        trashPortProvider.overrideWith((ref, accountId) => FakeTrashPort()),
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
        backgroundSchedulerProvider.overrideWithValue(background),
        widgetHostProvider.overrideWithValue(widgets),
        widgetRefresherProvider.overrideWithValue(FakeWidgetRefresher()),
      ],
    );
    addTearDown(container.dispose);
    handler = NotificationActionHandler(
      container,
      drainTimeout: const Duration(seconds: 1),
    );
  });

  /// Alice signed in, her database seeded and her notifications scheduled.
  Future<(String, AppDatabase)> signedIn() async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now, userId: alice.id),
    );
    await container.read(accountsProvider.future);
    final db = container.read(appDatabaseProvider(entry.id));
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([water, second], syncRunId: 'run');
    write.serverTasks.addEntries([
      MapEntry(water.id, water),
      MapEntry(second.id, second),
    ]);
    container.read(notificationSchedulerProvider(entry.id));
    // The app's start run waits a turn for the widget taps' import.
    await pumpEventQueue();
    await container.read(notificationSchedulerProvider(entry.id))!.reconcile();
    gateway.calls.clear();
    return (entry.id, db);
  }

  NotificationResponse action(
    String actionId, {
    required String accountId,
    required int taskId,
    required String key,
    String? payload,
  }) => NotificationResponse(
    notificationResponseType:
        NotificationResponseType.selectedNotificationAction,
    id: notificationOsIdFor(accountId, key),
    actionId: actionId,
    payload:
        payload ??
        NotificationPayload(
          accountId: accountId,
          taskId: taskId,
          key: key,
        ).toJson(),
  );

  group('Done', () {
    test("marks the task done through the outbox, cancels the task's other "
        'notifications before the send, sends it and reconciles', () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      final dueId = notificationOsIdFor(accountId, '1:due');
      final secondId = notificationOsIdFor(accountId, '2:due');
      expect(
        gateway.pending.keys,
        unorderedEquals([reminderId, dueId, secondId]),
      );
      List<int>? cancelledBeforeSend;
      write.beforeRequest = (_) async =>
          cancelledBeforeSend ??= [...gateway.cancelled];

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );

      expect(write.requests, ['update 1']);
      expect(write.updates, [(1, const TaskChanges(done: true))]);
      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(await db.outboxDao.count(), 0);
      expect(engine.refreshAfterWriteCalls, 1);
      expect(gateway.cancelled, unorderedEquals([reminderId, dueId]));
      // iOS may suspend the isolate while the send is under way.
      expect(cancelledBeforeSend, unorderedEquals([reminderId, dueId]));
      expect(gateway.pending.keys, [secondId]);
      expect((await db.scheduledNotificationsDao.all()).map((r) => r.key), [
        '2:due',
      ]);
    });

    test('leaves the op queued when the server cannot be reached, with the '
        'notifications gone all the same', () async {
      final (accountId, db) = await signedIn();
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
        ),
      );

      expect(write.requests, ['update 1']);
      expect(await db.outboxDao.count(), 1);
      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(gateway.pending.keys, [notificationOsIdFor(accountId, '2:due')]);
    });

    test('an expired access token queues a background drain, so the done '
        'goes out within minutes', () async {
      final (accountId, db) = await signedIn();
      write.beforeRequest = (_) => throw const TokenRejected(
        message:
            'the access token has expired and this isolate does not '
            'refresh',
      );

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
        ),
      );

      expect(await db.outboxDao.count(), 1);
      expect(background.calls, ['drain']);
    });

    test('an unreachable server queues no background drain', () async {
      final (accountId, _) = await signedIn();
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
        ),
      );

      expect(background.calls, isEmpty);
    });

    test('follows a temporary id to the server id', () async {
      final (accountId, db) = await signedIn();
      final localId = await db.outboxDao.queueCreate(
        NewTask(
          projectId: 7,
          title: 'New',
          reminders: [TaskReminder(reminder: reminderAt)],
        ),
        now: now,
      );
      expect(localId, -1);
      await container
          .read(notificationSchedulerProvider(accountId))!
          .reconcile();
      final localReminderId = notificationOsIdFor(accountId, '-1:reminder:0');
      expect(gateway.pending.keys, contains(localReminderId));

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: -1,
          key: '-1:reminder:0',
        ),
      );

      expect(write.requests, ['create New', 'update 100']);
      expect(await db.tasksDao.resolveId(-1), 100);
      expect((await db.tasksDao.find(100))!.done, isTrue);
      expect(gateway.cancelled, [localReminderId]);
      expect(await db.scheduledNotificationsDao.forTasks({-1, 100}), isEmpty);
    });

    test(
      "takes the task's notifications out of the tray before the send",
      () async {
        final (accountId, _) = await signedIn();
        final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
        final dueId = notificationOsIdFor(accountId, '1:due');
        final secondId = notificationOsIdFor(accountId, '2:due');
        // Both of the task's fired, and a run dropped their rows since.
        now = dueAt.add(const Duration(minutes: 1));
        gateway
          ..fire(reminderId)
          ..fire(dueId)
          ..tray[secondId] = 'an activity of another task';
        final db = container.read(appDatabaseProvider(accountId));
        await container
            .read(notificationSchedulerProvider(accountId))!
            .reconcile();
        expect(await db.scheduledNotificationsDao.forTasks({1}), isEmpty);
        Set<int>? trayBeforeSend;
        write.beforeRequest = (_) async =>
            trayBeforeSend ??= {...gateway.tray.keys};

        await handler.handle(
          action(
            NotificationActionIds.markDone,
            accountId: accountId,
            taskId: 1,
            key: '1:reminder:0',
          ),
        );

        expect(trayBeforeSend, {secondId});
        expect(gateway.tray.keys, [secondId]);
      },
    );

    test('a Done on a notification shown before its project turned read-only '
        'is ignored: nothing is queued, the task stays open, and its entries '
        'are scheduled again without Done', () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      final dueId = notificationOsIdFor(accountId, '1:due');
      final secondId = notificationOsIdFor(accountId, '2:due');
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      await db.projectsDao.upsertAll([
        sampleProject(
          id: 7,
          title: 'Work',
        ).copyWith(maxPermission: Permission.read),
      ]);
      expect(gateway.pending[dueId]!.snoozeOnly, isFalse);

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
          payload: gateway.tray[reminderId],
        ),
      );

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect((await db.tasksDao.find(1))!.done, isFalse);
      expect(gateway.pending.keys, unorderedEquals([dueId, secondId]));
      expect(gateway.pending[dueId]!.snoozeOnly, isTrue);
      expect(gateway.pending[secondId]!.snoozeOnly, isTrue);
    });

    test('a Done of a task in a project archived through its parent is '
        'ignored likewise', () async {
      final (accountId, db) = await signedIn();
      await db.projectsDao.upsertAll([
        sampleProject(id: 9, title: 'Home', archived: true),
        sampleProject(id: 7, title: 'Work', parent: 9),
      ]);

      // Without the instant, as scheduled before step 40e: the backstop does
      // not need it.
      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
        ),
      );

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 0);
      expect((await db.tasksDao.find(1))!.done, isFalse);
      expect(
        {
          for (final MapEntry(:key, :value) in gateway.pending.entries)
            key: value.snoozeOnly,
        },
        {
          notificationOsIdFor(accountId, '1:reminder:0'): true,
          notificationOsIdFor(accountId, '1:due'): true,
          notificationOsIdFor(accountId, '2:due'): true,
        },
      );
    });

    group('for an occurrence the task has passed', () {
      final daily = water.copyWith(repeatAfter: const Duration(days: 1));
      final nextDue = dueAt.add(const Duration(days: 1));

      Future<(String, AppDatabase)> dailySignedIn() async {
        final (accountId, db) = await signedIn();
        await db.tasksDao.upsertAll([daily], syncRunId: 'run');
        write.serverTasks[daily.id] = daily;
        return (accountId, db);
      }

      NotificationResponse doneOf(String accountId, String key, DateTime? at) =>
          action(
            NotificationActionIds.markDone,
            accountId: accountId,
            taskId: 1,
            key: key,
            payload: NotificationPayload(
              accountId: accountId,
              taskId: 1,
              key: key,
              occurrence: at,
            ).toJson(),
          );

      test('a repeating task done on the web since, its next due date '
          'synced, ignores it, so it does not move once more', () async {
        final (accountId, db) = await dailySignedIn();
        await db.tasksDao.upsertAll([
          daily.copyWith(
            dueDate: nextDue,
            reminders: [
              TaskReminder(reminder: reminderAt.add(const Duration(days: 1))),
            ],
          ),
        ], syncRunId: 'run');

        await handler.handle(doneOf(accountId, '1:due', dueAt));
        await handler.handle(doneOf(accountId, '1:reminder:0', reminderAt));

        expect(write.requests, isEmpty);
        expect(await db.outboxDao.count(), 0);
        final task = (await db.tasksDao.find(1))!;
        expect(task.done, isFalse);
        expect(task.dueDate, nextDue);
      });

      test('a repeating task still at that occurrence takes it', () async {
        final (accountId, db) = await dailySignedIn();

        await handler.handle(doneOf(accountId, '1:due', dueAt));

        // With the occurrence shown, against a Done made on the web.
        expect(write.updates, [
          (1, TaskChanges(done: true, doneBase: DoneBase(dueDate: dueAt))),
        ]);
      });

      test('a task done meanwhile, in the app or on the web, ignores it, '
          'repeating or not', () async {
        final (accountId, db) = await signedIn();
        await db.tasksDao.upsertAll([
          water.copyWith(done: true),
        ], syncRunId: 'run');

        await handler.handle(doneOf(accountId, '1:due', dueAt));

        expect(write.requests, isEmpty);
        expect(await db.outboxDao.count(), 0);
      });

      test(
        'a task that does not repeat takes it whatever its time is now',
        () async {
          final (accountId, db) = await signedIn();
          await db.tasksDao.upsertAll([
            water.copyWith(dueDate: nextDue),
          ], syncRunId: 'run');

          await handler.handle(doneOf(accountId, '1:due', dueAt));

          expect(write.updates, [(1, const TaskChanges(done: true))]);
        },
      );

      test('a payload scheduled before step 40e, without the instant, takes '
          'it as before', () async {
        final (accountId, db) = await dailySignedIn();
        await db.tasksDao.upsertAll([
          daily.copyWith(dueDate: nextDue),
        ], syncRunId: 'run');

        await handler.handle(doneOf(accountId, '1:due', null));

        expect(write.updates, [
          (1, TaskChanges(done: true, doneBase: DoneBase(dueDate: nextDue))),
        ]);
      });
    });
  });

  group('Snooze', () {
    test('Tomorrow moves a fired reminder to the next day at the default due '
        'time, 9:00 without one', () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);

      await handler.handle(
        action(
          NotificationActionIds.snoozeTomorrow,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );
      expect(
        gateway.pending[reminderId]!.fireAt,
        tomorrowAt(now, null).toUtc(),
      );

      await db.syncStateDao.write({
        SyncStateKeys.userSettings: encodeUserSettings(
          const UserSettings(defaultDueTime: ClockTime(7, 30)),
        ),
      });
      gateway.fire(reminderId);
      await handler.handle(
        action(
          NotificationActionIds.snoozeTomorrow,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );
      expect(
        gateway.pending[reminderId]!.fireAt,
        tomorrowAt(now, const ClockTime(7, 30)).toUtc(),
      );
    });

    test('tomorrowAt is the next calendar day at the time', () {
      expect(
        tomorrowAt(DateTime(2026, 12, 31, 0, 5), const ClockTime(7, 30)),
        DateTime(2027, 1, 1, 7, 30),
      );
    });

    test(
      'tomorrowAt is the next calendar day also across a change of daylight '
      'saving time',
      skip: needsBerlin,
      () {
        expect(
          tomorrowAt(DateTime(2026, 3, 28, 22), null),
          DateTime(2026, 3, 29, 9),
        );
        expect(
          tomorrowAt(DateTime(2026, 10, 25, 0, 30), const ClockTime(7, 30)),
          DateTime(2026, 10, 26, 7, 30),
        );
      },
    );

    test('moves a fired reminder to now + 10 min, under its id, before the '
        "reconcile, and a second snooze keeps the task's own time", () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);

      await handler.handle(
        action(
          NotificationActionIds.snooze10Minutes,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );

      final until = now.add(const Duration(minutes: 10));
      expect(gateway.pending[reminderId]!.fireAt, until);
      // The OS is told before the reconcile's own calls.
      expect(
        gateway.calls.indexOf('schedule $reminderId'),
        lessThan(gateway.calls.lastIndexOf('pendingIds')),
      );
      var row = (await db.scheduledNotificationsDao.find('1:reminder:0'))!;
      expect(row.fireAt, until);
      expect(row.snoozedUntil, until);
      expect(row.snoozeOriginalFireAt, reminderAt);
      expect(write.requests, isEmpty);

      now = until.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      await handler.handle(
        action(
          NotificationActionIds.snooze1Hour,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );

      final later = now.add(const Duration(hours: 1));
      expect(gateway.pending[reminderId]!.fireAt, later);
      row = (await db.scheduledNotificationsDao.find('1:reminder:0'))!;
      expect(row.snoozedUntil, later);
      expect(row.snoozeOriginalFireAt, reminderAt);
    });

    test('a snooze after a reconcile dropped the fired row reschedules at '
        'now + 10 min', () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      final scheduler = container.read(
        notificationSchedulerProvider(accountId),
      )!;
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      now = now.add(const Duration(minutes: 5));
      await scheduler.reconcile();
      expect(await db.scheduledNotificationsDao.find('1:reminder:0'), isNull);
      now = now.add(const Duration(minutes: 2));

      await handler.handle(
        action(
          NotificationActionIds.snooze10Minutes,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );

      final until = now.add(const Duration(minutes: 10));
      expect(gateway.pending[reminderId]!.fireAt, until);
      final row = (await db.scheduledNotificationsDao.find('1:reminder:0'))!;
      expect(row.fireAt, until);
      expect(row.snoozeOriginalFireAt, reminderAt);
      expect(write.requests, isEmpty);
    });

    test('a second snooze after the snoozed notification fired and a '
        "reconcile ran keeps the task's own time", () async {
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      final scheduler = container.read(
        notificationSchedulerProvider(accountId),
      )!;
      now = reminderAt.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      await handler.handle(
        action(
          NotificationActionIds.snooze10Minutes,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );
      final until = now.add(const Duration(minutes: 10));
      now = until.add(const Duration(minutes: 1));
      gateway.fire(reminderId);
      await scheduler.reconcile();
      expect(await db.scheduledNotificationsDao.find('1:reminder:0'), isNull);

      await handler.handle(
        action(
          NotificationActionIds.snooze1Hour,
          accountId: accountId,
          taskId: 1,
          key: '1:reminder:0',
        ),
      );

      final later = now.add(const Duration(hours: 1));
      expect(gateway.pending[reminderId]!.fireAt, later);
      final row = (await db.scheduledNotificationsDao.find('1:reminder:0'))!;
      expect(row.snoozedUntil, later);
      expect(row.snoozeOriginalFireAt, reminderAt);
    });

    test('a snooze of an occurrence the task has moved on from only '
        "reconciles, so the next one keeps its time; the next one's snooze "
        'moves it', () async {
      final (accountId, db) = await signedIn();
      final dueId = notificationOsIdFor(accountId, '1:due');
      final nextDue = dueAt.add(const Duration(days: 1));
      NotificationResponse snoozeOf(DateTime shown) => action(
        NotificationActionIds.snooze1Hour,
        accountId: accountId,
        taskId: 1,
        key: '1:due',
        payload: NotificationPayload(
          accountId: accountId,
          taskId: 1,
          key: '1:due',
          occurrence: shown,
        ).toJson(),
      );
      now = dueAt.add(const Duration(minutes: 1));
      gateway.fire(dueId);
      // Done on the web, and the next occurrence synced.
      await db.tasksDao.upsertAll([
        water.copyWith(
          repeatAfter: const Duration(days: 1),
          dueDate: nextDue,
          reminders: [
            TaskReminder(reminder: reminderAt.add(const Duration(days: 1))),
          ],
        ),
      ], syncRunId: 'run');
      await container
          .read(notificationSchedulerProvider(accountId))!
          .reconcile();
      expect(gateway.pending[dueId]!.fireAt, nextDue);
      expect(gateway.tray, isEmpty);

      await handler.handle(snoozeOf(dueAt));

      expect(gateway.pending[dueId]!.fireAt, nextDue);
      var row = (await db.scheduledNotificationsDao.find('1:due'))!;
      expect(row.snoozedUntil, isNull);

      now = nextDue.add(const Duration(minutes: 1));
      gateway.fire(dueId);
      await handler.handle(snoozeOf(nextDue));

      final until = now.add(const Duration(hours: 1));
      expect(gateway.pending[dueId]!.fireAt, until);
      row = (await db.scheduledNotificationsDao.find('1:due'))!;
      expect(row.snoozedUntil, until);
      expect(row.snoozeOriginalFireAt, nextDue);
    });

    test('a snooze of a task that does not exist does nothing', () async {
      final (accountId, _) = await signedIn();

      await handler.handle(
        action(
          NotificationActionIds.snooze10Minutes,
          accountId: accountId,
          taskId: 9,
          key: '9:due',
        ),
      );

      expect(gateway.scheduled.length, 3);
    });
  });

  WidgetDoneTap tapOfFirst(String accountId) =>
      WidgetDoneTap(id: 'tap', accountId: accountId, taskId: 1, createdAt: now);

  void onIOS() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  group("the widgets' Done taps", () {
    NotificationResponse snoozeOfSecond(String accountId) => action(
      NotificationActionIds.snooze10Minutes,
      accountId: accountId,
      taskId: 2,
      key: '2:due',
    );

    test('go in first on iOS, so that the action does not schedule again '
        'the reminders the widget took away', () async {
      onIOS();
      final (accountId, db) = await signedIn();
      final reminderId = notificationOsIdFor(accountId, '1:reminder:0');
      final dueId = notificationOsIdFor(accountId, '1:due');
      widgets.actions.add(tapOfFirst(accountId));
      gateway.pending
        ..remove(reminderId)
        ..remove(dueId);

      await handler.handle(snoozeOfSecond(accountId));

      expect(gateway.calls, isNot(contains('schedule $reminderId')));
      expect(gateway.calls, isNot(contains('schedule $dueId')));
      expect(widgets.actions, isEmpty);
      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(await db.outboxDao.count(), 1);
      expect(gateway.pending.keys, [notificationOsIdFor(accountId, '2:due')]);
      expect((await db.scheduledNotificationsDao.all()).map((r) => r.key), [
        '2:due',
      ]);
    });

    test('stay for the widget worker on Android, which imports them within '
        'seconds', () async {
      final (accountId, _) = await signedIn();
      widgets.actions.add(tapOfFirst(accountId));

      await handler.handle(snoozeOfSecond(accountId));

      expect(widgets.calls, isNot(contains('takeActions')));
      expect(widgets.actions, hasLength(1));
    });
  });

  NotificationResponse dueDoneOf(String accountId, Task task) => action(
    NotificationActionIds.markDone,
    accountId: accountId,
    taskId: task.id,
    key: '${task.id}:due',
    payload: NotificationPayload(
      accountId: accountId,
      taskId: task.id,
      key: '${task.id}:due',
      occurrence: task.dueDate,
    ).toJson(),
  );

  test('widget Done then notification Done of the same task sends at '
      'once on iOS', () async {
    onIOS();
    final (accountId, db) = await signedIn();
    widgets.actions.add(tapOfFirst(accountId));

    await handler.handle(dueDoneOf(accountId, water));

    expect(widgets.actions, isEmpty);
    expect(write.updates, [(1, const TaskChanges(done: true))]);
    expect(await db.outboxDao.count(), 0);
  });

  test('widget Done then notification Done of the same task sends at once '
      'on Android too, where the tap waits for the widget worker', () async {
    final (accountId, db) = await signedIn();
    widgets.actions.add(tapOfFirst(accountId));

    await handler.handle(dueDoneOf(accountId, water));

    expect(widgets.actions, hasLength(1));
    expect(write.updates, [(1, const TaskChanges(done: true))]);
    expect(await db.outboxDao.count(), 0);
  });

  test('widget Done then notification Done of another task tells iOS '
      'before anything waits for the network, then sends both', () async {
    onIOS();
    final (accountId, db) = await signedIn();
    widgets.actions.add(tapOfFirst(accountId));
    List<int>? cancelledBeforeSend;
    write.beforeRequest = (_) async =>
        cancelledBeforeSend ??= [...gateway.cancelled];

    await handler.handle(dueDoneOf(accountId, second));

    expect(
      cancelledBeforeSend,
      contains(notificationOsIdFor(accountId, '2:due')),
    );
    expect(write.requests, ['update 1', 'update 2']);
    expect(await db.outboxDao.count(), 0);
  });

  group('ignored', () {
    test('an unreadable payload, an unknown account, a tap and an unknown '
        'action', () async {
      final (accountId, _) = await signedIn();

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
          payload: 'garbage',
        ),
      );
      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: 'nobody',
          taskId: 1,
          key: '1:due',
        ),
      );
      await handler.handle(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: NotificationPayload(
            accountId: accountId,
            taskId: 1,
            key: '1:due',
          ).toJson(),
        ),
      );
      await handler.handle(
        action('open', accountId: accountId, taskId: 1, key: '1:due'),
      );

      expect(write.requests, isEmpty);
      expect(gateway.calls, isEmpty);
      expect(container.exists(outboxSenderProvider(accountId)), isFalse);
    });

    test('a failing gateway does not fail the action', () async {
      final (accountId, db) = await signedIn();
      gateway.beforeCall = (call) async {
        if (call.startsWith('cancel')) throw StateError('no plugin');
      };

      await handler.handle(
        action(
          NotificationActionIds.markDone,
          accountId: accountId,
          taskId: 1,
          key: '1:due',
        ),
      );

      expect(write.requests, ['update 1']);
      expect((await db.tasksDao.find(1))!.done, isTrue);
    });
  });
}
