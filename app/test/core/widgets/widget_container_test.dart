import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/outbox/external_done.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_entry_points.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_taps.dart';

import '../../helpers/activity_fakes.dart';
import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

// The widgets over the real providers, as a headless container builds them:
// an in-memory database per account and the real repository, sender,
// scheduler and publisher, with the clients, the engine, the notification
// plugin and the widget plugin faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const alice = User(id: 7, username: 'alice');
  final monday = DateTime(2026, 10, 26, 9);
  final water = sampleTask(
    id: 1,
    title: 'Water the plants',
    projectId: 7,
    due: monday.add(const Duration(hours: 2)),
  ).copyWith(createdBy: alice);
  final repeating = sampleTask(
    id: 2,
    title: 'Take out the bins',
    projectId: 7,
    due: monday.add(const Duration(hours: 3)),
    repeatAfter: const Duration(days: 7),
  ).copyWith(createdBy: alice);
  late DateTime now;
  late AuthFakes auth;
  late RecordingSyncEngine engine;
  late FakeWriteClient write;
  late FakeNotificationGateway gateway;
  late FakeBackgroundScheduler background;
  late FakeWidgetHost host;
  late ProviderContainer container;

  ProviderContainer newContainer({bool headless = true}) {
    final files = FakeAccountDatabaseFiles();
    return ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (_, _) => AppDatabase(NativeDatabase.memory()),
          ),
        ),
        syncEngineProvider.overrideWith((ref, accountId) => engine),
        writeClientProvider.overrideWith((ref, accountId) => write),
        readClientProvider.overrideWith((ref, accountId) => FakeSyncClient()),
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
        backgroundSchedulerProvider.overrideWithValue(background),
        widgetHostProvider.overrideWithValue(host),
        runsHeadlessProvider.overrideWithValue(headless),
      ],
    );
  }

  setUp(() {
    now = monday;
    auth = AuthFakes();
    engine = RecordingSyncEngine(SyncIdle(lastSyncedAt: monday));
    write = FakeWriteClient(clock: () => now);
    gateway = FakeNotificationGateway();
    background = FakeBackgroundScheduler();
    host = FakeWidgetHost();
    container = newContainer();
    addTearDown(container.dispose);
  });

  /// Alice signed in, her database seeded, her notifications scheduled and
  /// a Today widget of hers placed.
  Future<(String, AppDatabase)> signedIn() async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now, userId: alice.id),
    );
    await container.read(accountsProvider.future);
    final db = container.read(appDatabaseProvider(entry.id));
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 7,
        title: 'Home',
      ).copyWith(maxPermission: Permission.write),
    ]);
    await db.tasksDao.upsertAll([water, repeating], syncRunId: 'run');
    write.serverTasks.addEntries([
      MapEntry(water.id, water),
      MapEntry(repeating.id, repeating),
    ]);
    await container.read(notificationSchedulerProvider(entry.id))!.reconcile();
    host.placed[1] = WidgetConfig(accountId: entry.id, kind: const TodayKind());
    return (entry.id, db);
  }

  List<String> todayTitles(String accountId) => [
    for (final row in host.snapshot('$accountId.today')!.rows) row.title,
  ];

  group('the shared Done', () {
    test('marks the task done through the outbox, cancels its '
        'notifications, sends it and redraws the widgets', () async {
      final (accountId, db) = await signedIn();

      await ExternalDone(
        container,
        drainTimeout: const Duration(seconds: 1),
      ).markDone(accountId, 1);

      expect(write.updates, [(1, const TaskChanges(done: true))]);
      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(todayTitles(accountId), ['Take out the bins']);
      expect(
        gateway.cancelled,
        contains(notificationOsIdFor(accountId, '1:due')),
      );
      expect(host.updatedKeys.last, {'$accountId.today'});
    });

    test('without draining, leaves the op for the caller', () async {
      final (accountId, db) = await signedIn();
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: now,
      );

      await ExternalDone(container).settle(accountId, {1}, drains: false);

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 1);
      expect(todayTitles(accountId), ['Take out the bins']);
    });

    test('an expired token queues a background drain', () async {
      final (accountId, db) = await signedIn();
      write.beforeRequest = (_) =>
          throw const TokenRejected(message: 'expired, never refreshed');

      await ExternalDone(container).markDone(accountId, 1);

      expect(await db.outboxDao.count(), 1);
      expect(background.calls, ['drain']);
    });
  });

  group('widget taps', () {
    WidgetDoneTap tap(String id, String accountId, int taskId) => WidgetDoneTap(
      id: id,
      accountId: accountId,
      taskId: taskId,
      createdAt: now,
    );

    test('are applied once each, through the outbox, and acknowledged '
        'after the commit', () async {
      final (accountId, db) = await signedIn();
      host.actions.addAll([
        tap('a', accountId, 1),
        tap('b', accountId, 2),
        tap('c', 'fedcba9876543210fedcba9876543210', 1),
      ]);

      await importWidgetTaps(
        container,
        drainTimeout: const Duration(seconds: 1),
      );

      expect(write.updates, [
        (1, const TaskChanges(done: true)),
        (2, const TaskChanges(done: true)),
      ]);
      expect(host.actions, isEmpty, reason: 'the unknown account dropped');
      expect(host.calls.skipWhile((call) => call != 'ackActions a,b,c'), [
        'ackActions a,b,c',
        'updateAll',
      ], reason: 'a widget drawn before the acknowledgement hides the rows');
      expect(todayTitles(accountId), isNot(contains('Water the plants')));
      expect(await db.importedWidgetActionsDao.contains('a'), isTrue);
    });

    test('read again after a crash before their acknowledgement, are not '
        'applied twice, so a repeating task moves once', () async {
      final (accountId, db) = await signedIn();
      final bins = tap('bins', accountId, 2);
      final applied = await WidgetTapImport(
        container,
        done: ExternalDone(container, drainTimeout: const Duration(seconds: 1)),
      ).apply([bins]);
      expect(applied, {'bins'});
      expect(write.updates, hasLength(1));
      // The app died before the file went.
      host.actions.add(bins);

      await importWidgetTaps(container);

      expect(write.updates, hasLength(1));
      expect(host.actions, isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('a tap whose write fails stays for the next import', () async {
      final (accountId, db) = await signedIn();
      host.actions.add(tap('a', accountId, 1));
      await db.close();

      await importWidgetTaps(container);

      expect(host.actions, hasLength(1));
    });

    test('of a task that is gone are settled', () async {
      final (accountId, db) = await signedIn();
      host.actions.add(tap('gone', accountId, 404));

      await importWidgetTaps(container);

      expect(write.requests, isEmpty);
      expect(host.actions, isEmpty);
      expect(await db.importedWidgetActionsDao.contains('gone'), isTrue);
    });
  });

  test("the worker's entry point applies the queue, publishes every "
      'account and tells the worker, which ends it', () async {
    final (accountId, _) = await signedIn();
    host.actions.add(
      WidgetDoneTap(id: 'w', accountId: accountId, taskId: 1, createdAt: now),
    );
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetWorkerChannel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetWorkerChannel, null),
    );

    addTearDown(resetLoggingForTest);
    await runWidgetActions(createContainer: () async => container);

    expect(write.updates, [(1, const TaskChanges(done: true))]);
    expect(host.actions, isEmpty);
    expect(todayTitles(accountId), ['Take out the bins']);
    expect(calls, ['finished']);
  });

  test('a sign-out replaces the widgets of the account with "Account '
      'removed"', () async {
    final (accountId, _) = await signedIn();
    await container.read(widgetRefresherProvider).refresh(accountId);
    expect(host.snapshot('$accountId.today')?.state, WidgetSnapshotState.ok);

    await container.read(accountDataWiperProvider)(accountId);

    expect(host.calls, contains('deleteForAccount $accountId'));
    final removed = host.snapshot('$accountId.today')!;
    expect(removed.state, WidgetSnapshotState.accountRemoved);
    expect(removed.title, 'Account removed');
    expect(removed.rows, isEmpty);
    expect(host.catalogs, isEmpty);
  });

  test('a headless container builds from the stored switch', () async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(widgetTitles: false),
    );
    final (accountId, _) = await signedIn();

    await container.read(widgetRefresherProvider).refresh(accountId);

    expect(host.snapshot('$accountId.today')!.rows, isEmpty);
    expect(host.snapshot('$accountId.today')!.total, 2);
  });

  group('in the app', () {
    late ProviderContainer app;

    setUp(() {
      app = newContainer(headless: false);
      addTearDown(app.dispose);
    });

    test('a publisher publishes when built, and again soon after its '
        'session ended', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, userId: alice.id),
      );
      await app.read(accountsProvider.future);
      host.placed[1] = WidgetConfig(
        accountId: entry.id,
        kind: const TodayKind(),
      );
      app.listen(accountWidgetPublishersProvider, (_, _) {});
      await pumpEventQueue();
      await app.read(widgetRefresherProvider).refresh(entry.id);
      expect(host.snapshot('${entry.id}.today')?.state, WidgetSnapshotState.ok);

      await app.read(accountRegistryProvider).markNeedsReauth(entry.id);
      await app.read(accountsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue();

      expect(
        host.snapshot('${entry.id}.today')?.state,
        WidgetSnapshotState.needsReauth,
      );
    });

    test('turning task titles off republishes without rows, turning them '
        'on again with them', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, userId: alice.id),
      );
      await app.read(accountsProvider.future);
      final db = app.read(appDatabaseProvider(entry.id));
      await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Home')]);
      await db.tasksDao.upsertAll([water, repeating], syncRunId: 'run');
      host.placed[1] = WidgetConfig(
        accountId: entry.id,
        kind: const TodayKind(),
      );
      app.listen(accountWidgetPublishersProvider, (_, _) {});
      await pumpEventQueue();
      await app.read(widgetRefresherProvider).refresh(entry.id);
      expect(host.snapshot('${entry.id}.today')!.rows, hasLength(2));
      Future<void> showTitles({required bool show}) async {
        await app
            .read(privacySettingsControllerProvider.notifier)
            .change((settings) => settings.copyWith(widgetTitles: show));
        await pumpEventQueue();
      }

      // A list a widget showed before it was removed, with its titles.
      final stale = '${entry.id}.project_9';
      host.snapshots[stale] = host.snapshots['${entry.id}.today']!;

      await showTitles(show: false);

      final hidden = host.snapshot('${entry.id}.today')!;
      expect(hidden.rows, isEmpty);
      expect(hidden.total, 2);
      expect(hidden.empty?.title, '2 tasks');
      expect(hidden.empty?.body, 'Open Rurana to see them');
      expect(host.updatedKeys.last, {'${entry.id}.today'});
      expect(host.snapshots, isNot(contains(stale)));

      await showTitles(show: true);

      expect(todayTitles(entry.id), ['Water the plants', 'Take out the bins']);
    });

    test('the host file follows the active account, whose Today an '
        'unconfigured widget shows', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, userId: alice.id),
      );
      await app.read(accountsProvider.future);
      host.requested.add(
        WidgetConfig(accountId: entry.id, kind: const TodayKind()),
      );

      await app.read(widgetHostSettingsProvider.future);

      expect(host.hostFile, (activeAccountId: entry.id, dynamicColor: true));
      expect(host.snapshot('${entry.id}.today'), isNotNull);
      expect(host.calls, contains('updateAll'));
    });

    test('notes the 24-hour switch for headless isolates', () async {
      await app.read(widgetAlwaysUse24HourFormatProvider.future);

      expect(
        auth.preferences.values[widgetAlwaysUse24HourFormatKey],
        anyOf('true', 'false'),
      );
    });
  });
}
