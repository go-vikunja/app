import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

// The sender with list positions: they go after the rest of the update,
// kanban placements included, the downloaded list follows what the server
// accepted (no sync would), and a refusal is a sync problem that puts the
// row back once discarded.
void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late OutboxSender sender;
  final now = DateTime.utc(2026, 10, 19, 12);
  final one = sampleTask(id: 1, title: 'One', projectId: 7);
  final two = sampleTask(id: 2, title: 'Two', projectId: 7);

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: FakeSyncClient()
        ..allProjects = [sampleProject(id: 7, title: 'Work')]
        ..allTasks = [one, two],
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    await db.tasksDao.upsertAll([one, two], syncRunId: 'run');
    await db.listSnapshotsDao.replace('view:70', {
      1: 65536,
      2: 131072,
    }, loadedAt: now);
    write.serverTasks.addAll({1: one, 2: two});
  });

  Future<void> queue(int id, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(id, changes, now: now), isTrue);
  }

  test('a reorder goes as the position, and the downloaded list follows '
      'with nothing left queued', () async {
    await queue(2, const TaskChanges(positions: {70: 32768}));
    expect((await db.tasksDao.loadProjectList(7, viewId: 70)).queuedPositions, {
      2: 32768.0,
    });

    await sender.drain();

    expect(write.requests, ['update 2', 'position 2 view 70 32768.0']);
    expect(write.listPositions[70], {2: 32768.0});
    final list = await db.tasksDao.loadProjectList(7, viewId: 70);
    expect(list.queuedPositions, isEmpty);
    expect(list.snapshot.taskIds, [2, 1]);
    expect(await db.outboxDao.count(), 0);
  });

  test('positions go last, after the body and the kanban moves', () async {
    write.bucketSlots[80] = {1: (bucketId: 1, position: 1)};
    await queue(
      1,
      const TaskChanges(
        title: 'Renamed',
        kanban: {80: BucketPlacement(bucketId: 2, position: 5)},
        positions: {70: 200000, 71: 3},
      ),
    );

    await sender.drain();

    expect(write.requests, [
      'update 1',
      'move 1 view 80 bucket 2',
      'position 1 view 80 5.0',
      'position 1 view 70 200000.0',
      'position 1 view 71 3.0',
    ]);
    expect((await db.listSnapshotsDao.load('view:70')).positions, {
      2: 131072.0,
      1: 200000.0,
    });
    expect((await db.listSnapshotsDao.load('view:71')).loadedAt, isNull);
  });

  test('a position queued behind a create goes once the server named the '
      'task, under its id', () async {
    final local = await db.outboxDao.queueCreate(
      const NewTask(projectId: 7, title: 'New'),
      now: now,
    );
    await queue(local, const TaskChanges(positions: {70: 98304}));

    await sender.drain();

    expect(write.requests, [
      'create New',
      'update 100',
      'position 100 view 70 98304.0',
    ]);
    expect((await db.listSnapshotsDao.load('view:70')).taskIds, [1, 100, 2]);
  });

  test('a refused position is a sync problem naming the reorder; the row '
      'keeps its place here until it is discarded', () async {
    write.refusedListViews[70] = const Forbidden();
    await queue(1, const TaskChanges(positions: {70: 200000}));

    await sender.drain();

    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.failure, isA<Forbidden>());
    expect(problem.changes, const TaskChanges(positions: {70: 200000}));
    var list = await db.tasksDao.loadProjectList(7, viewId: 70);
    expect(list.queuedPositions, {1: 200000.0});
    expect(list.snapshot.positions[1], 65536);

    await sender.discard(problem.operationId);

    list = await db.tasksDao.loadProjectList(7, viewId: 70);
    expect(list.queuedPositions, isEmpty);
    expect(list.snapshot.taskIds, [1, 2]);
    expect(await db.outboxDao.count(), 0);
  });
}
