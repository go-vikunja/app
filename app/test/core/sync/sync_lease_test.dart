import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
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

  DefaultSyncEngine engine(FakeSyncClient client, {bool headless = false}) {
    final engine = DefaultSyncEngine(
      db: db,
      client: client,
      perPage: 2,
      now: () => now,
      headless: headless,
      delay: (_) => pumpEventQueue(),
    );
    addTearDown(engine.dispose);
    return engine;
  }

  Future<void> leaseTo(String owner, DateTime until) => db.syncStateDao.write({
    SyncStateKeys.syncLease: jsonEncode({
      'owner': owner,
      'until': until.toIso8601String(),
    }),
  });

  Future<Map<String, String>> state() => db.syncStateDao.readAll();

  setUp(() {
    db = testDatabase();
    now = DateTime.utc(2026, 10, 10, 12);
  });

  test('a run waits for the one another engine holds, and purges nothing '
      'that one marked', () async {
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

  test('a headless engine gives way to a run in progress and syncs '
      'nothing', () async {
    await engine(server()).ensureInitialSync();
    await leaseTo('elsewhere', now.add(const Duration(minutes: 1)));
    final before = await state();
    final client = server();

    await engine(client, headless: true).refresh();

    expect(client.requests, isEmpty);
    expect(await state(), before);
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
