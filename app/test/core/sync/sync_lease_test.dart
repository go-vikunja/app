import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_engine_impl.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

/// Engines of one account in different isolates share its database; these
/// stand for them with two engines on one database, each with a client of
/// its own so the requests tell them apart.
void main() {
  late AppDatabase db;
  late DateTime now;
  final tasks = [
    for (var id = 1; id <= 6; id++) sampleTask(id: id, title: 'Task $id'),
  ];

  FakeSyncClient server() => FakeSyncClient()
    ..allProjects = [sampleProject(id: 1, title: 'Work')]
    ..allTasks = tasks;

  DefaultSyncEngine engine(
    FakeSyncClient client, {
    bool headless = false,
    int? processId,
    Future<void> Function(Duration)? delay,
  }) {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: 2,
      now: () => now,
      headless: headless,
      processId: processId,
      delay: delay ?? (_) => pumpEventQueue(),
    );
    addTearDown(engine.dispose);
    return engine;
  }

  Future<void> leaseTo(String owner, DateTime until, {int? process}) =>
      db.syncStateDao.write({
        SyncStateKeys.syncLease: jsonEncode({
          'owner': owner,
          'until': until.toIso8601String(),
          'process': ?process,
        }),
      });

  Future<Map<String, String>> state() => db.syncStateDao.readAll();

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
  });

  test('a run waits for the one another engine of this process holds, and '
      'purges nothing that one marked', () async {
    final first = server();
    final gate = RequestGate()..pattern = 'done = true';
    first.beforeRequest = gate.call;
    final running = engine(first).ensureInitialSync();
    await pumpEventQueue();
    expect(gate.isHolding, isTrue);

    final second = server();
    final waiting = engine(second).fullResync();
    await pumpEventQueue(times: 50);
    expect(second.requests, isEmpty);

    gate
      ..pattern = null
      ..release();
    await running;
    await waiting;

    expect(second.requests, isNotEmpty);
    expect(await db.tasksDao.count(), 6);
    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
  });

  test('a sync that an ended process left under way resumes at once instead '
      'of waiting for its lease, and the run it displaced purges '
      'nothing', () async {
    final first = server();
    final gate = RequestGate()..pattern = 'done = true';
    first.beforeRequest = gate.call;
    final running = engine(first, processId: 2).ensureInitialSync();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    expect(
      jsonDecode((await state())[SyncStateKeys.syncLease]!),
      containsPair('process', 2),
    );

    final second = server();
    final resuming = engine(
      second,
      processId: 1,
      delay: (_) => fail('waited for the lease'),
    );
    final seen = <SyncStatus>[];
    final subscription = resuming.status.listen(seen.add);
    addTearDown(subscription.cancel);
    await resuming.ensureInitialSync();

    expect(
      seen,
      contains(
        isA<SyncRunning>().having((status) => status.initial, 'initial', true),
      ),
    );
    expect(seen.last, isA<SyncIdle>());
    expect(second.requests, isNot(contains(startsWith('projects page'))));
    expect(await db.tasksDao.count(), 6);
    expect((await state())[SyncStateKeys.lastSyncedAt], isNotNull);
    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);

    gate
      ..pattern = null
      ..release();
    await running;

    expect(await db.tasksDao.count(), 6);
  });

  test('a lease another process left is taken over at once, also by a '
      'headless engine', () async {
    await engine(server()).ensureInitialSync();
    for (final headless in [false, true]) {
      await leaseTo('ended', now.add(const Duration(minutes: 2)), process: 2);
      final client = server();

      final outcome = await engine(
        client,
        headless: headless,
        processId: 1,
        delay: (_) => fail('waited for the lease'),
      ).refresh();

      expect(outcome, SyncOutcome.synced);
      expect(client.requests, isNotEmpty);
      expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
    }
  });

  test('a headless engine gives way to a run in progress in this process, or '
      'to a lease an older version wrote, and syncs nothing', () async {
    await engine(server()).ensureInitialSync();
    final client = server();
    for (final process in [1, null]) {
      await leaseTo(
        'elsewhere',
        now.add(const Duration(minutes: 1)),
        process: process,
      );
      final before = await state();

      expect(
        await engine(client, headless: true, processId: 1).refresh(),
        SyncOutcome.skipped,
      );

      expect(client.requests, isEmpty);
      expect(await state(), before);
    }
    await leaseTo('elsewhere', now.subtract(const Duration(minutes: 1)));
    expect(await engine(client, headless: true).refresh(), SyncOutcome.synced);
  });

  test('the first sync another engine completed meanwhile is not run '
      'again', () async {
    final first = server();
    final gate = RequestGate()..pattern = 'done = true';
    first.beforeRequest = gate.call;
    final running = engine(first).ensureInitialSync();
    await pumpEventQueue();
    final second = server();
    final waiting = engine(second).ensureInitialSync();
    await pumpEventQueue();

    gate
      ..pattern = null
      ..release();
    await running;
    await waiting;

    expect(second.requests, isEmpty);
  });

  test('a lease that ran out, or lies further ahead than a clock set back '
      'allows, is taken over', () async {
    await engine(server()).ensureInitialSync();
    for (final until in [
      now.subtract(const Duration(seconds: 1)),
      now.add(const Duration(hours: 1)),
    ]) {
      await leaseTo('elsewhere', until);
      final client = server();

      await engine(client).refresh();

      expect(client.requests, isNotEmpty);
      expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
    }
  });

  test('a run whose lease another run took stops quietly: it purges nothing '
      'and does not count as a full run', () async {
    final sync = engine(server());
    await sync.ensureInitialSync();
    final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
    now = now.add(const Duration(minutes: 5));
    final client = server();
    final gate = RequestGate()..pattern = 'done = true';
    client.beforeRequest = gate.call;
    final resync = engine(client);
    final seen = <SyncStatus>[];
    final subscription = resync.status.listen(seen.add);
    addTearDown(subscription.cancel);
    final running = resync.fullResync();
    await pumpEventQueue();
    expect(gate.isHolding, isTrue);
    // The run stalled past its lease, another took over and marked a task.
    await leaseTo('elsewhere', now.add(const Duration(minutes: 1)));
    await db.tasksDao.upsertAll([
      sampleTask(id: 99, title: 'Marked by the other run'),
    ], syncRunId: 'other-run');

    gate
      ..pattern = null
      ..release();
    await running;

    expect(await db.tasksDao.find(99), isNotNull);
    expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
    expect(seen.last, isA<SyncIdle>());
    expect(
      jsonDecode((await state())[SyncStateKeys.syncLease]!),
      containsPair('owner', 'elsewhere'),
    );
  });

  test('a run whose lease another run took and let go again, or left to run '
      'out, stops quietly too', () async {
    await engine(server()).ensureInitialSync();
    final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
    for (final takenAndLeft in <Future<void> Function()>[
      () => db.syncStateDao.write({SyncStateKeys.syncLease: null}),
      () => leaseTo('elsewhere', now.subtract(const Duration(minutes: 1))),
    ]) {
      now = now.add(const Duration(minutes: 5));
      final client = server();
      final gate = RequestGate()..pattern = 'done = true';
      client.beforeRequest = gate.call;
      final running = engine(client).fullResync();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      await db.tasksDao.upsertAll([
        sampleTask(id: 99, title: 'Marked by the other run'),
      ], syncRunId: 'other-run');
      await takenAndLeft();

      gate
        ..pattern = null
        ..release();
      await running;

      expect(await db.tasksDao.find(99), isNotNull);
      expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
    }
  });

  test('an incremental run whose lease another run took and let go again '
      'purges no project it reconciles', () async {
    final client = server();
    final sync = engine(client);
    await sync.ensureInitialSync();
    now = now.add(const Duration(minutes: 5));
    // Task 6 is gone on the server, so project 1 is reconciled by id.
    client.allTasks = tasks.take(5).toList();
    final gate = RequestGate()..pattern = 'project 1 tasks id > 4';
    client.beforeRequest = gate.call;
    final running = sync.refresh();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    await db.tasksDao.upsertAll([
      sampleTask(id: 99, title: 'Marked by the other run'),
    ], syncRunId: 'other-run');
    await db.syncStateDao.write({SyncStateKeys.syncLease: null});

    gate
      ..pattern = null
      ..release();

    expect(await running, SyncOutcome.skipped);
    expect(await db.tasksDao.findAll([6, 99]), hasLength(2));
  });

  test('a full run whose lease another run took purges no archived project '
      'it finds gone', () async {
    FakeSyncClient withOld() => FakeSyncClient()
      ..allProjects = [
        sampleProject(id: 1, title: 'Work'),
        sampleProject(id: 2, title: 'Old', archived: true),
      ]
      ..allTasks = [
        ...tasks,
        sampleTask(id: 7, title: 'Old task', projectId: 2),
      ];
    await engine(withOld()).ensureInitialSync();
    final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
    now = now.add(const Duration(minutes: 5));
    final client = withOld();
    final gate = RequestGate()..pattern = 'project 2 tasks';
    client.beforeRequest = gate.call;
    final running = engine(client).fullResync();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    await leaseTo('elsewhere', now.add(const Duration(minutes: 1)));
    client.forbiddenProjects.add(2);

    gate
      ..pattern = null
      ..release();
    await running;

    expect(
      (await db.projectsDao.loadAll()).map((project) => project.id),
      contains(2),
    );
    expect(await db.tasksDao.find(7), isNotNull);
    expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
    expect(
      jsonDecode((await state())[SyncStateKeys.syncLease]!),
      containsPair('owner', 'elsewhere'),
    );
  });

  test('an incremental run whose lease another run took purges no project '
      'it finds gone', () async {
    final client = server();
    final sync = engine(client);
    await sync.ensureInitialSync();
    now = now.add(const Duration(minutes: 5));
    // Task 6 is gone on the server, so the projects are counted one by one.
    client.allTasks = tasks.take(5).toList();
    final gate = RequestGate()..pattern = 'project 1 tasks';
    client.beforeRequest = gate.call;
    final running = sync.refresh();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    await db.syncStateDao.write({SyncStateKeys.syncLease: null});
    client.forbiddenProjects.add(1);

    gate
      ..pattern = null
      ..release();

    expect(await running, SyncOutcome.skipped);
    expect((await db.projectsDao.loadAll()).map((project) => project.id), [1]);
    expect(await db.tasksDao.findAll([1, 2, 3, 4, 5, 6]), hasLength(6));
  });

  test('an incremental run that loses its lease after its walk remembers no '
      'totals', () async {
    final client = FakeSyncClient()
      ..allProjects = [
        sampleProject(id: 1, title: 'Work'),
        sampleProject(id: 2, title: 'Home'),
      ]
      ..allTasks = [
        ...tasks,
        sampleTask(id: 7, title: 'Home task', projectId: 2),
      ];
    await engine(client).ensureInitialSync();
    now = now.add(const Duration(minutes: 5));
    expect(
      await db.outboxDao.queueUpdate(
        6,
        const TaskChanges(done: true),
        now: now,
      ),
      isTrue,
    );
    await db.outboxDao.markFailed(
      (await db.outboxDao.all()).single.id,
      const NotFound(code: 4002),
    );
    client.allTasks = [
      for (final task in client.allTasks)
        if (task.id != 6) task,
    ];
    final gate = RequestGate()..pattern = 'project 2 tasks (all) per_page=1';
    client.beforeRequest = gate.call;
    final running = engine(client).refresh();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    await db.syncStateDao.write({SyncStateKeys.syncLease: null});
    gate
      ..pattern = null
      ..release();

    expect(await running, SyncOutcome.skipped);
    expect(
      (await state()).containsKey(SyncStateKeys.unexplainedTotals),
      isFalse,
    );
    client.requests.clear();

    await engine(client).refresh();

    expect(
      client.requests,
      contains('project 1 tasks (all) per_page=1 page=1'),
    );
  });

  group('a run whose lease another run took and let go again', () {
    FakeSyncClient withHome() => server()
      ..allProjects = [
        ...server().allProjects,
        sampleProject(id: 2, title: 'Home'),
      ]
      ..allTasks = [
        ...tasks,
        sampleTask(id: 7, title: 'Home task', projectId: 2),
      ]
      ..allLabels = [const Label(id: 1, title: 'urgent')];

    Future<void> loseLeaseAt(
      String pattern,
      FakeSyncClient client,
      Future<void> Function() run,
    ) async {
      final gate = RequestGate()..pattern = pattern;
      client.beforeRequest = gate.call;
      final running = run();
      while (!gate.isHolding) {
        await pumpEventQueue();
      }
      await db.syncStateDao.write({SyncStateKeys.syncLease: null});
      gate
        ..pattern = null
        ..release();
      await running;
    }

    test('keeps the projects the server no longer lists, incremental or '
        'full', () async {
      final client = withHome();
      final sync = engine(client);
      await sync.ensureInitialSync();
      final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
      now = now.add(const Duration(minutes: 5));
      client
        ..allProjects = server().allProjects
        ..allTasks = tasks;

      for (final run in <Future<void> Function()>[
        sync.refresh,
        sync.fullResync,
      ]) {
        await loseLeaseAt('projects page 1', client, run);

        expect(
          (await db.projectsDao.loadAll()).map((project) => project.id),
          contains(2),
        );
        expect(await db.tasksDao.find(7), isNotNull);
        expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
      }
    });

    test('keeps the labels the server no longer lists, incremental or '
        'full', () async {
      final client = withHome();
      final sync = engine(client);
      await sync.ensureInitialSync();
      final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
      now = now.add(const Duration(minutes: 5));
      client.allLabels = [];

      for (final run in <Future<void> Function()>[
        sync.refresh,
        sync.fullResync,
      ]) {
        await loseLeaseAt('labels page 1', client, run);

        expect(await db.labelsDao.find(1), isNotNull);
        expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
      }
    });
  });

  test('dispose lets go of the lease of a run under way at once', () async {
    final client = server();
    final gate = RequestGate()..pattern = 'done = true';
    client.beforeRequest = gate.call;
    final sync = engine(client, headless: true);
    final running = sync.ensureInitialSync();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    expect((await state()).containsKey(SyncStateKeys.syncLease), isTrue);

    await sync.dispose();

    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
    gate
      ..pattern = null
      ..release();
    await running;
    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
  });

  test('a disposed engine takes no lease back: a renewal that waited for the '
      'database ends the run before its request', () async {
    final client = server()
      ..allProjects = [
        for (var id = 1; id <= 3; id++) sampleProject(id: id, title: 'P$id'),
      ];
    final gate = RequestGate()..pattern = 'projects page 1';
    client.beforeRequest = gate.call;
    final sync = engine(client);
    final running = sync.ensureInitialSync();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }
    final busy = Completer<void>();
    final blocking = db.transaction(() => busy.future);
    await pumpEventQueue();
    gate
      ..pattern = null
      ..release();
    await pumpEventQueue();

    final disposing = sync.dispose();
    busy.complete();
    await blocking;
    await disposing;
    await running;

    expect(client.requests, isNot(contains(startsWith('projects page 2'))));
    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
  });

  test('a failed run lets go of the lease', () async {
    final client = server()
      ..beforeRequest = (request) async {
        if (request.contains('done = true')) {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };

    await expectLater(
      engine(client).ensureInitialSync(),
      throwsA(isA<NetworkFailure>()),
    );

    expect((await state()).containsKey(SyncStateKeys.syncLease), isFalse);
    expect(SyncCheckpoint.fromState(await state()), isNotNull);
  });

  test('a headless refresh stays incremental when the last full run is a '
      'day old; the app leaves it to its own refresh', () async {
    await engine(server()).ensureInitialSync();
    final lastFull = (await state())[SyncStateKeys.lastFullSyncAt];
    now = now.add(const Duration(hours: 25));

    await engine(server(), headless: true).refresh();

    expect((await state())[SyncStateKeys.lastFullSyncAt], lastFull);
    expect((await state())[SyncStateKeys.lastSyncedAt], now.toIso8601String());

    await engine(server()).refresh();

    expect(
      (await state())[SyncStateKeys.lastFullSyncAt],
      now.toIso8601String(),
    );
  });
}
