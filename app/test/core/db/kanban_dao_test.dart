import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final monday = DateTime.utc(2026, 10, 12, 9);
  final now = DateTime.utc(2026, 10, 19, 12);
  final later = DateTime.utc(2026, 10, 19, 13);
  final board = sampleKanbanView(
    id: 80,
    projectId: 7,
    defaultBucketId: 1,
    doneBucketId: 3,
  );
  const todo = Bucket(
    id: 1,
    viewId: 80,
    title: 'To-Do',
    count: 2,
    position: 100,
  );
  const doing = Bucket(
    id: 2,
    viewId: 80,
    title: 'Doing',
    limit: 3,
    count: 1,
    position: 200,
  );
  const doneBucket = Bucket(
    id: 3,
    viewId: 80,
    title: 'Done',
    count: 1,
    position: 300,
  );

  setUp(() async {
    db = testDatabase();
    await db.projectsDao.upsertAll([
      sampleProject(
        id: 7,
        title: 'Work',
        views: [sampleListView(id: 70, projectId: 7), board],
      ),
    ]);
  });

  Future<void> download({
    List<Bucket> buckets = const [doneBucket, todo, doing],
    Map<int, BoardSlot> slots = const {
      1: (bucketId: 1, position: 65536),
      2: (bucketId: 1, position: 131072),
      3: (bucketId: 2, position: 32768),
      4: (bucketId: 3, position: 65536),
    },
    Map<int, int> loadedPages = const {},
    DateTime? at,
  }) => db.kanbanDao.replaceBoard(
    80,
    buckets: buckets,
    slots: slots,
    loadedPages: loadedPages,
    loadedAt: at ?? now,
  );

  group('the board download', () {
    test('stores the buckets in position order and the cards with their '
        "bucket in the view's snapshot", () async {
      await download(loadedPages: {2: 3});

      final stored = await db.kanbanDao.load(80);
      expect(stored.buckets, [todo, doing, doneBucket]);
      expect(stored.slots, {
        1: (bucketId: 1, position: 65536.0),
        2: (bucketId: 1, position: 131072.0),
        3: (bucketId: 2, position: 32768.0),
        4: (bucketId: 3, position: 65536.0),
      });
      expect(stored.loadedAt, now);
      expect(await db.kanbanDao.loadedPages(80), {1: 1, 2: 3, 3: 1});
      expect(
        (await db.listSnapshotsDao.load('view:80')).positions.keys,
        containsAll([1, 2, 3, 4]),
      );
    });

    test('a board never downloaded is empty', () async {
      final stored = await db.kanbanDao.load(80);
      expect(stored.buckets, isEmpty);
      expect(stored.slots, isEmpty);
      expect(stored.loadedAt, isNull);
    });

    test('a new download replaces the buckets and cards as a whole', () async {
      await download();
      await download(
        buckets: const [todo],
        slots: const {2: (bucketId: 1, position: 5)},
        at: later,
      );

      final stored = await db.kanbanDao.load(80);
      expect(stored.buckets, [todo]);
      expect(stored.slots, {2: (bucketId: 1, position: 5.0)});
      expect(stored.loadedAt, later);
    });

    test('a list snapshot of another view is not a board', () async {
      await db.listSnapshotsDao.replace('view:70', {1: 1}, loadedAt: now);

      expect((await db.kanbanDao.load(70)).slots, isEmpty);
      expect((await db.listSnapshotsDao.load('view:70')).positions, {1: 1});
    });
  });

  group('a further page of a bucket', () {
    test("adds its cards to the bucket, takes the server's count and "
        'counts the page; a card it takes from another bucket leaves that '
        "bucket's count", () async {
      await download();

      final appended = await db.kanbanDao.appendToBucket(
        80,
        1,
        positions: {5: 262144, 3: 196608},
        loadedPages: 2,
        count: 4,
      );

      expect(appended, isTrue);
      final stored = await db.kanbanDao.load(80);
      expect(stored.slots[5], (bucketId: 1, position: 262144.0));
      expect(stored.slots[3], (
        bucketId: 1,
        position: 196608.0,
      ), reason: "the page is newer than the card's place in Doing");
      expect([for (final b in stored.buckets) b.count], [4, 0, 1]);
      expect(await db.kanbanDao.loadedPages(80), {1: 2, 2: 1, 3: 1});
      expect(stored.loadedAt, now);
    });

    test('keeps the count when the page has none (v1)', () async {
      await download();

      await db.kanbanDao.appendToBucket(
        80,
        2,
        positions: {6: 1},
        loadedPages: 2,
      );

      expect((await db.kanbanDao.load(80)).buckets[1].count, 1);
    });

    test('after the last page the bucket counts the cards it holds, so '
        'a card listed in two buckets cannot keep it wanting more', () async {
      await download(
        buckets: const [
          Bucket(id: 1, viewId: 80, title: 'Mine', count: 3, position: 0),
          Bucket(id: 2, viewId: 80, title: 'Urgent', count: 2, position: 1),
        ],
        slots: const {
          1: (bucketId: 1, position: 1),
          2: (bucketId: 1, position: 2),
          3: (bucketId: 2, position: 1),
        },
      );

      await db.kanbanDao.appendToBucket(
        80,
        2,
        positions: const {},
        loadedPages: 2,
        count: 2,
        last: true,
      );

      expect(
        [for (final b in (await db.kanbanDao.load(80)).buckets) b.count],
        [3, 1],
      );
    });

    test('of a bucket the board no longer has writes nothing', () async {
      await download();

      expect(
        await db.kanbanDao.appendToBucket(
          80,
          9,
          positions: {6: 1},
          loadedPages: 2,
        ),
        isFalse,
      );
      expect((await db.kanbanDao.load(80)).slots, isNot(contains(6)));
    });
  });

  group('a placement the server accepted', () {
    test('moves the card and its count to the other bucket', () async {
      await download();

      await db.kanbanDao.applySentPlacements(1, {
        80: const BucketPlacement(bucketId: 2, position: 16384),
      });

      final stored = await db.kanbanDao.load(80);
      expect(stored.slots[1], (bucketId: 2, position: 16384.0));
      expect([for (final b in stored.buckets) b.count], [1, 2, 1]);
    });

    test('within its bucket only reorders the card', () async {
      await download();

      await db.kanbanDao.applySentPlacements(2, {
        80: const BucketPlacement(bucketId: 1, position: 1),
      });

      final stored = await db.kanbanDao.load(80);
      expect(stored.slots[2], (bucketId: 1, position: 1.0));
      expect([for (final b in stored.buckets) b.count], [2, 1, 1]);
    });

    test("without a position keeps the card's, and a card new to the board "
        'goes on top of its bucket', () async {
      await download();

      await db.kanbanDao.applySentPlacements(4, {
        80: const BucketPlacement(bucketId: 1),
      });
      await db.kanbanDao.applySentPlacements(9, {
        80: const BucketPlacement(bucketId: 1),
      });

      final stored = await db.kanbanDao.load(80);
      expect(stored.slots[4], (bucketId: 1, position: 65536.0));
      expect(stored.slots[9], (bucketId: 1, position: 32768.0));
      expect([for (final b in stored.buckets) b.count], [4, 1, 0]);
    });

    test('on a board never downloaded, or into a bucket it lacks, changes '
        'nothing', () async {
      await db.kanbanDao.applySentPlacements(1, {
        80: const BucketPlacement(bucketId: 2, position: 1),
      });
      expect((await db.kanbanDao.load(80)).slots, isEmpty);

      await download();
      await db.kanbanDao.applySentPlacements(1, {
        80: const BucketPlacement(bucketId: 9, position: 1),
        81: const BucketPlacement(bucketId: 2, position: 1),
      });
      expect((await db.kanbanDao.load(80)).slots[1], (
        bucketId: 1,
        position: 65536.0,
      ));
    });
  });

  test('the boards and snapshots of views that are gone are removed', () async {
    await download();
    await db.listSnapshotsDao.replace('view:70', {1: 1}, loadedAt: now);
    await db.listSnapshotsDao.replace('view:99', {1: 1}, loadedAt: now);
    await db.listSnapshotsDao.replace('project:7', {1: 1}, loadedAt: now);
    await db.listSnapshotsDao.replace('filter:-2', {1: 1}, loadedAt: now);

    await db.kanbanDao.removeGoneViews();
    expect((await db.kanbanDao.load(80)).buckets, hasLength(3));
    expect((await db.listSnapshotsDao.load('view:99')).loadedAt, isNull);

    await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    await db.kanbanDao.removeGoneViews();

    final stored = await db.kanbanDao.load(80);
    expect(stored.buckets, isEmpty);
    expect(stored.loadedAt, isNull);
    expect((await db.listSnapshotsDao.load('view:70')).loadedAt, isNull);
    expect((await db.listSnapshotsDao.load('project:7')).loadedAt, now);
    expect((await db.listSnapshotsDao.load('filter:-2')).loadedAt, now);
  });

  group('the board source', () {
    final old = DateTime.utc(2026, 10, 2);
    setUp(() async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Listed', projectId: 7, updated: old),
        sampleTask(id: 2, title: 'Open', projectId: 7, updated: old),
        sampleTask(
          id: 4,
          title: 'Done, listed',
          projectId: 7,
          done: true,
          updated: old,
        ),
        sampleTask(
          id: 5,
          title: 'Done long ago',
          projectId: 7,
          done: true,
          updated: old,
          created: old,
        ),
        sampleTask(
          id: 6,
          title: 'Done since the download',
          projectId: 7,
          done: true,
          created: old,
          updated: later,
        ),
        sampleTask(id: 8, title: 'Elsewhere', projectId: 8, due: monday),
      ], syncRunId: 'run');
    });

    List<int> ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

    test('holds the view, the download and the tasks the board can show, '
        'newest first', () async {
      await download();

      final source = await db.tasksDao.loadBoard(7, 80);

      expect(source.view, board);
      expect(source.view?.doneBucketId, 3);
      expect(source.buckets, [todo, doing, doneBucket]);
      expect(source.snapshot[4], (bucketId: 3, position: 65536.0));
      expect(source.loadedAt, now);
      expect(ids(source.projectTasks), [6, 4, 2, 1]);
      expect(source.queued, isEmpty);
    });

    test('without a download only the open tasks come', () async {
      final source = await db.tasksDao.loadBoard(7, 80);

      expect(source.loadedAt, isNull);
      expect(source.buckets, isEmpty);
      expect(ids(source.projectTasks), [2, 1]);
    });

    test('a task created here and the placements queued for the view come '
        'along', () async {
      await download();
      final local = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: old,
      );
      await db.outboxDao.queueUpdate(
        local,
        const TaskChanges(
          done: true,
          kanban: {80: BucketPlacement(bucketId: 3, position: 32768)},
        ),
        now: old,
      );
      await db.outboxDao.queueUpdate(
        5,
        const TaskChanges(
          kanban: {
            80: BucketPlacement(bucketId: 2),
            81: BucketPlacement(bucketId: 9),
          },
        ),
        now: old,
      );
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(isFavorite: true),
        now: old,
      );

      final source = await db.tasksDao.loadBoard(7, 80);

      expect(ids(source.projectTasks), [local, 6, 5, 4, 2, 1]);
      expect(source.queued, {
        local: const BucketPlacement(bucketId: 3, position: 32768),
        5: const BucketPlacement(bucketId: 2),
      });
    });

    test('a task queued for deletion is gone', () async {
      await download();
      await db.outboxDao.queueDelete(1, now: now);

      expect(ids((await db.tasksDao.loadBoard(7, 80)).projectTasks), [6, 4, 2]);
    });

    test('follows a download, a placement and a done here', () async {
      final seen = <BoardSource>[];
      final subscription = db.tasksDao.watchBoard(7, 80).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.last.loadedAt, isNull);

      await download();
      await pumpEventQueue();
      expect(seen.last.loadedAt, now);

      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(kanban: {80: BucketPlacement(bucketId: 2)}),
        now: now,
      );
      await pumpEventQueue();
      expect(seen.last.queued, {2: const BucketPlacement(bucketId: 2)});

      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: now,
      );
      await pumpEventQueue();
      expect(
        seen.last.projectTasks.firstWhere((task) => task.id == 1).done,
        isTrue,
      );
    });
  });
}
