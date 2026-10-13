import 'package:drift/native.dart';
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
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

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
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
        backgroundSchedulerProvider.overrideWithValue(background),
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
      expect(engine.refreshCalls, 1);
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
  });

  group('Snooze', () {
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
        lessThan(gateway.calls.indexOf('pendingIds')),
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
