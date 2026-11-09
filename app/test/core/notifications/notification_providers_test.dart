import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/sign_out_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

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

  List<Override> overrides() => [
    ...auth.overrides,
    accountDatabaseFilesProvider.overrideWithValue(files),
    openDatabasesProvider.overrideWithValue(
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

  test('the window is 60 on iOS and 100 elsewhere', () {
    expect(notificationWindow(TargetPlatform.iOS), 60);
    expect(notificationWindow(TargetPlatform.android), 100);
  });

  test('every signed-in account gets a scheduler while the shell listens; '
      'signing one out cancels its notifications, forgets its preferences '
      'and drops it', () async {
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

    await container.read(signOutProvider).call(alice);
    await pumpEventQueue();

    expect(gateway.cancelled, [aliceDue]);
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

  group('following subscriptions (D80)', () {
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

    test('accounts on 2.7.0 and link-share guests keep D17', () async {
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
        gateway.calls.where((c) => c.startsWith('cancel')),
        unorderedEquals(['cancel $aliceDue', 'cancel $bobDue']),
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
      expect(due.body, 'Open Rurana to see it');
      expect(due.payload, payload);
    });

    test("a content that shows less withdraws every account's reminders "
        'and activity from the tray, but not the sign-in notification; one '
        'that shows more withdraws nothing', () async {
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
        201: payload(bob, ActivityTray.moreKey(bob)),
        301: null,
      });

      await change(
        (settings) => settings.copyWith(
          notificationContent: NotificationContent.noTitles,
        ),
      );
      await pumpEventQueue();
      expect(gateway.tray.keys, unorderedEquals([103, 301]));

      gateway.tray[104] = payload(alice, '1:due');
      await change(
        (settings) =>
            settings.copyWith(notificationContent: NotificationContent.all),
      );
      await pumpEventQueue();
      expect(gateway.tray.keys, unorderedEquals([103, 104, 301]));
    });

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
