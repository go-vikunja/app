import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/background/background_providers.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/logging/logging_setup.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/outbox/external_done.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
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
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

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
import '../../helpers/trash_fakes.dart';
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

  ProviderContainer newContainer({
    bool headless = true,
    Duration Function(DateTime utc)? utcOffsetAt,
  }) {
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
        trashPortProvider.overrideWith((ref, accountId) => FakeTrashPort()),
        clockProvider.overrideWithValue(() => now),
        notificationGatewayProvider.overrideWithValue(gateway),
        backgroundSchedulerProvider.overrideWithValue(background),
        widgetHostProvider.overrideWithValue(host),
        runsHeadlessProvider.overrideWithValue(headless),
        attachmentDownloadsProvider.overrideWithValue(
          AttachmentDownloads(() async => Directory('/no-cache')),
        ),
        if (utcOffsetAt != null)
          utcOffsetAtProvider.overrideWithValue(utcOffsetAt),
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
        (
          2,
          TaskChanges(
            done: true,
            doneBase: DoneBase(dueDate: repeating.dueDate!.toUtc()),
          ),
        ),
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

    group('of a repeating task', () {
      final shownDue = repeating.dueDate!;
      final nextDue = shownDue.add(const Duration(days: 7));

      WidgetDoneTap showing(String id, String accountId, DateTime? dueAt) =>
          WidgetDoneTap(
            id: id,
            accountId: accountId,
            taskId: 2,
            createdAt: now,
            shown: (dueAt: dueAt),
          );

      test('whose row showed a due date it has moved past since are '
          'settled without a Done, so it does not move once more', () async {
        final (accountId, db) = await signedIn();
        await db.tasksDao.upsertAll([
          repeating.copyWith(dueDate: nextDue),
        ], syncRunId: 'run');
        host.actions.add(showing('stale', accountId, shownDue));

        await importWidgetTaps(container);

        expect(write.updates, isEmpty);
        expect(await db.outboxDao.count(), 0);
        expect(host.actions, isEmpty);
        expect(await db.importedWidgetActionsDao.contains('stale'), isTrue);
        expect((await db.tasksDao.find(2))!.dueDate, nextDue);
      });

      test('whose row showed the due date it still has are applied', () async {
        final (accountId, _) = await signedIn();
        host.actions.add(showing('current', accountId, shownDue));

        await importWidgetTaps(
          container,
          drainTimeout: const Duration(seconds: 1),
        );

        expect(write.updates, hasLength(1));
        expect(write.updates.single.$1, 2);
      });

      test('written before the rows said what they showed are applied as '
          'before', () async {
        final (accountId, db) = await signedIn();
        await db.tasksDao.upsertAll([
          repeating.copyWith(dueDate: nextDue),
        ], syncRunId: 'run');
        host.actions.add(tap('old', accountId, 2));

        await importWidgetTaps(
          container,
          drainTimeout: const Duration(seconds: 1),
        );

        expect(write.updates, hasLength(1));
      });
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

  test('an account whose session ended on this device is told so, from '
      'its record as a headless container reads it '
      '(decision log: Sessions)', () async {
    final (accountId, _) = await signedIn();
    await SessionDiagnostics(auth.preferences).recordEnd(
      accountId,
      SessionEndDiagnosis(
        at: now.toUtc(),
        cause: SessionEndCause.storageUnreadable,
        part: AppPart.app,
      ),
    );
    await container.read(accountRegistryProvider).markNeedsReauth(accountId);
    await pumpEventQueue();

    await container.read(widgetRefresherProvider).refresh(accountId);

    final today = host.snapshot('$accountId.today')!;
    expect(today.state, WidgetSnapshotState.needsReauth);
    expect(today.message?.title, 'Signed out on this device');
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

  test('a headless container reads the switch anew for every build, as the '
      'app may have turned task titles off since it started', () async {
    final (accountId, _) = await signedIn();
    await container.read(widgetRefresherProvider).refresh(accountId);
    expect(todayTitles(accountId), hasLength(2));

    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(widgetTitles: false),
    );
    await container.read(widgetRefresherProvider).refresh(accountId);

    expect(host.snapshot('$accountId.today')!.rows, isEmpty);
    expect(host.snapshot('$accountId.today')!.total, 2);
  });

  group('an account the app signs out while a headless container runs', () {
    late ProviderContainer app;

    setUp(() {
      app = newContainer(headless: false);
      addTearDown(app.dispose);
    });

    Future<void> signOutInApp(String accountId) async {
      await app.read(accountsProvider.future);
      await app.read(signOutProvider).call(accountId);
      expect(
        host.snapshot('$accountId.today')?.state,
        WidgetSnapshotState.accountRemoved,
      );
    }

    test('keeps "Account removed" on its widgets when a run of the '
        "container writes after the app's wipe", () async {
      final (accountId, _) = await signedIn();
      final publisher = container.read(widgetPublisherProvider(accountId))!;
      await signOutInApp(accountId);

      await publisher.publishNow();

      final today = host.snapshot('$accountId.today')!;
      expect(today.state, WidgetSnapshotState.accountRemoved);
      expect(today.rows, isEmpty);
      expect(host.catalogs, isEmpty);
      await publisher.publishNow();
      expect(host.snapshot('$accountId.today')!.rows, isEmpty);
    });

    test('keeps "Account removed" on its widgets when a write of that run '
        'fails after one landed', () async {
      final (accountId, _) = await signedIn();
      final publisher = container.read(widgetPublisherProvider(accountId))!;
      await signOutInApp(accountId);
      host.catalogFailure = Exception('disk full');

      await expectLater(publisher.publishNow(), throwsException);

      final today = host.snapshot('$accountId.today')!;
      expect(today.state, WidgetSnapshotState.accountRemoved);
      expect(today.rows, isEmpty);
      expect(host.writesOf('$accountId.today'), 3);
    });

    test('is not published again, and its database not opened again, by a '
        'later refresh', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, userId: alice.id),
      );
      await container.read(accountsProvider.future);
      host.placed[1] = WidgetConfig(
        accountId: entry.id,
        kind: const TodayKind(),
      );
      await signOutInApp(entry.id);
      host.calls.clear();

      await container.read(widgetRefresherProvider).refreshAll();

      expect(container.exists(appDatabaseProvider(entry.id)), isFalse);
      expect(host.calls, isEmpty);
      expect(
        host.snapshot('${entry.id}.today')!.state,
        WidgetSnapshotState.accountRemoved,
      );
    });
  });

  test('a registry that turns unreadable while a headless container runs '
      'signs nobody out of its widgets', () async {
    final (accountId, _) = await signedIn();
    auth.preferences.values[AccountRegistry.storageKey] = 'not json';

    await container.read(widgetRefresherProvider).refresh(accountId);

    expect(host.snapshot('$accountId.today')!.state, WidgetSnapshotState.ok);
    expect(todayTitles(accountId), hasLength(2));
    expect(host.catalogs, contains(accountId));
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
      expect(hidden.empty?.body, 'Open Vikunja to see them');
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

      expect(host.hostFile, (activeAccountId: entry.id, dynamicColor: false));
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

    group('a resume', () {
      final binding = TestWidgetsFlutterBinding.instance;
      late Duration offset;
      late ProviderContainer shown;
      late String accountId;

      setUp(() async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        offset = const Duration(hours: 1);
        shown = newContainer(headless: false, utcOffsetAt: (_) => offset);
        addTearDown(shown.dispose);
        final entry = await auth.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: now, userId: alice.id),
        );
        accountId = entry.id;
        await shown.read(accountsProvider.future);
        shown.listen(accountWidgetPublishersProvider, (_, _) {});
        await pumpEventQueue();
      });

      /// A list the host shows from now on, which only a publish writes.
      String shownFromNow(WidgetKind kind) {
        final config = WidgetConfig(accountId: accountId, kind: kind);
        host.requested.add(config);
        return config.key;
      }

      Future<void> back({required bool hidden}) async {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        if (hidden) {
          binding
            ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
            ..handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        }
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await pumpEventQueue();
      }

      test('without a hide before it (the notification shade, a system '
          "dialog, the app lock's prompt) publishes nothing", () async {
        final key = shownFromNow(const OverdueKind());

        await back(hidden: false);

        expect(host.snapshots, isNot(contains(key)));
      });

      test('after a hide publishes once', () async {
        final key = shownFromNow(const OverdueKind());

        await back(hidden: true);
        expect(host.writesOf(key), 1);

        final next = shownFromNow(const UpcomingKind(3));
        await back(hidden: false);
        expect(host.snapshots, isNot(contains(next)));
      });

      test("without a hide publishes when the device's 24-hour switch "
          'changed, which a split screen allows', () async {
        final before = await shown.read(
          widgetAlwaysUse24HourFormatProvider.future,
        );
        binding.platformDispatcher.alwaysUse24HourFormatTestValue = !before;
        addTearDown(binding.platformDispatcher.clearAlwaysUse24HourTestValue);
        final key = shownFromNow(const OverdueKind());

        await back(hidden: false);

        expect(host.writesOf(key), 1);
        expect(
          auth.preferences.values[widgetAlwaysUse24HourFormatKey],
          '${!before}',
        );
      });

      test('without a hide publishes when the time zone changed', () async {
        offset = const Duration(hours: 2);
        final key = shownFromNow(const OverdueKind());

        await back(hidden: false);
        expect(host.writesOf(key), 1);

        final next = shownFromNow(const UpcomingKind(3));
        await back(hidden: false);
        expect(host.snapshots, isNot(contains(next)));
      });
    });
  });
}
