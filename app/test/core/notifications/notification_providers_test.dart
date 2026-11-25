import 'dart:async';

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
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 12, 9);
  final dueAt = now.add(const Duration(hours: 2));
  late AuthFakes auth;
  late FakeAccountDatabaseFiles files;
  late FakeNotificationGateway gateway;
  late WidgetHost widgets;
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
    widgetHostProvider.overrideWithValue(widgets),
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
    widgets = FakeWidgetHost();
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

  /// [count] due tasks of the user's own in the account's database, task
  /// `id` due `id` minutes after [dueAt].
  Future<void> ownTasks(
    String accountId,
    int userId, {
    required int count,
  }) async {
    final db = container.read(appDatabaseProvider(accountId));
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      for (var id = 1; id <= count; id++)
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

  /// An inactive account of [name] on a server of its own.
  Future<String> signsIn(String name, int userId) async {
    final entry = await auth.seedAccount(
      fullServer270(root: 'https://$name.example.com'),
      tokens: issueTokens(issuedAt: now, userId: userId, username: name),
      activate: false,
    );
    return entry.id;
  }

  test('the window is 60 on iOS, shared evenly by the accounts with a '
      'session reminder and a snoozed entry each', () {
    expect(notificationWindow(platform: TargetPlatform.iOS), 58);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 2), 28);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 3), 18);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 5), 10);
    expect(notificationWindow(platform: TargetPlatform.iOS, accounts: 7), 6);
    for (var accounts = 1; accounts <= 21; accounts++) {
      final window = notificationWindow(
        platform: TargetPlatform.iOS,
        accounts: accounts,
      );
      expect(
        accounts * (window + 2),
        lessThanOrEqualTo(64),
        reason: '$accounts',
      );
    }
  });

  test('the window is 480 on Android, shared evenly by the accounts with a '
      'session reminder and a snoozed entry each, at most 100 per account, '
      'leaving 20 of the 500 alarms Android allows an app', () {
    expect(notificationWindow(platform: TargetPlatform.android), 100);
    expect(
      notificationWindow(platform: TargetPlatform.android, accounts: 4),
      100,
    );
    expect(
      notificationWindow(platform: TargetPlatform.android, accounts: 5),
      94,
    );
    expect(
      notificationWindow(platform: TargetPlatform.android, accounts: 6),
      78,
    );
    expect(
      notificationWindow(platform: TargetPlatform.android, accounts: 10),
      46,
    );
    for (var accounts = 1; accounts <= 160; accounts++) {
      final window = notificationWindow(
        platform: TargetPlatform.android,
        accounts: accounts,
      );
      expect(
        accounts * (window + 2),
        lessThanOrEqualTo(480),
        reason: '$accounts',
      );
    }
  });

  group('on iOS the accounts share the 64 the system keeps', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    test("two accounts hold 28 each, so neither drops the other's "
        'soonest', () async {
      final (alice, bob) = await twoAccounts();
      await ownTasks(alice, 7, count: 40);
      await ownTasks(bob, 8, count: 40);

      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();

      expect(pendingPerAccount(), {alice: 28, bob: 28});
      expect(gateway.pending.keys, contains(notificationOsIdFor(bob, '1:due')));
      expect(
        gateway.pending.keys,
        contains(notificationOsIdFor(alice, '1:due')),
      );
    });

    test('a third account takes its share from the others: 18 each and a '
        'session reminder each, 57 in all, room left for a snoozed entry '
        'each', () async {
      final (alice, bob) = await twoAccounts();
      await ownTasks(alice, 7, count: 40);
      await ownTasks(bob, 8, count: 40);
      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();
      expect(pendingPerAccount(), {alice: 28, bob: 28});

      final carol = await signsIn('carol', 9);
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      await ownTasks(carol, 9, count: 40);
      final carols = container.read(notificationSchedulerProvider(carol));
      await carols!.reconcile();
      for (final account in [alice, bob, carol]) {
        await container.read(appDatabaseProvider(account)).syncStateDao.write({
          SyncStateKeys.lastSyncedAt: now.toIso8601String(),
        });
        await container.read(sessionRemindersProvider).update(account);
      }
      await pumpEventQueue();

      expect(pendingPerAccount(), {alice: 19, bob: 19, carol: 19});
      expect(
        gateway.pending.keys,
        containsAll([
          for (final account in [alice, bob, carol])
            sessionReminderOsId(account),
        ]),
      );
      expect(gateway.pending, hasLength(57));
    });
  });

  group('on Android the accounts share 480 of the 500 alarms the system '
      'allows', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });

    test('four accounts keep 100 each; a fifth takes its share from the '
        'others: 94 each and a session reminder each, 475 in all, never '
        'more than 480 on the way', () async {
      var peak = 0;
      void measure() {
        if (gateway.alarms.length > peak) peak = gateway.alarms.length;
      }

      gateway.beforeCall = (_) async => measure();
      final (alice, bob) = await twoAccounts();
      final carol = await signsIn('carol', 9);
      final dave = await signsIn('dave', 10);
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      final four = [(alice, 7), (bob, 8), (carol, 9), (dave, 10)];
      for (final (account, userId) in four) {
        await ownTasks(account, userId, count: 100);
      }
      container.listen(accountNotificationSchedulersProvider, (_, _) {});
      await pumpEventQueue();
      expect(pendingPerAccount(), {
        alice: 100,
        bob: 100,
        carol: 100,
        dave: 100,
      });

      final erin = await signsIn('erin', 11);
      container.invalidate(accountsProvider);
      await container.read(accountsProvider.future);
      await pumpEventQueue();
      expect(pendingPerAccount(), {alice: 94, bob: 94, carol: 94, dave: 94});

      await ownTasks(erin, 11, count: 100);
      await container.read(notificationSchedulerProvider(erin))!.reconcile();
      for (final account in [alice, bob, carol, dave, erin]) {
        await container.read(appDatabaseProvider(account)).syncStateDao.write({
          SyncStateKeys.lastSyncedAt: now.toIso8601String(),
        });
        await container.read(sessionRemindersProvider).update(account);
      }
      await pumpEventQueue();

      expect(pendingPerAccount(), {
        for (final account in [alice, bob, carol, dave, erin]) account: 95,
      });
      expect(
        gateway.pending.keys,
        allOf(
          contains(notificationOsIdFor(alice, '94:due')),
          isNot(contains(notificationOsIdFor(alice, '95:due'))),
        ),
      );
      expect(gateway.alarms, hasLength(475));
      measure();
      expect(peak, lessThanOrEqualTo(480));
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

  test('coming back after a hide reconciles every scheduler once', () async {
    await twoAccounts();
    container.listen(accountNotificationSchedulersProvider, (_, _) {});
    await pumpEventQueue();
    gateway.calls.clear();

    await _comeBack(hidden: true);

    expect(gateway.calls.where((c) => c == 'capabilities').length, 2);
    expect(gateway.calls.where((c) => c.startsWith('schedule')), isEmpty);

    gateway.calls.clear();
    await _comeBack(hidden: false);
    expect(gateway.calls, isEmpty);
  });

  test('a resume without a hide (the notification shade, a system dialog, '
      "the app lock's prompt) reconciles nothing", () async {
    await twoAccounts();
    container.listen(accountNotificationSchedulersProvider, (_, _) {});
    await pumpEventQueue();
    gateway.calls.clear();

    await _comeBack(hidden: false);

    expect(gateway.calls, isEmpty);
  });

  group('without a hide, what the OS allows reconciles where it arrives', () {
    Iterable<String> runs() => gateway.calls.where((c) => c == 'pendingIds');

    test('a permission granted in the OS dialog schedules the reminders at '
        'once', () async {
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.notAsked,
        exactAlarms: true,
      );
      final (alice, bob) = await twoAccounts();
      container
        ..listen(accountNotificationSchedulersProvider, (_, _) {})
        ..listen(osNotificationCapabilitiesProvider, (_, _) {});
      await pumpEventQueue();
      expect(gateway.pending, isEmpty);

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: true,
      );
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await container
          .read(osNotificationCapabilitiesProvider.notifier)
          .requestPermission();
      await _comeBack(hidden: false);

      expect(
        gateway.pending.keys,
        unorderedEquals([
          notificationOsIdFor(alice, '1:due'),
          notificationOsIdFor(bob, '1:due'),
        ]),
      );
    });

    test('a permission or exact alarms changed beside the app (the shade, '
        'a split screen) reconcile on the next resume', () async {
      final (alice, bob) = await twoAccounts();
      container
        ..listen(accountNotificationSchedulersProvider, (_, _) {})
        ..listen(osNotificationCapabilitiesProvider, (_, _) {});
      await pumpEventQueue();
      expect(gateway.pending, hasLength(2));
      gateway.calls.clear();

      await _comeBack(hidden: false);
      expect(runs(), isEmpty, reason: 'nothing changed');

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      await _comeBack(hidden: false);
      expect(gateway.pending, isEmpty);

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: false,
      );
      await _comeBack(hidden: false);
      expect(
        gateway.pending.keys,
        unorderedEquals([
          notificationOsIdFor(alice, '1:due'),
          notificationOsIdFor(bob, '1:due'),
        ]),
      );

      gateway.calls.clear();
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: true,
      );
      await _comeBack(hidden: false);
      expect(runs(), hasLength(2));
    });
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
      await _comeBack(hidden: true);

      expect(gateway.calls.where((c) => c == 'pendingIds').length, 2);
      expect(schedulesAndCancels(), isEmpty);
    });

    test('on Android re-arms without waiting for the widget taps, so a '
        'rebuild while they are imported does not lose it', () async {
      final (alice, due) = await scheduledByAnEarlierProcess();
      gateway.forceStop();
      final taps = _HeldTaps();
      widgets = taps;

      final app = process()
        ..listen(notificationSchedulerProvider(alice), (_, _) {})
        ..listen(widgetTapImporterProvider, (_, _) {});
      await pumpEventQueue();
      expect(taps.taken, 1);
      final first = app.read(notificationSchedulerProvider(alice));
      app.invalidate(notificationSchedulerProvider(alice));
      await pumpEventQueue();
      expect(
        app.read(notificationSchedulerProvider(alice)),
        isNot(same(first)),
      );
      taps.release();
      await pumpEventQueue();

      expect(schedulesAndCancels(), ['schedule $due']);
      expect(gateway.alarms, [due]);
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

    test('a headless container reads the content anew for every activity '
        'shown, as the app may have changed it since it started', () async {
      container = ProviderContainer(
        overrides: [
          ...overrides(),
          runsHeadlessProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      final (alice, _) = await twoAccounts();
      final entry = container.read(accountsProvider).value!.find(alice)!;
      final db = container.read(appDatabaseProvider(alice));
      Future<void> showNew(int id) async {
        await db.serverNotificationsDao.upsertAll([
          sampleNotification(
            id: id,
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
      }

      await showNew(1);
      expect(gateway.activities.last.title, 'Water the plants');

      await storePrivacySettings(
        auth.preferences,
        const PrivacySettings(
          notificationContent: NotificationContent.noTitles,
        ),
      );
      await showNew(2);

      expect(gateway.activities.last.title, 'New activity');
    });
  });

  test('in the app on iOS, the start and resume runs wait until the widget '
      'taps are imported, whose reminders they would schedule again '
      '(decision log: Notifications and widgets)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final taps = _HeldTaps();
    widgets = taps;
    container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    await twoAccounts();
    Iterable<String> runs() => gateway.calls.where((c) => c == 'capabilities');

    container
      ..listen(accountNotificationSchedulersProvider, (_, _) {})
      ..listen(widgetTapImporterProvider, (_, _) {});
    await pumpEventQueue();
    expect(taps.taken, 1);
    expect(runs(), isEmpty);

    taps.release();
    await pumpEventQueue();
    expect(runs(), hasLength(2));

    gateway.calls.clear();
    taps.hold();
    await _comeBack(hidden: true);
    expect(taps.taken, 2);
    expect(runs(), isEmpty);

    taps.release();
    await pumpEventQueue();
    expect(runs(), hasLength(2));
  });

  for (final hidden in [true, false]) {
    test('in the app on iOS, a permission granted in the settings '
        '${hidden ? 'app' : 'beside the app'} waits for the widget taps too '
        '(decision log: Notifications and widgets)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final taps = _HeldTaps();
      widgets = taps;
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      final (alice, bob) = await twoAccounts();
      container
        ..listen(accountNotificationSchedulersProvider, (_, _) {})
        ..listen(widgetTapImporterProvider, (_, _) {})
        ..listen(osNotificationCapabilitiesProvider, (_, _) {});
      taps.release();
      await pumpEventQueue();
      expect(gateway.pending, isEmpty);

      gateway
        ..calls.clear()
        ..current = const NotificationCapabilities(
          permission: NotificationPermission.granted,
          exactAlarms: true,
        );
      taps.hold();
      await _comeBack(hidden: hidden);
      expect(taps.taken, 2);
      expect(gateway.calls, ['capabilities'], reason: 'only the read itself');

      taps.release();
      await pumpEventQueue();
      expect(
        gateway.pending.keys,
        unorderedEquals([
          notificationOsIdFor(alice, '1:due'),
          notificationOsIdFor(bob, '1:due'),
        ]),
      );
    });
  }

  test(
    'in the app on Android, a permission granted beside the app '
    'schedules at once, without waiting for an import of widget taps',
    () async {
      final taps = _HeldTaps();
      widgets = taps;
      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.denied,
        exactAlarms: true,
      );
      container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
      final (alice, bob) = await twoAccounts();
      container
        ..listen(accountNotificationSchedulersProvider, (_, _) {})
        ..listen(widgetTapImporterProvider, (_, _) {})
        ..listen(osNotificationCapabilitiesProvider, (_, _) {});
      taps.release();
      await pumpEventQueue();
      expect(gateway.pending, isEmpty);

      gateway.current = const NotificationCapabilities(
        permission: NotificationPermission.granted,
        exactAlarms: true,
      );
      taps.hold();
      await _comeBack(hidden: false);

      expect(
        gateway.pending.keys,
        unorderedEquals([
          notificationOsIdFor(alice, '1:due'),
          notificationOsIdFor(bob, '1:due'),
        ]),
      );
      taps.release();
    },
  );
}

/// Back in front after the shade or a dialog, or with [hidden] from
/// another app.
Future<void> _comeBack({required bool hidden}) async {
  final binding = TestWidgetsFlutterBinding.instance
    ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  if (hidden) {
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await pumpEventQueue();
}

/// Holds each import of the widget taps at its start until released.
final class _HeldTaps extends Fake implements WidgetHost {
  var _held = Completer<void>();
  int taken = 0;

  void hold() => _held = Completer<void>();

  void release() => _held.complete();

  @override
  Future<List<WidgetDoneTap>> takeActions() async {
    taken++;
    await _held.future;
    return const [];
  }
}
