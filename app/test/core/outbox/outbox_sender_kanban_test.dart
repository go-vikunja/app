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

// The sender with kanban placements: they go through the task write port
// after the rest of the update, the downloaded board follows what the
// server accepted (no sync would), and a refusal is a sync problem that
// leaves the card in its server column once discarded.
void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  final now = DateTime.utc(2026, 10, 19, 12);
  final one = sampleTask(id: 1, title: 'One', projectId: 7);
  final two = sampleTask(id: 2, title: 'Two', projectId: 7);
  const todo = Bucket(id: 1, viewId: 80, title: 'To-Do', count: 2, position: 1);
  const doing = Bucket(
    id: 2,
    viewId: 80,
    title: 'Doing',
    limit: 1,
    position: 2,
  );
  const doneBucket = Bucket(id: 3, viewId: 80, title: 'Done', position: 3);

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = [one, two];
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 7,
        title: 'Work',
        views: [
          sampleKanbanView(
            id: 80,
            projectId: 7,
            defaultBucketId: 1,
            doneBucketId: 3,
          ),
        ],
      ),
    ]);
    await db.tasksDao.upsertAll([one, two], syncRunId: 'run');
    await db.kanbanDao.replaceBoard(
      80,
      buckets: const [todo, doing, doneBucket],
      slots: const {
        1: (bucketId: 1, position: 65536),
        2: (bucketId: 1, position: 131072),
      },
      loadedPages: const {},
      loadedAt: now,
    );
    write
      ..serverTasks.addAll({1: one, 2: two})
      ..kanbanViews[80] = (doneBucketId: 3, defaultBucketId: 1)
      ..bucketSlots[80] = {
        1: (bucketId: 1, position: 65536),
        2: (bucketId: 1, position: 131072),
      };
  });

  Future<void> place(int id, BucketPlacement placement, {bool? done}) async {
    expect(
      await db.outboxDao.queueUpdate(
        id,
        TaskChanges(done: done, kanban: {80: placement}),
        now: now,
      ),
      isTrue,
    );
  }

  test('a placement goes as the move, then the position, and the board '
      'follows', () async {
    await place(2, const BucketPlacement(bucketId: 2, position: 32768));

    await sender.drain();

    expect(write.requests, [
      'update 2',
      'move 2 view 80 bucket 2',
      'position 2 view 80 32768.0',
    ]);
    expect(write.bucketSlots[80]![2], (bucketId: 2, position: 32768.0));
    final board = await db.kanbanDao.load(80);
    expect(board.slots[2], (bucketId: 2, position: 32768.0));
    expect([for (final bucket in board.buckets) bucket.count], [1, 1, 0]);
    expect((await db.tasksDao.findRow(2))!.pendingChanges, isNull);
    expect(await db.outboxDao.count(), 0);
  });

  test(
    'a drop into the done bucket marks the task done there and here',
    () async {
      await place(
        1,
        const BucketPlacement(bucketId: 3, position: 65536),
        done: true,
      );

      await sender.drain();

      expect(write.serverTasks[1]!.done, isTrue);
      expect(write.bucketSlots[80]![1], (bucketId: 3, position: 65536.0));
      final task = (await db.tasksDao.find(1))!;
      expect(task.done, isTrue);
      expect((await db.kanbanDao.load(80)).slots[1]?.bucketId, 3);
    },
  );

  test('a placement queued behind a create goes once the server named the '
      'task, under its id', () async {
    final local = await db.outboxDao.queueCreate(
      const NewTask(projectId: 7, title: 'New'),
      now: now,
    );
    await place(local, const BucketPlacement(bucketId: 2, position: 16384));

    await sender.drain();

    expect(write.requests, [
      'create New',
      'update 100',
      'move 100 view 80 bucket 2',
      'position 100 view 80 16384.0',
    ]);
    expect((await db.kanbanDao.load(80)).slots[100], (
      bucketId: 2,
      position: 16384.0,
    ));
  });

  test('a full column refuses the move: a sync problem, the card stays '
      'placed here until it is discarded', () async {
    write.refusedBuckets[2] = const DomainError(412, code: 10004);
    await place(1, const BucketPlacement(bucketId: 2, position: 1));

    await sender.drain();

    final problem = (await db.outboxDao.loadProblems()).single;
    expect(
      problem.failure,
      isA<DomainError>().having((failure) => failure.code, 'code', 10004),
    );
    expect(problem.taskTitle, 'One');
    var source = await db.tasksDao.loadBoard(7, 80);
    expect(source.queued, {1: const BucketPlacement(bucketId: 2, position: 1)});
    expect(source.snapshot[1]?.bucketId, 1);

    await sender.discard(problem.operationId);

    source = await db.tasksDao.loadBoard(7, 80);
    expect(source.queued, isEmpty);
    expect(source.snapshot[1]?.bucketId, 1);
    expect(await db.outboxDao.count(), 0);
  });
}
