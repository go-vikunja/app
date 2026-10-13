import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_notifier.dart';
import 'package:vikunja_mobile/core/activity/activity_sync.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/local/local_activity_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/test_database.dart';

void main() {
  final noon = DateTime.utc(2026, 10, 13, 12);

  group('LocalActivityRepository', () {
    late AppDatabase db;
    late FakeSyncClient read;
    late FakeWriteClient write;
    late FakeNotificationGateway gateway;
    late LocalActivityRepository repository;

    setUp(() async {
      db = testDatabase();
      read = FakeSyncClient();
      write = FakeWriteClient(clock: () => noon);
      gateway = FakeNotificationGateway();
      final tray = ActivityTray(gateway);
      repository = LocalActivityRepository(
        db,
        ActivitySync(
          db: db,
          read: read.notifications,
          write: write.notifications,
          now: () => noon,
          withdraw: (ids) => tray.withdraw('acc', ids),
        ),
        accountId: 'acc',
        tray: tray,
        now: () => noon,
      );
      addTearDown(repository.dispose);
      await db.syncStateDao.write({
        SyncStateKeys.activitySyncedAt: noon.toIso8601String(),
      });
    });

    test('refresh stores what is new and counts it as handled: the inbox '
        'shows it, so it never becomes an OS notification', () async {
      read.serverNotifications = [
        sampleNotification(id: 2),
        sampleNotification(id: 1, readAt: noon),
      ];

      await repository.refresh();

      expect((await repository.watchAll().first).map((n) => n.id), [2, 1]);
      expect(await repository.watchUnreadCount().first, 1);
      expect(await db.serverNotificationsDao.unhandledUnread(), isEmpty);
    });

    test(
      'refresh throws the failure of the pull and keeps the stored ones',
      () async {
        read.serverNotifications = [sampleNotification(id: 1)];
        await repository.refresh();
        read.beforeRequest = (_) =>
            throw const NetworkFailure(NetworkProblem.unreachable);

        await expectLater(repository.refresh(), throwsA(isA<NetworkFailure>()));

        expect(await repository.watchAll().first, hasLength(1));
      },
    );

    test('markRead shows at once and is sent right after', () async {
      read.serverNotifications = [
        sampleNotification(id: 1),
        sampleNotification(id: 2),
      ];
      await repository.refresh();

      await repository.markRead(1);

      expect((await db.serverNotificationsDao.find(1))!.readAt, noon);
      expect(await repository.watchUnreadCount().first, 1);
      await pumpEventQueue();
      expect(write.notifications.marked, [(1, true)]);
      expect(await db.serverNotificationsDao.pendingReads(), isEmpty);
    });

    test('markAllRead goes out as one request', () async {
      read.serverNotifications = [
        sampleNotification(id: 1),
        sampleNotification(id: 2),
      ];
      await repository.refresh();

      await repository.markAllRead();

      expect(await repository.watchUnreadCount().first, 0);
      await pumpEventQueue();
      expect(write.notifications.markedAll, 1);
    });

    test('a read here takes the notification off the tray', () async {
      read.serverNotifications = [
        sampleNotification(id: 1),
        sampleNotification(id: 2),
        sampleNotification(id: 3, readAt: noon),
      ];
      await repository.refresh();

      await repository.markRead(1);
      expect(gateway.cancelled, [notificationOsIdFor('acc', 'activity:1')]);

      gateway.cancelled.clear();
      await repository.markAllRead();
      expect(gateway.cancelled, [notificationOsIdFor('acc', 'activity:2')]);
    });

    test('a read on the server takes the notification off the tray at the '
        'next refresh', () async {
      read.serverNotifications = [
        sampleNotification(id: 1),
        sampleNotification(id: 2),
      ];
      await repository.refresh();

      read.serverNotifications = [
        sampleNotification(id: 1, readAt: noon),
        sampleNotification(id: 2),
      ];
      await repository.refresh();

      expect(gateway.cancelled, [notificationOsIdFor('acc', 'activity:1')]);
    });

    test(
      "the server's reminders stay out of the badge, not the list",
      () async {
        read.serverNotifications = [
          sampleNotification(id: 1, name: 'task.reminder'),
          sampleNotification(id: 2),
        ];
        await repository.refresh();

        expect(await repository.watchUnreadCount().first, 1);
        expect(await repository.watchAll().first, hasLength(2));
        expect(await db.serverNotificationsDao.unreadCount(), 2);
      },
    );

    test('pull-to-refresh reads back far enough to take what was read on '
        'the web', () async {
      read.serverNotifications = [
        for (var id = 120; id >= 1; id--) sampleNotification(id: id),
      ];
      await repository.refresh(wholeWindow: true);
      expect(await repository.watchUnreadCount().first, 120);

      read
        ..serverNotifications = [
          for (var id = 120; id >= 1; id--)
            sampleNotification(id: id, readAt: noon),
        ]
        ..requests.clear();
      await repository.refresh(wholeWindow: true);

      expect(await repository.watchUnreadCount().first, 0);
      expect(read.requests, [
        'notifications 1',
        'notifications 2',
        'notifications 3',
      ]);
    });

    test('a mark made offline waits for the next refresh', () async {
      read.serverNotifications = [sampleNotification(id: 1)];
      await repository.refresh();
      read.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await repository.markRead(1);
      await pumpEventQueue();
      expect(write.notifications.marked, isEmpty);
      expect(await db.serverNotificationsDao.pendingReads(), hasLength(1));

      read.beforeRequest = null;
      await repository.refresh();
      expect(write.notifications.marked, [(1, true)]);
    });
  });

  group('providers', () {
    late AuthFakes auth;
    late ProviderContainer container;
    late Map<String, AppDatabase> databases;
    late FakeNotificationGateway gateway;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      auth = AuthFakes();
      databases = {};
      final files = FakeAccountDatabaseFiles();
      container = ProviderContainer(
        overrides: [
          ...auth.overrides,
          accountDatabaseFilesProvider.overrideWithValue(files),
          openDatabasesProvider.overrideWithValue(
            OpenDatabases(
              files,
              open: (accountId, _) =>
                  databases[accountId] = AppDatabase(NativeDatabase.memory()),
            ),
          ),
          readClientProvider.overrideWith((ref, _) => FakeSyncClient()),
          writeClientProvider.overrideWith((ref, _) => FakeWriteClient()),
          syncEngineProvider.overrideWith((ref, _) => FakeSyncEngine()),
          clockProvider.overrideWithValue(() => noon),
          notificationGatewayProvider.overrideWithValue(
            gateway = FakeNotificationGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('the inbox follows the active account; none without one', () async {
      await container.read(accountsProvider.future);
      expect(container.read(activityRepositoryProvider), isNull);

      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon),
      );
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: noon, userId: 8, username: 'bob'),
        activate: false,
      );
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      final forAlice = container.read(activityRepositoryProvider);
      expect(forAlice, isA<LocalActivityRepository>());
      expect(
        forAlice,
        same(container.read(accountActivityRepositoryProvider(alice.id))),
      );

      await container.read(accountRegistryProvider).setActive(bob.id);
      await pumpEventQueue();
      expect(
        container.read(activityRepositoryProvider),
        allOf(isNotNull, isNot(same(forAlice))),
      );
    });

    test('sign-out forgets the background notes of the account and takes '
        'what it has in the tray', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: noon),
      );
      await container.read(accountsProvider.future);
      String delivered(String accountId, String key) => NotificationPayload(
        accountId: accountId,
        taskId: 0,
        key: key,
      ).toJson();
      gateway.tray
        ..[1] = delivered(alice.id, 'activity:3')
        ..[2] = delivered(alice.id, 'session:${alice.id}')
        ..[3] = delivered('someone-else', 'activity:3')
        ..[4] = null;
      final log = BackgroundRunLog(auth.preferences);
      await log.recordAccountRun(alice.id, noon);
      await auth.preferences.setString(
        ActivityNotifier.sessionEndedKey(alice.id),
        'true',
      );

      await container.read(accountDataWiperProvider)(alice.id);

      expect(await log.lastRunAt(alice.id), isNull);
      expect(
        auth.preferences.values[ActivityNotifier.sessionEndedKey(alice.id)],
        isNull,
      );
      expect(gateway.tray.keys, unorderedEquals([3, 4]));
    });
  });
}
