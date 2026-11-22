import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 12, 9);
  final dueAt = now.add(const Duration(hours: 2));
  late AuthFakes auth;
  late FakeAccountDatabaseFiles files;
  late FakeNotificationGateway gateway;
  late ProviderContainer container;

  List<Override> overrides({OpenDatabases? databases}) => [
    ...auth.overrides,
    accountDatabaseFilesProvider.overrideWithValue(files),
    openDatabasesProvider.overrideWithValue(
      databases ??
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
    ),
    clockProvider.overrideWithValue(() => now),
    notificationGatewayProvider.overrideWithValue(gateway),
  ];

  setUp(() {
    // One in-memory database per account is the point here.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
    auth = AuthFakes();
    files = FakeAccountDatabaseFiles();
    gateway = FakeNotificationGateway();
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
  });

  /// Alice (active) and Bob (inactive), each with one due task of their
  /// own in their database.
  Future<(String alice, String bob)> twoAccounts() async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    await container.read(accountsProvider.future);
    for (final (entry, userId) in [(alice, 7), (bob, 8)]) {
      final db = container.read(appDatabaseProvider(entry.id));
      await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Mine', projectId: 7, due: dueAt).copyWith(
          createdBy: User(id: userId, username: 'u$userId'),
        ),
      ], syncRunId: 'run');
    }
    return (alice.id, bob.id);
  }

  test('the window is 60 on iOS, shared evenly by the accounts with a '
      'session reminder each, and 100 per account elsewhere', () {
    expect(notificationWindow(platform: TargetPlatform.iOS), 59);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 2), 29);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 3), 19);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 7), 7);
    for (var accounts = 1; accounts <= 30; accounts++) {
      final window = notificationWindow(
        platform: TargetPlatform.iOS,
        accounts: accounts,
      );
      expect(
        accounts * (window + 1),
        lessThanOrEqualTo(60),
        reason: '$accounts',
      );
    }
    expect(notificationWindow(platform: TargetPlatform.android), 100);
    expect(
      notificationWindow(platform: TargetPlatform.android, accounts: 3),
      100,
    );
  });

  group('on iOS the accounts share the 64 the system keeps', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    /// Forty due tasks of the user's own in the account's database.
    Future<void> fortyOwnTasks(String accountId, int userId) async {
      final db = container.read(appDatabaseProvider(accountId));
      await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
      await db.tasksDao.upsertAll([
        for (var id = 1; id <= 40; id++)
          sampleTask(
            id: id,
            title: 'Task $id',
            projectId: 7,
            due: dueAt.add(Duration(minutes: id)),
          ).copyWith(
            createdBy: User(id: userId, username: 'u$userId'),
          ),
      ], syncRunId: 'run');
    }

    Map<String, int> pendingPerAccount() {
      final counts = <String, int>{};
      for (final notification in gateway.pending.values) {
        final account = NotificationPayload.fromJson(notification.payload)
            .accountId;
        counts[account] = (counts[account] ?? 0) + 1;
      }
      return counts;
    }

    Future<RegisteredAccount> carolSignsIn() => auth.seedAccount(
      fullServer270(root: 'https://carol.example.com'),
      tokens: issueTokens(issuedAt: now, userId: 9, username: 'carol'),
      activate: false,
    );

    test("two accounts hold 29 each, so neither drops the other's "
        'soonest', () async {
      final (alice, bob) = await twoAccounts();
      await fortyOwnTasks(alice, 7);
      await fortyOwnTasks(bob, 8);

      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();

      expect(pendingPerAccount(), {alice: 29, bob: 29});
      expect(gateway.pending.keys, contains(notificationOsIdFor(bob, '1:due')));
      expect(
        gateway.pending.keys,
        contains(notificationOsIdFor(alice, '1:due')),
      );
    });

    test('a third account takes its share from the others: 19 each and a '
        'session reminder each, 60 in all', () async {
      final (alice, bob) = await twoAccounts();
      await fortyOwnTasks(alice, 7);
      await fortyOwnTasks(bob, 8);
      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();
      expect(pendingPerAccount(), {alice: 29, bob: 29});

      final carol = await carolSignsIn();
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      await fortyOwnTasks(carol.id, 9);
      final carols = container.read(notificationSchedulerProvider(carol.id));
      await carols!.reconcile();
      for (final account in [alice, bob, carol.id]) {
        await container.read(appDatabaseProvider(account)).syncStateDao.write({
          SyncStateKeys.lastSyncedAt: now.toIso8601String(),
        });
        await container.read(sessionRemindersProvider).update(account);
      }
      await pumpEventQueue();

      expect(pendingPerAccount(), {alice: 20, bob: 20, carol.id: 20});
      expect(
        gateway.pending.keys,
        containsAll([
          for (final account in [alice, bob, carol.id])
            sessionReminderOsId(account),
        ]),
      );
      expect(gateway.pending, hasLength(60));
    });
  });

  test('every signed-in account gets a scheduler while the shell listens; '
      'signing one out cancels its notifications, its session reminder '
      'included, forgets its preferences and drops it', () async {
    final (alice, bob) = await twoAccounts();
    final aliceDue = notificationOsIdFor(alice, '1:due');
    final bobDue = notificationOsIdFor(bob, '1:due');
    final preferences = container.read(notificationPreferencesStoreProvider);
    await preferences.write(
      alice,
      const NotificationPreferences(reminders: false),
    );
    await preferences.write(
      bob,
      const NotificationPreferences(reminders: false),
    );

    final schedulers = container.listen(
      accountNotificationSchedulersProvider,
      (_, _) {},
    );
    await pumpEventQueue();

    expect(schedulers.read(), {alice, bob});
    expect(gateway.pending.keys, unorderedEquals([aliceDue, bobDue]));
    final registry = container.read(notificationSchedulersProvider);
    expect(registry.find(alice), isNotNull);
    expect(registry.find(bob), isNotNull);

    await container.read(appDatabaseProvider(alice)).syncStateDao.write({
      SyncStateKeys.lastSyncedAt: now.toIso8601String(),
    });
    await container.read(sessionRemindersProvider).update(alice);
    expect(gateway.pending.keys, contains(sessionReminderOsId(alice)));
    gateway.cancelled.clear();

    await container.read(signOutProvider).call(alice);
    await pumpEventQueue();

    expect(gateway.cancelled, [aliceDue, sessionReminderOsId(alice)]);
    expect(gateway.pending.keys, [bobDue]);
    expect(schedulers.read(), {bob});
    expect(registry.find(alice), isNull);
    expect(files.deleted, [alice]);
    expect(
      auth.preferences.values.containsKey(
        StoredNotificationPreferences.keyFor(alice),
      ),
      isFalse,
    );
    expect(
      auth.preferences.values.containsKey(
        StoredNotificationPreferences.keyFor(bob),
      ),
      isTrue,
    );
  });

  test('coming back to the front reconciles every scheduler', () async {
    await twoAccounts();
    container.listen(accountNotificationSchedulersProvider, (_, _) {});
    await pumpEventQueue();
    gateway.calls.clear();

    TestWidgetsFlutterBinding.instance
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(gateway.calls.where((c) => c == 'capabilities').length, 2);
    expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);
  });

  test('a scheduler built from the provider keeps the same os ids across '
      'a rebuild', () async {
    final (alice, _) = await twoAccounts();
    final aliceDue = notificationOsIdFor(alice, '1:due');
    await container.read(notificationSchedulerProvider(alice))!.reconcile();
    expect(gateway.pending.keys, [aliceDue]);
    gateway.calls.clear();

    container.invalidate(notificationSchedulerProvider(alice));
    await container.read(notificationSchedulerProvider(alice))!.reconcile();

    expect(gateway.pending.keys, [aliceDue]);
    expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);
    expect(gateway.cancelled, isEmpty);
  });

  group('the first build in a process', () {
    late Map<String, Database> sqlite;

    setUp(() {
      sqlite = {};
      addTearDown(() {
        for (final database in sqlite.values) {
          database.close();
        }
      });
    });

    Iterable<String> schedulesAndCancels() => gateway.calls.where(
      (c) => c.startsWith('schedule') || c.startsWith('cancel'),
    );

    /// A container whose databases outlive it, as the files outlive a
    /// process.
    ProviderContainer process({bool headless = false}) {
      final databases = OpenDatabases(
        files,
        open: (accountId, _) => AppDatabase(
          NativeDatabase.opened(
            sqlite.putIfAbsent(accountId, sqlite3.openInMemory),
            closeUnderlyingOnClose: false,
          ),
        ),
      );
      final process = ProviderContainer(
        overrides: [
          ...overrides(databases: databases),
          if (headless) runsHeadlessProvider.overrideWithValue(true),
        ],
      );
      addTearDown(process.dispose);
      return process;
    }

    /// An earlier process of the app scheduled alice's due notification
    /// and has ended; the plugin lists it as pending.
    Future<(String alice, int due)> scheduledByAnEarlierProcess() async {
      container = process();
      final (alice, _) = await twoAccounts();
      container.listen(notificationSchedulerProvider(alice), (_, _) {});
      await pumpEventQueue();
      final due = notificationOsIdFor(alice, '1:due');
      expect(gateway.pending.keys, [due]);
      container.dispose();
      gateway.calls.clear();
      return (alice, due);
    }

    test('on Android schedules again what the plugin lists after a force '
        'stop, cancelling nothing; a rebuild and a resume in the same '
        'process do not', () async {
      final (alice, due) = await scheduledByAnEarlierProcess();
      gateway.forceStop();

      final app = process()
        ..listen(notificationSchedulerProvider(alice), (_, _) {});
      await pumpEventQueue();

      expect(schedulesAndCancels(), ['schedule $due']);
      expect(gateway.alarms, [due]);

      gateway.calls.clear();
      final first = app.read(notificationSchedulerProvider(alice));
      app.invalidate(notificationSchedulerProvider(alice));
      await pumpEventQueue();
      expect(
        app.read(notificationSchedulerProvider(alice)),
        isNot(same(first)),
      );
      TestWidgetsFlutterBinding.instance
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(gateway.calls.where((c) => c == 'pendingIds').length, 2);
      expect(schedulesAndCancels(), isEmpty);
    });

    test('in a headless container leaves the re-arming to the app', () async {
      final (alice, _) = await scheduledByAnEarlierProcess();
      gateway.forceStop();

      process(headless: true)
          .listen(notificationSchedulerProvider(alice), (_, _) {});
      await pumpEventQueue();

      expect(gateway.calls, contains('pendingIds'));
      expect(schedulesAndCancels(), isEmpty);
      expect(gateway.alarms, isEmpty);
    });

    test("on iOS is a normal run: the pending list is the system's", () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final (alice, _) = await scheduledByAnEarlierProcess();

      process().listen(notificationSchedulerProvider(alice), (_, _) {});
      await pumpEventQueue();

      expect(gateway.calls, contains('pendingIds'));
      expect(schedulesAndCancels(), isEmpty);
    });
  });

  group('following subscriptions '
      '(decision log: Notifications and widgets)', () {
    const bob = User(id: 8, username: 'bob');

    Subscription via(int projectId) =>
        Subscription(entity: SubscriptionEntity.project, entityId: projectId);

    /// Both projects are followed; the account's own task 1 is opted out,
    /// bob's task 2 is not the account's but its project is followed.
    Future<void> seedFollowing(RegisteredAccount entry) async {
      final db = container.read(appDatabaseProvider(entry.id));
      await db.projectsDao.upsertAll([
        sampleProject(id: 7, title: 'Work').copyWith(subscription: via(7)),
        sampleProject(id: 8, title: 'Shared').copyWith(subscription: via(8)),
      ]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Mine', projectId: 7, due: dueAt).copyWith(
          createdBy: User(id: entry.account.userId, username: 'me'),
        ),
        sampleTask(
          id: 2,
          title: "Bob's",
          projectId: 8,
          due: dueAt,
        ).copyWith(createdBy: bob),
      ], syncRunId: 'run');
      await db.tasksDao.storeOwnSubscription(
        1,
        null,
        userId: entry.account.userId,
      );
    }

    test('an account on 2.8.0 follows its subscriptions', () async {
      final alice = await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: now),
      );
      await container.read(accountsProvider.future);
      await seedFollowing(alice);

      container.listen(notificationSchedulerProvider(alice.id), (_, _) {});
      await pumpEventQueue();

      expect(gateway.pending.keys, [notificationOsIdFor(alice.id, '2:due')]);
    });

    test('accounts on 2.7.0 and link-share guests keep the rule of older '
        'servers (decision log: Notifications and widgets)', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final guest = await auth.seedGuest(
        fullServer280(root: 'https://other.example.org'),
        token: null,
        activate: false,
      );
      await container.read(accountsProvider.future);
      await seedFollowing(alice);
      await seedFollowing(guest);

      container
        ..listen(notificationSchedulerProvider(alice.id), (_, _) {})
        ..listen(notificationSchedulerProvider(guest.id), (_, _) {});
      await pumpEventQueue();

      expect(
        gateway.pending.keys,
        unorderedEquals([
          notificationOsIdFor(alice.id, '1:due'),
          notificationOsIdFor(guest.id, '1:due'),
        ]),
      );
    });

    test('a refreshed connection on 2.8.0 builds the scheduler again, which '
        'reconciles at once; other registry writes do not', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      await container.read(accountsProvider.future);
      await seedFollowing(alice);
      final scheduler = container.listen(
        notificationSchedulerProvider(alice.id),
        (_, _) {},
      );
      await pumpEventQueue();
      final before = scheduler.read();
      final mine = notificationOsIdFor(alice.id, '1:due');
      expect(gateway.pending.keys, [mine]);
      final registry = container.read(accountRegistryProvider);

      await registry.updateDisplayName(alice.id, 'A.');
      await pumpEventQueue();
      expect(scheduler.read(), same(before));

      await registry.updateConnection(alice.id, (_) => fullServer280());
      await pumpEventQueue();

      expect(scheduler.read(), allOf(isNotNull, isNot(same(before))));
      expect(gateway.cancelled, [mine]);
      expect(gateway.pending.keys, [notificationOsIdFor(alice.id, '2:due')]);
    });
  });

  group('privacy settings', () {
    Future<void> change(PrivacySettings Function(PrivacySettings) edit) =>
        container.read(privacySettingsControllerProvider.notifier).change(edit);

    Future<(int, int)> scheduledForBoth() async {
      final (alice, bob) = await twoAccounts();
      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();
      return (
        notificationOsIdFor(alice, '1:due'),
        notificationOsIdFor(bob, '1:due'),
      );
    }

    test('stored ones are read for the first run', () async {
      await storePrivacySettings(
        auth.preferences,
        const PrivacySettings(
          appLock: true,
          notificationContent: NotificationContent.noTitles,
        ),
      );

      await scheduledForBoth();

      expect(gateway.pending.values.map((n) => n.title), [
        'Task due',
        'Task due',
      ]);
      expect(
        gateway.pending.values.map((n) => n.privacy),
        everyElement(const NotificationPrivacy(doneNeedsUnlock: true)),
      );
    });

    test('hiding notifications on the lock screen reschedules every '
        "account's pending ones, hidden", () async {
      final (aliceDue, bobDue) = await scheduledForBoth();
      gateway.calls.clear();

      await change(
        (settings) => settings.copyWith(
          notificationContent: NotificationContent.hiddenOnLockScreen,
        ),
      );
      await pumpEventQueue();

      expect(
        gateway.calls.where((c) => c.startsWith('schedule')),
        unorderedEquals(['schedule $aliceDue', 'schedule $bobDue']),
      );
      expect(gateway.pending.keys, unorderedEquals([aliceDue, bobDue]));
      for (final notification in gateway.pending.values) {
        expect(notification.title, 'Mine');
        expect(
          notification.privacy,
          const NotificationPrivacy(hiddenOnLockScreen: true),
        );
      }
    });

    test('turning the app lock on reschedules with Done behind the device '
        'unlock', () async {
      await scheduledForBoth();
      gateway.calls.clear();

      await change((settings) => settings.copyWith(appLock: true));
      await pumpEventQueue();

      expect(
        gateway.calls.where((c) => c.startsWith('schedule')),
        hasLength(2),
      );
      expect(gateway.pending.values.map((n) => n.privacy.doneNeedsUnlock), [
        isTrue,
        isTrue,
      ]);
    });

    test('turning the app lock on withdraws the reminders and activity '
        'already shown, whose Done runs without the unlock; turning it off '
        'withdraws nothing', () async {
      final (alice, _) = await twoAccounts();
      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();
      String payload(String key) =>
          NotificationPayload(accountId: alice, taskId: 1, key: key).toJson();
      gateway.tray.addAll({
        101: payload('1:due'),
        102: payload(ActivityTray.activityKey(5)),
        103: payload(ActivityTray.sessionKey(alice)),
      });

      await change((settings) => settings.copyWith(appLock: true));
      await pumpEventQueue();
      expect(gateway.tray.keys, [103]);

      gateway.tray[104] = payload('1:due');
      await change((settings) => settings.copyWith(appLock: false));
      await pumpEventQueue();
      expect(gateway.tray.keys, unorderedEquals([103, 104]));
    });

    test('no titles: generic texts, the payload unchanged', () async {
      final (aliceDue, _) = await scheduledForBoth();
      final payload = gateway.pending[aliceDue]!.payload;

      await change(
        (settings) => settings.copyWith(
          notificationContent: NotificationContent.noTitles,
        ),
      );
      await pumpEventQueue();

      final due = gateway.pending[aliceDue]!;
      expect(due.title, 'Task due');
      expect(due.body, 'Open Vikunja to see it');
      expect(due.payload, payload);
    });

    test(
      "a content that shows less withdraws every account's reminders "
      'and activity from the tray, but not the sign-in notification nor '
      'the session reminder; one that shows more withdraws nothing',
      () async {
        final (alice, bob) = await twoAccounts();
        container.listen(accountNotificationSchedulersProvider, (_, _) {});
        await pumpEventQueue();
        String payload(String accountId, String key) => NotificationPayload(
          accountId: accountId,
          taskId: 1,
          key: key,
        ).toJson();
        gateway.tray.addAll({
          101: payload(alice, '1:due'),
          102: payload(alice, ActivityTray.activityKey(5)),
          103: payload(alice, ActivityTray.sessionKey(alice)),
          105: payload(alice, SessionReminders.key(alice)),
          201: payload(bob, ActivityTray.moreKey(bob)),
          301: null,
        });

        await change(
          (settings) => settings.copyWith(
            notificationContent: NotificationContent.noTitles,
          ),
        );
        await pumpEventQueue();
        expect(gateway.tray.keys, unorderedEquals([103, 105, 301]));

        gateway.tray[104] = payload(alice, '1:due');
        await change(
          (settings) =>
              settings.copyWith(notificationContent: NotificationContent.all),
        );
        await pumpEventQueue();
        expect(gateway.tray.keys, unorderedEquals([103, 104, 105, 301]));
      },
    );

    test('a headless container reads them anew for every run, since the '
        'app may have changed them meanwhile', () async {
      container = ProviderContainer(
        overrides: [
          ...overrides(),
          runsHeadlessProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      final (alice, _) = await twoAccounts();
      final scheduler = container.read(notificationSchedulerProvider(alice))!;
      await scheduler.reconcile();
      final due = notificationOsIdFor(alice, '1:due');
      expect(gateway.pending[due]!.title, 'Mine');

      await storePrivacySettings(
        auth.preferences,
        const PrivacySettings(
          notificationContent: NotificationContent.noTitles,
        ),
      );
      await scheduler.reconcile();
      await pumpEventQueue();

      expect(gateway.pending[due]!.title, 'Task due');
    });

    test('other settings leave the notifications alone', () async {
      await scheduledForBoth();
      gateway.calls.clear();

      await change(
        (settings) => settings.copyWith(
          lockAfter: LockAfter.fiveMinutes,
          blockScreenshots: true,
          widgetTitles: false,
        ),
      );
      await pumpEventQueue();

      expect(gateway.calls, isEmpty);
    });

    test('activity notifications follow the notification content', () async {
      final (alice, _) = await twoAccounts();
      await change(
        (settings) => settings.copyWith(
          notificationContent: NotificationContent.hiddenOnLockScreen,
        ),
      );
      final entry = container.read(accountsProvider).value!.find(alice)!;
      final db = container.read(appDatabaseProvider(alice));
      await db.serverNotificationsDao.upsertAll([
        sampleNotification(
          id: 1,
          extra: {
            'assignee': const {'id': 7},
          },
        ),
      ], handled: false);

      await container
          .read(activityNoticesProvider)
          .show(
            account: entry.account,
            db: db,
            fresh: await db.serverNotificationsDao.unhandledUnread(),
          );

      expect(gateway.activities.single.title, 'Water the plants');
      expect(gateway.activities.single.privacy.hiddenOnLockScreen, isTrue);
    });
  });
}
