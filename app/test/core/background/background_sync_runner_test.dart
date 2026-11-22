import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/background/background_sync_runner.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/widget_fakes.dart';

// The runner over the real providers, with an in-memory database per
// account, fake clients and engines per account and the notification
// plugin faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final monday = DateTime.utc(2026, 10, 12, 9);
  late DateTime now;
  late AuthFakes auth;
  late FakeNotificationGateway gateway;
  late FakeTimers timers;
  late Map<String, AppDatabase> databases;
  late Map<String, FakeSyncEngine> engines;
  late Map<String, FakeSyncClient> reads;
  late Map<String, FakeWriteClient> writes;
  late Set<String> disposedEngines;
  late List<String> order;
  late FakeWidgetHost widgets;
  late RefreshCutoff Function() makeCutoff;
  late ProviderContainer container;

  FakeSyncEngine engineOf(String accountId) => engines.putIfAbsent(
    accountId,
    () => FakeSyncEngine(
      initialStatus: SyncIdle(lastSyncedAt: monday),
      clock: () => now,
    )..onRefresh = () async => order.add('sync $accountId'),
  );

  FakeSyncClient readOf(String accountId) =>
      reads.putIfAbsent(accountId, FakeSyncClient.new);

  FakeWriteClient writeOf(String accountId) =>
      writes.putIfAbsent(accountId, () => FakeWriteClient(clock: () => now));

  setUpAll(() {
    // One in-memory database per account, opened by the provider and by
    // the seeding alike.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );
  });

  setUp(() {
    now = monday;
    auth = AuthFakes();
    gateway = FakeNotificationGateway();
    timers = FakeTimers();
    databases = {};
    engines = {};
    reads = {};
    writes = {};
    disposedEngines = {};
    order = [];
    widgets = FakeWidgetHost();
    makeCutoff = () => RefreshCutoff(clock: () => now);
    final files = FakeAccountDatabaseFiles();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        accountDatabaseFilesProvider.overrideWithValue(files),
        openDatabasesProvider.overrideWithValue(
          OpenDatabases(
            files,
            open: (accountId, _) => databases.putIfAbsent(
              accountId,
              () => AppDatabase(NativeDatabase.memory()),
            ),
          ),
        ),
        syncEngineProvider.overrideWith((ref, accountId) {
          ref.onDispose(() => disposedEngines.add(accountId));
          return engineOf(accountId);
        }),
        readClientProvider.overrideWith((ref, accountId) => readOf(accountId)),
        writeClientProvider.overrideWith(
          (ref, accountId) => writeOf(accountId),
        ),
        clockProvider.overrideWithValue(() => now),
        // Six hours behind UTC, so that the session reminders fall in the
        // day.
        utcOffsetAtProvider.overrideWithValue((_) => const Duration(hours: -6)),
        notificationGatewayProvider.overrideWithValue(gateway),
        widgetHostProvider.overrideWithValue(widgets),
        refreshCutoffProvider.overrideWith((ref) => makeCutoff()),
      ],
    );
    addTearDown(() async {
      for (final db in databases.values) {
        await db.close();
      }
    });
  });

  BackgroundSyncRunner runner({
    Duration deadline = const Duration(minutes: 9),
  }) => BackgroundSyncRunner(
    createContainer: () async => container,
    deadline: deadline,
    now: () => now,
    createTimer: timers.create,
  );

  /// An account as a previous app run left it, synced at [syncedAt]
  /// (never, when null), its activity synced once.
  Future<RegisteredAccount> signedIn(
    int userId, {
    DateTime? syncedAt,
    bool needsReauth = false,
    bool activitySynced = true,
  }) async {
    final entry = await auth.seedAccount(
      fullServer270(root: 'https://server$userId.example.org'),
      tokens: issueTokens(issuedAt: now, userId: userId, username: 'u$userId'),
      needsReauth: needsReauth,
    );
    final db = databases.putIfAbsent(
      entry.id,
      () => AppDatabase(NativeDatabase.memory()),
    );
    await db.syncStateDao.write({
      SyncStateKeys.lastSyncedAt: syncedAt?.toIso8601String(),
      if (activitySynced)
        SyncStateKeys.activitySyncedAt: monday.toIso8601String(),
    });
    return entry;
  }

  Future<BackgroundRunOutcome?> lastOutcome() async =>
      (await BackgroundRunLog(auth.preferences).lastResult())?.outcome;

  test('every step for an account: drain, sync, activity with its '
      'notification, reconcile, noted for the UI', () async {
    final entry = await signedIn(1, syncedAt: monday);
    final db = databases[entry.id]!;
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Water', projectId: 7),
    ], syncRunId: 'run');
    await db.outboxDao.queueUpdate(
      1,
      const TaskChanges(done: true),
      now: monday,
    );
    writeOf(entry.id).serverTasks[1] = sampleTask(id: 1, title: 'Water');
    readOf(entry.id).serverNotifications = [sampleNotification(id: 3)];
    now = monday.add(const Duration(minutes: 30));

    final outcome = await runner().run();

    expect(outcome, BackgroundRunOutcome.completed);
    expect(engineOf(entry.id).refreshCalls, 1);
    expect(writeOf(entry.id).requests, ['update 1']);
    expect(await db.outboxDao.count(), 0);
    expect(readOf(entry.id).requests, contains('notifications 1'));
    expect(
      gateway.activities.single.osId,
      notificationOsIdFor(entry.id, 'activity:3'),
    );
    expect(gateway.calls, contains('pendingIds'));
    expect(await BackgroundRunLog(auth.preferences).lastRunAt(entry.id), now);
    expect(await lastOutcome(), BackgroundRunOutcome.completed);
    expect(disposedEngines, {entry.id});
  });

  group('a sync run sends every queue first', () {
    Future<void> queueDone(RegisteredAccount entry) async {
      final db = databases[entry.id]!;
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Water', projectId: 7),
      ], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: monday,
      );
      writeOf(entry.id)
        ..serverTasks[1] = sampleTask(id: 1, title: 'Water')
        ..beforeRequest = (request) async => order.add(request);
    }

    test('then syncs, once', () async {
      final entry = await signedIn(1, syncedAt: monday);
      await queueDone(entry);

      expect(await runner().run(), BackgroundRunOutcome.completed);

      expect(order, ['update 1', 'sync ${entry.id}']);
      expect(engineOf(entry.id).refreshCalls, 1);
      expect(await databases[entry.id]!.outboxDao.count(), 0);
    });

    test('before any account syncs; an empty queue costs no request', () async {
      final empty = await signedIn(
        1,
        syncedAt: monday.subtract(const Duration(days: 2)),
      );
      final queued = await signedIn(2, syncedAt: monday);
      await queueDone(queued);
      bool? senderBuilt;
      engineOf(empty.id).onRefresh = () async {
        order.add('sync ${empty.id}');
        senderBuilt = container.exists(outboxSenderProvider(empty.id));
      };

      expect(await runner().run(), BackgroundRunOutcome.completed);

      expect(order, ['update 1', 'sync ${empty.id}', 'sync ${queued.id}']);
      expect(senderBuilt, isFalse);
      expect(writeOf(empty.id).requests, isEmpty);
    });

    test("a server that cannot be reached skips the account's sync and "
        'activity; the others still sync', () async {
      final down = await signedIn(
        1,
        syncedAt: monday.subtract(const Duration(hours: 2)),
      );
      final up = await signedIn(2, syncedAt: monday);
      await queueDone(down);
      writeOf(down.id).beforeRequest = (request) async {
        order.add(request);
        throw const NetworkFailure(NetworkProblem.unreachable);
      };
      readOf(down.id).serverNotifications = [sampleNotification(id: 3)];
      readOf(up.id).serverNotifications = [sampleNotification(id: 4)];

      expect(await runner().run(), BackgroundRunOutcome.partial);

      expect(order, ['update 1', 'sync ${up.id}']);
      expect(engines[down.id]?.refreshCalls ?? 0, 0);
      expect(readOf(down.id).requests, isEmpty);
      expect(readOf(up.id).requests, contains('notifications 1'));
      expect(await databases[down.id]!.outboxDao.count(), 1);
    });

    test('and stops at the deadline rule, before any sync', () async {
      final first = await signedIn(
        1,
        syncedAt: monday.subtract(const Duration(hours: 2)),
      );
      final second = await signedIn(2, syncedAt: monday);
      await queueDone(first);
      await queueDone(second);
      writeOf(first.id).beforeRequest = (request) async {
        order.add(request);
        now = now.add(const Duration(seconds: 55));
      };

      final outcome = await runner(deadline: const Duration(minutes: 1)).run();

      expect(outcome, BackgroundRunOutcome.deadline);
      expect(order, ['update 1']);
      expect(writeOf(second.id).requests, isEmpty);
      expect(engines[first.id]?.refreshCalls ?? 0, 0);
      expect(engines[second.id]?.refreshCalls ?? 0, 0);
      expect(await lastOutcome(), BackgroundRunOutcome.deadline);
    });

    test('but not of an account that never synced or must sign in '
        'again', () async {
      final fresh = await signedIn(1);
      final ended = await signedIn(2, syncedAt: monday, needsReauth: true);
      await queueDone(fresh);
      final db = databases[ended.id]!;
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Water', projectId: 7),
      ], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: monday,
      );

      await runner().run();

      expect(writeOf(fresh.id).requests, isEmpty);
      // A sender is built only for a queue it sends.
      expect(writes, isNot(contains(ended.id)));
    });
  });

  test("publishes each account's widgets after its turn, an ended "
      "session's too", () async {
    final synced = await signedIn(1, syncedAt: monday);
    final ended = await signedIn(2, syncedAt: monday, needsReauth: true);
    final fresh = await signedIn(3);
    for (final (id, entry) in [(1, synced), (2, ended), (3, fresh)]) {
      widgets.placed[id] = WidgetConfig(
        accountId: entry.id,
        kind: const TodayKind(),
      );
    }

    await runner().run();

    expect(
      widgets.snapshot('${synced.id}.today')?.state,
      WidgetSnapshotState.ok,
    );
    expect(
      widgets.snapshot('${ended.id}.today')?.state,
      WidgetSnapshotState.needsReauth,
    );
    expect(
      widgets.snapshot('${fresh.id}.today'),
      isNull,
      reason: 'the first-sync screen owns an account that never synced',
    );
  });

  test("imports the widgets' Done taps first, so the run sends them", () async {
    final entry = await signedIn(1, syncedAt: monday);
    final db = databases[entry.id]!;
    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Water', projectId: 7),
    ], syncRunId: 'run');
    writeOf(entry.id).serverTasks[1] = sampleTask(id: 1, title: 'Water');
    widgets.actions.add(
      WidgetDoneTap(id: 'tap', accountId: entry.id, taskId: 1, createdAt: now),
    );

    await runner().run();

    expect(writeOf(entry.id).requests, ['update 1']);
    expect(await db.outboxDao.count(), 0);
    expect(widgets.actions, isEmpty);
  });

  test('skips everything while the app is in front', () async {
    final entry = await signedIn(1, syncedAt: monday);
    await BackgroundRunLog(auth.preferences)
        .beat(now.subtract(const Duration(seconds: 90)));

    expect(await runner().run(), BackgroundRunOutcome.skipped);

    expect(engines[entry.id]?.refreshCalls ?? 0, 0);
    expect(gateway.calls, isEmpty);
    expect(await lastOutcome(), BackgroundRunOutcome.skipped);
  });

  test('runs once the heartbeat is two minutes old', () async {
    final entry = await signedIn(1, syncedAt: monday);
    await BackgroundRunLog(auth.preferences)
        .beat(now.subtract(const Duration(minutes: 2)));

    await runner().run();

    expect(engineOf(entry.id).refreshCalls, 1);
  });

  test('the accounts go oldest-synced first, a never synced one is only '
      'reconciled', () async {
    final recent = await signedIn(1, syncedAt: monday);
    final old = await signedIn(
      2,
      syncedAt: monday.subtract(const Duration(days: 2)),
    );
    final middle = await signedIn(
      3,
      syncedAt: monday.subtract(const Duration(hours: 5)),
    );
    final fresh = await signedIn(4);

    expect(await runner().run(), BackgroundRunOutcome.completed);

    expect(order, ['sync ${old.id}', 'sync ${middle.id}', 'sync ${recent.id}']);
    expect(engines[fresh.id]?.refreshCalls ?? 0, 0);
    expect(readOf(fresh.id).requests, isEmpty);
  });

  test('stops between accounts when too little time is left', () async {
    final first = await signedIn(
      1,
      syncedAt: monday.subtract(const Duration(hours: 2)),
    );
    final second = await signedIn(2, syncedAt: monday);
    engineOf(first.id).onRefresh = () async =>
        now = now.add(const Duration(seconds: 55));

    final outcome = await runner(deadline: const Duration(minutes: 1)).run();

    expect(outcome, BackgroundRunOutcome.deadline);
    expect(engineOf(first.id).refreshCalls, 1);
    expect(engines[second.id]?.refreshCalls ?? 0, 0);
    expect(await lastOutcome(), BackgroundRunOutcome.deadline);
    expect(disposedEngines, {first.id});
  });

  test(
    'at the deadline the container is disposed, which aborts the sync',
    () async {
      final entry = await signedIn(1, syncedAt: monday);
      final gate = Completer<void>();
      engineOf(entry.id).onRefresh = () => gate.future;

      final run = runner().run();
      await pumpEventQueue();
      expect(engineOf(entry.id).refreshCalls, 1);
      timers.fireNext();

      expect(await run, BackgroundRunOutcome.deadline);
      expect(disposedEngines, {entry.id});
      gate.complete();
    },
  );

  test('a session that ended marks the account and notifies once', () async {
    final entry = await signedIn(1, syncedAt: monday);
    auth.tokenGateway.onRefresh = (_) async =>
        throw const SessionEnded(SessionEndReason.expired);
    // The engine's first request asks for a token, like GET /user.
    engineOf(entry.id).onRefresh = () async {
      await container
          .read(sessionManagersProvider)
          .forAccount(entry.id)
          .validAccessToken();
    };
    now = monday.add(const Duration(hours: 1));

    expect(await runner().run(), BackgroundRunOutcome.partial);

    expect(
      (await AccountRegistry(auth.preferences).find(entry.id))!
          .account
          .needsReauth,
      isTrue,
    );
    final notice = gateway.activities.single;
    expect(notice.title, 'Sign in again to server1.example.org');
    expect(
      jsonDecode(notice.payload),
      containsPair('key', 'session:${entry.id}'),
    );
    expect(writeOf(entry.id).requests, isEmpty);
    expect(readOf(entry.id).requests, isEmpty);
    expect(
      await BackgroundRunLog(auth.preferences).lastRunAt(entry.id),
      isNull,
    );
  });

  test('an account in needsReauth gets the notice once and its notifications '
      'refilled, nothing on the network', () async {
    final entry = await signedIn(1, syncedAt: monday, needsReauth: true);

    await runner().run();
    await runner().run();

    expect(gateway.activities, hasLength(1));
    expect(gateway.calls, contains('pendingIds'));
    expect(engines[entry.id]?.refreshCalls ?? 0, 0);
    expect(readOf(entry.id).requests, isEmpty);
  });

  test('a failed step does not stop the others, the run is partial', () async {
    final entry = await signedIn(1, syncedAt: monday);
    engineOf(entry.id).onRefresh = () async => throw const ServerFailure(500);
    readOf(entry.id).serverNotifications = [sampleNotification(id: 3)];

    expect(await runner().run(), BackgroundRunOutcome.partial);

    expect(readOf(entry.id).requests, contains('notifications 1'));
    expect(gateway.activities, hasLength(1));
    expect(
      await BackgroundRunLog(auth.preferences).lastRunAt(entry.id),
      isNull,
    );
  });

  test('a sync that gave way to another run of the account is not noted as '
      'synced; the activity still comes', () async {
    final entry = await signedIn(1, syncedAt: monday);
    engineOf(entry.id).refreshOutcome = SyncOutcome.skipped;
    readOf(entry.id).serverNotifications = [sampleNotification(id: 3)];

    expect(await runner().run(), BackgroundRunOutcome.completed);

    expect(engineOf(entry.id).refreshCalls, 1);
    expect(readOf(entry.id).requests, contains('notifications 1'));
    expect(
      await BackgroundRunLog(auth.preferences).lastRunAt(entry.id),
      isNull,
    );
  });

  test('an unreachable server costs one timeout: the notifications are '
      'refilled first, the other network steps are skipped', () async {
    final entry = await signedIn(1, syncedAt: monday);
    engineOf(entry.id).onRefresh = () async {
      order.add('sync ${entry.id}');
      expect(gateway.calls, contains('pendingIds'));
      throw const NetworkFailure(NetworkProblem.unreachable);
    };
    readOf(entry.id).serverNotifications = [sampleNotification(id: 3)];

    expect(await runner().run(), BackgroundRunOutcome.partial);

    expect(order, ['sync ${entry.id}']);
    expect(readOf(entry.id).requests, isEmpty);
    expect(writeOf(entry.id).requests, isEmpty);
  });

  test('the accounts take turns: the one whose last turn is oldest goes '
      'first, however long ago it synced', () async {
    final log = BackgroundRunLog(auth.preferences);
    final stuck = await signedIn(
      1,
      syncedAt: monday.subtract(const Duration(days: 3)),
    );
    final other = await signedIn(2, syncedAt: monday);
    await log.recordAttempt(
      stuck.id,
      monday.subtract(const Duration(hours: 1)),
    );
    await log.recordAttempt(
      other.id,
      monday.subtract(const Duration(hours: 2)),
    );

    await runner().run();

    expect(order, ['sync ${other.id}', 'sync ${stuck.id}']);
    expect(await log.lastAttemptAt(stuck.id), now);
    expect(await log.lastAttemptAt(other.id), now);
  });

  test(
    'stops before the next account once the app came to the front',
    () async {
      final first = await signedIn(
        1,
        syncedAt: monday.subtract(const Duration(hours: 2)),
      );
      final second = await signedIn(2, syncedAt: monday);
      engineOf(first.id).onRefresh = () async {
        order.add('sync ${first.id}');
        await BackgroundRunLog(auth.preferences).beat(now);
      };

      expect(await runner().run(), BackgroundRunOutcome.skipped);

      expect(order, ['sync ${first.id}']);
      expect(engines[second.id]?.refreshCalls ?? 0, 0);
    },
  );

  test('when the OS stops the run it ends like at the deadline and notes '
      'it', () async {
    final entry = await signedIn(1, syncedAt: monday);
    final gate = Completer<void>();
    engineOf(entry.id).onRefresh = () => gate.future;
    final background = runner();

    final run = background.run();
    await pumpEventQueue();
    await background.stop(reason: 0);

    expect(await run, BackgroundRunOutcome.stopped);
    expect(await lastOutcome(), BackgroundRunOutcome.stopped);
    expect(disposedEngines, {entry.id});
    gate.complete();
  });

  test('a drain run only drains', () async {
    final entry = await signedIn(1, syncedAt: monday);
    final db = databases[entry.id]!;
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Water', projectId: 7),
    ], syncRunId: 'run');
    await db.outboxDao.queueUpdate(
      1,
      const TaskChanges(done: true),
      now: monday,
    );
    // A backoff another isolate armed does not hold it back.
    await db.outboxDao.scheduleRetry(
      (await db.outboxDao.all()).single.id,
      attempts: 1,
      failure: const TokenRejected(),
      nextAttemptAt: monday.add(const Duration(minutes: 5)),
    );
    writeOf(entry.id).serverTasks[1] = sampleTask(id: 1, title: 'Water');

    expect(
      await runner().run(kind: BackgroundRunKind.drain),
      BackgroundRunOutcome.completed,
    );

    expect(writeOf(entry.id).requests, ['update 1']);
    expect(readOf(entry.id).requests, isEmpty);
    expect(gateway.calls, isNot(contains('pendingIds')));
  });

  test('a session that ends during a drain is noticed as well', () async {
    final entry = await signedIn(1, syncedAt: monday);
    final db = databases[entry.id]!;
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Water', projectId: 7),
    ], syncRunId: 'run');
    await db.outboxDao.queueUpdate(
      1,
      const TaskChanges(done: true),
      now: monday,
    );
    // What the session manager does when the refresh says the session is
    // gone.
    writeOf(entry.id).beforeRequest = (_) async {
      await AccountRegistry(auth.preferences).markNeedsReauth(entry.id);
      throw const SessionEnded(SessionEndReason.expired);
    };

    expect(
      await runner().run(kind: BackgroundRunKind.drain),
      BackgroundRunOutcome.partial,
    );

    expect(await db.outboxDao.count(), 1);
    expect(gateway.activities.single.payload, contains('session:${entry.id}'));
  });

  test('no account: nothing to run', () async {
    expect(await runner().run(), BackgroundRunOutcome.nothing);
  });

  test('never throws, also when the container cannot be built', () async {
    final failing = BackgroundSyncRunner(
      createContainer: () async => throw StateError('no plugins'),
      deadline: const Duration(seconds: 25),
    );

    expect(await failing.run(), BackgroundRunOutcome.nothing);
  });

  test(
    'a sign-out in another isolate makes the run let go of the account',
    () async {
      final entry = await signedIn(1, syncedAt: monday);
      final gate = Completer<void>();
      engineOf(entry.id).onRefresh = () => gate.future;
      readOf(entry.id).serverNotifications = [sampleNotification(id: 3)];

      final run = runner().run();
      await pumpEventQueue();
      BackgroundRunnerChannel.release(entry.id);
      await pumpEventQueue();
      gate.complete();

      await run;
      expect(writeOf(entry.id).requests, isEmpty);
      expect(readOf(entry.id).requests, isEmpty);
      expect(gateway.activities, isEmpty);
    },
  );

  group('a link-share guest', () {
    Future<RegisteredAccount> guestSignedIn({DateTime? syncedAt}) async {
      final entry = await auth.seedGuest(
        fullServer270(root: 'https://shared.example.org'),
        token: issueLinkShareToken(issuedAt: now),
      );
      await databases
          .putIfAbsent(entry.id, () => AppDatabase(NativeDatabase.memory()))
          .syncStateDao
          .write({
            SyncStateKeys.lastSyncedAt: syncedAt?.toIso8601String(),
            SyncStateKeys.activitySyncedAt: monday.toIso8601String(),
          });
      return entry;
    }

    test('is synced, drained and reconciled, without the activity the server '
        'refuses it, and the run completes', () async {
      final guest = await guestSignedIn(syncedAt: monday);
      final user = await signedIn(1, syncedAt: monday);
      final db = databases[guest.id]!;
      await db.projectsDao.upsertAll([
        sampleProject(id: 1378, title: 'Garden'),
      ]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Water', projectId: 1378),
      ], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: monday,
      );
      writeOf(guest.id).serverTasks[1] = sampleTask(id: 1, title: 'Water');
      readOf(guest.id).serverNotifications = [sampleNotification(id: 3)];
      readOf(user.id).serverNotifications = [sampleNotification(id: 4)];
      now = monday.add(const Duration(minutes: 30));

      expect(await runner().run(), BackgroundRunOutcome.completed);

      expect(engineOf(guest.id).refreshCalls, greaterThanOrEqualTo(1));
      expect(writeOf(guest.id).requests, ['update 1']);
      expect(readOf(guest.id).requests, isNot(contains(startsWith('notif'))));
      expect(readOf(user.id).requests, contains('notifications 1'));
      expect(await BackgroundRunLog(auth.preferences).lastRunAt(guest.id), now);
    });

    test(
      'whose share is gone is marked and noticed like an ended session',
      () async {
        final guest = await guestSignedIn(syncedAt: monday);
        engineOf(guest.id).onRefresh = () async {
          container
              .read(linkShareSessionsProvider)
              .forAccount(guest.id)
              .noteGone(const LinkShareGone(code: 13003));
          throw const LinkShareGone(code: 13003);
        };

        expect(await runner().run(), BackgroundRunOutcome.partial);

        expect(
          (await AccountRegistry(auth.preferences).find(guest.id))!
              .account
              .needsReauth,
          isTrue,
        );
        expect(
          gateway.activities.single.payload,
          contains('session:${guest.id}'),
        );
      },
    );

    test('whose link this device lost is told that it ended here, not on '
        'the server (decision log: Sessions)', () async {
      final guest = await guestSignedIn(syncedAt: monday);
      await auth.linkShareStore.delete(guest.id);
      engineOf(guest.id).onRefresh = () async {
        await container
            .read(linkShareSessionsProvider)
            .forAccount(guest.id)
            .validAccessToken();
      };

      expect(await runner().run(), BackgroundRunOutcome.partial);

      final ended = (await SessionDiagnostics(auth.preferences)
          .lastEnd(guest.id))!;
      expect(ended.cause, SessionEndCause.missingTokens);
      expect(
        gateway.activities.single.body,
        lookupAppLocalizations(const Locale('en'))
            .guestAccessEndedOnDeviceNotificationBody('shared.example.org'),
      );
    });

    test('at the deadline, an authentication on its way gets the grace to '
        'store its token', () async {
      final guest = await guestSignedIn(syncedAt: monday);
      final answer = Completer<LinkShareAuth>();
      auth.linkShareGateway.onAuthenticate = (_, _) => answer.future;
      // The stored token expired days ago by the device's clock.
      engineOf(guest.id).onRefresh = () async {
        await container
            .read(linkShareSessionsProvider)
            .forAccount(guest.id)
            .validAccessToken();
      };

      final run = runner().run();
      var finished = false;
      unawaited(run.then((_) => finished = true));
      await pumpEventQueue();
      expect(auth.linkShareGateway.authentications, hasLength(1));
      timers.fireNext();
      await pumpEventQueue();
      expect(finished, isFalse);
      final fresh = issueLinkShareToken(issuedAt: DateTime.now().toUtc());
      answer.complete(linkShareAuthFor(fresh));

      expect(await run, BackgroundRunOutcome.deadline);
      expect((await auth.linkShareStore.read(guest.id))?.token, fresh.jwt);
    });

    test('a sign-out elsewhere retires its session too', () async {
      final guest = await guestSignedIn(syncedAt: monday);
      final gate = Completer<void>();
      engineOf(guest.id).onRefresh = () => gate.future;
      final sessions = container.read(linkShareSessionsProvider);

      final run = runner().run();
      await pumpEventQueue();
      BackgroundRunnerChannel.release(guest.id);
      await pumpEventQueue();
      gate.complete();
      await run;

      await expectLater(
        sessions.forAccount(guest.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(auth.linkShareGateway.authentications, isEmpty);
    });

    test('gets no session reminder', () async {
      final guest = await guestSignedIn(syncedAt: monday);

      expect(await runner().run(), BackgroundRunOutcome.completed);

      final reminderId = sessionReminderOsId(guest.id);
      expect(gateway.calls, isNot(contains('scheduleActivity $reminderId')));
      expect(gateway.calls, isNot(contains('cancel $reminderId')));
    });
  });

  group('the session reminder', () {
    const sixtyHours = Duration(hours: 60);

    test('is moved by the turn: 60 h after the sync it made', () async {
      final entry = await signedIn(1, syncedAt: monday, activitySynced: false);
      now = monday.add(const Duration(minutes: 30));
      engineOf(entry.id).onRefresh = () => databases[entry.id]!.syncStateDao
          .write({SyncStateKeys.lastSyncedAt: now.toIso8601String()});

      expect(await runner().run(), BackgroundRunOutcome.completed);

      final reminder = gateway.scheduledActivities.single;
      expect(reminder.osId, sessionReminderOsId(entry.id));
      expect(reminder.fireAt, now.add(sixtyHours));
    });

    test('is cancelled once the session ended during the turn', () async {
      final entry = await signedIn(1, syncedAt: monday);
      await container.read(accountsProvider.future);
      await container.read(sessionRemindersProvider).update(entry.id);
      expect(gateway.pending, contains(sessionReminderOsId(entry.id)));
      auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired);
      engineOf(entry.id).onRefresh = () async {
        await container
            .read(sessionManagersProvider)
            .forAccount(entry.id)
            .validAccessToken();
      };
      now = monday.add(const Duration(hours: 1));

      expect(await runner().run(), BackgroundRunOutcome.partial);

      expect(gateway.pending, isNot(contains(sessionReminderOsId(entry.id))));
    });

    test('is cancelled for an account that must sign in again', () async {
      final entry = await signedIn(1, syncedAt: monday, needsReauth: true);
      final reminderId = sessionReminderOsId(entry.id);
      gateway.pending[reminderId] = ScheduledNotification(
        osId: reminderId,
        fireAt: monday.add(sixtyHours),
        title: 'Open the app',
        body: '',
        payload: '',
        exact: false,
      );

      await runner().run();

      expect(gateway.pending, isNot(contains(reminderId)));
      expect(gateway.scheduledActivities, isEmpty);
    });
  });

  group('keeping sessions alive (decision log: Sessions)', () {
    // The seeded tokens were issued at [monday], long expired by the real
    // clock the session managers use, so every first request refreshes.
    Future<void> needsToken(String accountId) => container
        .read(sessionManagersProvider)
        .forAccount(accountId)
        .validAccessToken();

    TokenSet renewed(int userId) =>
        issueTokens(issuedAt: DateTime.now(), userId: userId);

    Future<bool> needsReauth(String accountId) async =>
        (await AccountRegistry(auth.preferences).find(accountId))!
            .account
            .needsReauth;

    const log = BackgroundRunLog.new;

    Future<BackgroundAccountOutcome?> turnOf(String accountId) async =>
        (await log(auth.preferences).lastOutcome(accountId))?.outcome;

    test('answers must arrive within the settle time after the deadline, '
        'less the margin and the connect time', () async {
      makeCutoff = () => RefreshCutoff(
        clock: () => now,
        connectTimeout: const Duration(seconds: 10),
        minimumTokenTimeout: const Duration(seconds: 30),
      );
      final entry = await signedIn(1, syncedAt: monday);
      final seen = <(Duration, bool)>[];
      engineOf(entry.id).onRefresh = () async {
        final cutoff = container.read(refreshCutoffProvider);
        for (final at in const [
          Duration.zero,
          Duration(minutes: 8, seconds: 20),
          Duration(minutes: 8, seconds: 24),
        ]) {
          now = monday.add(at);
          seen.add((cutoff.tokenTimeout, cutoff.allowsRefresh));
        }
      };

      await runner().run();

      // 9 min + 5 s settle - 2 s margin - 10 s connect.
      expect(seen, [
        (const Duration(seconds: 60), true),
        (const Duration(seconds: 33), true),
        (const Duration(seconds: 29), false),
      ]);
    });

    test('no turn starts once a token refresh could no longer start, and '
        'none counts as its attempt', () async {
      makeCutoff = () => RefreshCutoff(
        clock: () => now,
        minimumTokenTimeout: const Duration(minutes: 10),
      );
      final entry = await signedIn(1, syncedAt: monday);
      auth.tokenGateway.onRefresh = (_) async => renewed(1);
      engineOf(entry.id).onRefresh = () => needsToken(entry.id);

      expect(await runner().run(), BackgroundRunOutcome.deadline);

      expect(engineOf(entry.id).refreshCalls, 0);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(await log(auth.preferences).lastAttemptAt(entry.id), isNull);
    });

    test('a refresh the cutoff holds back is noted as deferred, not as an '
        'unreachable server', () async {
      makeCutoff = () => RefreshCutoff(
        clock: () => now,
        minimumTokenTimeout: const Duration(seconds: 30),
      );
      final entry = await signedIn(1, syncedAt: monday);
      auth.tokenGateway.onRefresh = (_) async => renewed(1);
      engineOf(entry.id).onRefresh = () async {
        now = monday.add(const Duration(minutes: 8, seconds: 40));
        await needsToken(entry.id);
      };

      expect(await runner().run(), BackgroundRunOutcome.partial);

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(await needsReauth(entry.id), isFalse);
      expect(await turnOf(entry.id), BackgroundAccountOutcome.deferred);
    });

    test('secure storage that refuses to read is noted as such, not as an '
        'unreachable server', () async {
      final entry = await signedIn(1, syncedAt: monday);
      auth.tokenGateway.onRefresh = (_) async => renewed(1);
      auth.secureStore.beforeRead = (_) async =>
          throw PlatformException(code: 'keystore');
      engineOf(entry.id).onRefresh = () => needsToken(entry.id);

      expect(await runner().run(), BackgroundRunOutcome.partial);

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(await needsReauth(entry.id), isFalse);
      expect(
        await turnOf(entry.id),
        BackgroundAccountOutcome.storageUnreadable,
      );
    });

    test("a guest's link that secure storage refuses to read is noted as "
        'such, not as an unreachable server', () async {
      final guest = await auth.seedGuest(
        fullServer270(root: 'https://shared.example.org'),
        token: issueLinkShareToken(issuedAt: now),
      );
      await databases
          .putIfAbsent(guest.id, () => AppDatabase(NativeDatabase.memory()))
          .syncStateDao
          .write({SyncStateKeys.lastSyncedAt: monday.toIso8601String()});
      auth.secureStore.beforeRead = (_) async =>
          throw PlatformException(code: 'keystore');
      engineOf(guest.id).onRefresh = () async {
        await container
            .read(linkShareSessionsProvider)
            .forAccount(guest.id)
            .validAccessToken();
      };

      expect(await runner().run(), BackgroundRunOutcome.partial);

      expect(auth.linkShareGateway.authentications, isEmpty);
      expect(await needsReauth(guest.id), isFalse);
      expect(
        await turnOf(guest.id),
        BackgroundAccountOutcome.storageUnreadable,
      );
    });

    test("a stop closes the gate at once and notes the system's reason for "
        'the turn it cut short', () async {
      final entry = await signedIn(1, syncedAt: monday);
      final syncing = Completer<void>();
      final release = Completer<void>();
      engineOf(entry.id).onRefresh = () async {
        syncing.complete();
        await release.future;
      };
      final cutoff = container.read(refreshCutoffProvider);
      final background = runner();

      final run = background.run();
      await syncing.future;
      expect(cutoff.allowsRefresh, isTrue);
      // Android's WorkInfo.STOP_REASON_CONSTRAINT_CONNECTIVITY, as the
      // plugin passes it through.
      final stopping = background.stop(reason: 7);
      expect(cutoff.allowsRefresh, isFalse);

      expect(await run, BackgroundRunOutcome.stopped);
      await stopping;
      release.complete();

      final turn = (await log(auth.preferences).lastOutcome(entry.id))!;
      expect(turn.outcome, BackgroundAccountOutcome.stopped);
      expect(turn.stopReason, 7);
      expect(
        jsonDecode(auth.preferences.values[BackgroundRunLog.lastRunResultKey]!),
        isNot(contains('stopReason')),
      );
    });

    test("a turn the run's own deadline cut short is noted as stopped "
        'without a reason of the system', () async {
      final entry = await signedIn(1, syncedAt: monday);
      final syncing = Completer<void>();
      final release = Completer<void>();
      engineOf(entry.id).onRefresh = () async {
        syncing.complete();
        await release.future;
      };

      final run = runner().run();
      await syncing.future;
      timers.fireNext();

      expect(await run, BackgroundRunOutcome.deadline);
      release.complete();
      final turn = (await log(auth.preferences).lastOutcome(entry.id))!;
      expect(turn.outcome, BackgroundAccountOutcome.stopped);
      expect(turn.stopReason, isNull);
    });

    test('a session that ends during the settle after the deadline is noted '
        'as ended, not as a turn the deadline cut short', () async {
      final entry = await signedIn(1, syncedAt: monday);
      final answer = Completer<TokenSet>();
      auth.tokenGateway.onRefresh = (_) => answer.future;
      engineOf(entry.id).onRefresh = () => needsToken(entry.id);

      final run = runner().run();
      await pumpEventQueue();
      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      timers.fireNext();
      await pumpEventQueue();
      answer.completeError(
        const SessionEnded(SessionEndReason.expired, code: 16003),
      );

      expect(await run, BackgroundRunOutcome.deadline);
      expect(await needsReauth(entry.id), isTrue);
      expect(await turnOf(entry.id), BackgroundAccountOutcome.sessionEnded);
    });

    test('a turn whose sync went through counts as synced when the deadline '
        'falls during its activity fetch', () async {
      final entry = await signedIn(1, syncedAt: monday);
      final fetching = Completer<void>();
      final release = Completer<void>();
      readOf(entry.id).beforeRequest = (request) async {
        if (!request.startsWith('notifications')) return;
        fetching.complete();
        await release.future;
      };
      now = monday.add(const Duration(minutes: 3));

      final run = runner().run();
      await fetching.future;
      timers.fireNext();

      expect(await run, BackgroundRunOutcome.deadline);
      release.complete();
      expect(await turnOf(entry.id), BackgroundAccountOutcome.synced);
      expect(await log(auth.preferences).lastRunAt(entry.id), now);
    });

    test('a run that went through still stores tokens storage refused at '
        'first', () async {
      final entry = await signedIn(1, syncedAt: monday);
      final fresh = renewed(1);
      auth.tokenGateway.onRefresh = (_) async => fresh;
      var refusals = 1;
      auth.secureStore.beforeWrite = (_) async {
        if (refusals-- > 0) throw StateError('storage busy');
      };
      engineOf(entry.id).onRefresh = () => needsToken(entry.id);

      expect(await runner().run(), BackgroundRunOutcome.completed);

      expect(
        (await auth.tokenStore.read(entry.id))!.refreshToken,
        fresh.refreshToken,
      );
    });

    test('each turn notes how it ended', () async {
      final synced = await signedIn(1, syncedAt: monday);
      final waiting = await signedIn(2, syncedAt: monday, needsReauth: true);
      final ended = await signedIn(3, syncedAt: monday);
      auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired);
      engineOf(ended.id).onRefresh = () => needsToken(ended.id);

      await runner().run();

      expect(await turnOf(synced.id), BackgroundAccountOutcome.synced);
      expect(await turnOf(waiting.id), BackgroundAccountOutcome.signInNeeded);
      expect(await turnOf(ended.id), BackgroundAccountOutcome.sessionEnded);
    });

    test('an account waiting for a sign-in works again when another isolate '
        'stored newer tokens after this one gave up', () async {
      final entry = await signedIn(1, syncedAt: monday, needsReauth: true);
      final diagnostics = SessionDiagnostics(auth.preferences);
      await diagnostics.recordEnd(
        entry.id,
        SessionEndDiagnosis(
          at: monday,
          cause: SessionEndCause.refreshRejected,
          part: AppPart.backgroundRun,
          failedToken: tokenFingerprint('rotated-away'),
        ),
      );
      auth.tokenGateway.onRefresh = (_) async => renewed(1);

      await runner().run();

      expect(await needsReauth(entry.id), isFalse);
      expect(engineOf(entry.id).refreshCalls, 1);
      expect(gateway.activities, isEmpty);
      expect(await turnOf(entry.id), BackgroundAccountOutcome.synced);
      expect(
        (await diagnostics.lastEnd(entry.id))!.resolution,
        SessionEndResolution.restored,
      );
    });

    test('an account that works again sends its queue before it '
        'syncs', () async {
      final entry = await signedIn(1, syncedAt: monday, needsReauth: true);
      final db = databases[entry.id]!;
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Water', projectId: 7),
      ], syncRunId: 'run');
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: monday,
      );
      writeOf(entry.id)
        ..serverTasks[1] = sampleTask(id: 1, title: 'Water')
        ..beforeRequest = (request) async => order.add(request);
      await SessionDiagnostics(auth.preferences).recordEnd(
        entry.id,
        SessionEndDiagnosis(
          at: monday,
          cause: SessionEndCause.refreshRejected,
          part: AppPart.backgroundRun,
          failedToken: tokenFingerprint('rotated-away'),
        ),
      );
      auth.tokenGateway.onRefresh = (_) async => renewed(1);

      await runner().run();

      expect(await needsReauth(entry.id), isFalse);
      expect(order, ['update 1', 'sync ${entry.id}']);
      expect(writeOf(entry.id).requests, ['update 1']);
      expect(await turnOf(entry.id), BackgroundAccountOutcome.synced);
    });

    test('a guest waiting for a sign-in only because its link could not be '
        'read goes on once it reads', () async {
      final guest = await auth.seedGuest(
        fullServer270(root: 'https://shared.example.org'),
        token: issueLinkShareToken(issuedAt: now),
        needsReauth: true,
      );
      await databases
          .putIfAbsent(guest.id, () => AppDatabase(NativeDatabase.memory()))
          .syncStateDao
          .write({SyncStateKeys.lastSyncedAt: monday.toIso8601String()});
      final diagnostics = SessionDiagnostics(auth.preferences);
      await diagnostics.recordEnd(
        guest.id,
        SessionEndDiagnosis(
          at: monday,
          cause: SessionEndCause.storageUnreadable,
          part: AppPart.app,
        ),
      );

      await runner().run();

      expect(await needsReauth(guest.id), isFalse);
      expect(engineOf(guest.id).refreshCalls, 1);
      expect(await turnOf(guest.id), BackgroundAccountOutcome.synced);
      expect(
        (await diagnostics.lastEnd(guest.id))!.resolution,
        SessionEndResolution.restored,
      );
    });
  });
}
