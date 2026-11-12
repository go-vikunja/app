import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/background/background_runner_channel.dart';
import 'package:vikunja_mobile/core/background/background_sync_runner.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';

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
        notificationGatewayProvider.overrideWithValue(gateway),
        widgetHostProvider.overrideWithValue(widgets),
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
    await background.stop();

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
  });
}
