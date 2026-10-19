import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

void main() {
  late AppDatabase db;
  late RecordingSyncEngine sync;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  final now = DateTime.utc(2026, 10, 19, 12);
  final monday = DateTime.utc(2026, 10, 12, 9);
  final board = sampleKanbanView(
    id: 80,
    projectId: 7,
    defaultBucketId: 1,
    doneBucketId: 3,
  );
  const todo = Bucket(id: 1, viewId: 80, title: 'To-Do', position: 100);
  const doing = Bucket(id: 2, viewId: 80, title: 'Doing', position: 200);
  const doneBucket = Bucket(id: 3, viewId: 80, title: 'Done', position: 300);
  final tasks = [
    for (var id = 1; id <= 7; id++)
      sampleTask(id: id, title: 'Task $id', projectId: 7, done: id == 7),
  ];

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    repository = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      perPage: 2,
      now: () => now,
    );
    addTearDown(repository.dispose);
    final projects = [
      sampleProject(id: 7, title: 'Work', views: [board]),
    ];
    await db.projectsDao.upsertAll(projects);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    read
      ..allProjects = projects
      ..allTasks = tasks
      ..viewBuckets[80] = const [doneBucket, todo, doing]
      ..bucketSlots[80] = {
        1: (bucketId: 1, position: 10),
        2: (bucketId: 1, position: 20),
        3: (bucketId: 1, position: 30),
        4: (bucketId: 1, position: 40),
        5: (bucketId: 1, position: 50),
        6: (bucketId: 2, position: 5),
        7: (bucketId: 3, position: 1),
      };
  });

  List<int> counts(List<Bucket> buckets) => [
    for (final bucket in buckets) bucket.count,
  ];

  test('a refresh syncs, then stores the board: every bucket with its '
      'first page and count', () async {
    await repository.refreshBoard(7, 80);

    expect(sync.refreshCalls, 1);
    expect(read.requests, ['board project 7 view 80 per_page=2']);
    final source = await repository.watchBoard(7, 80).first;
    expect(source.view, board);
    expect([for (final b in source.buckets) b.id], [1, 2, 3]);
    expect(counts(source.buckets), [5, 1, 1]);
    expect(source.snapshot, {
      1: (bucketId: 1, position: 10.0),
      2: (bucketId: 1, position: 20.0),
      6: (bucketId: 2, position: 5.0),
      7: (bucketId: 3, position: 1.0),
    });
    expect(source.loadedAt, now);
    expect(
      [for (final task in source.projectTasks) task.id],
      [7, 6, 5, 4, 3, 2, 1],
      reason: 'the done task the board lists comes along',
    );
  });

  test('the board counts as loaded when its request went out, so what '
      'the server changes meanwhile is newer', () async {
    var clock = now;
    final timed = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      perPage: 2,
      now: () => clock,
    );
    addTearDown(timed.dispose);
    read.beforeRequest = (request) async {
      if (request.startsWith('board')) {
        clock = now.add(const Duration(minutes: 1));
      }
    };

    await timed.refreshBoard(7, 80);

    expect((await timed.watchBoard(7, 80).first).loadedAt, now);
  });

  test("the page size is the server's, at most 50 per bucket", () async {
    final wide = LocalTaskRepository(
      db,
      sync,
      sender,
      write,
      read: read,
      perPage: 250,
      now: () => now,
    );
    addTearDown(wide.dispose);

    await wide.refreshBoard(7, 80);

    expect(read.requests, ['board project 7 view 80 per_page=50']);
  });

  test('more of a bucket comes page by page, and a refresh downloads again '
      'every page loaded', () async {
    await repository.refreshBoard(7, 80);
    read.requests.clear();

    await repository.loadMoreOfBucket(7, 80, 1);
    await repository.loadMoreOfBucket(7, 80, 1);

    expect(sync.refreshCalls, 1, reason: 'loading more does not sync');
    expect(read.requests, [
      'bucket 1 of view 80 page 2 per_page=2',
      'bucket 1 of view 80 page 3 per_page=2',
    ]);
    var source = await repository.watchBoard(7, 80).first;
    expect([
      for (final MapEntry(:key, :value) in source.snapshot.entries)
        if (value.bucketId == 1) key,
    ], unorderedEquals([1, 2, 3, 4, 5]));

    read
      ..requests.clear()
      ..bucketSlots[80]![8] = (bucketId: 1, position: 1)
      ..allTasks = [...tasks, sampleTask(id: 8, title: 'Task 8', projectId: 7)];
    await repository.refreshBoard(7, 80);

    expect(read.requests, [
      'board project 7 view 80 per_page=2',
      'bucket 1 of view 80 page 2 per_page=2',
      'bucket 1 of view 80 page 3 per_page=2',
    ]);
    source = await repository.watchBoard(7, 80).first;
    expect(source.snapshot.keys, containsAll([8, 1, 2, 3, 4, 5]));
    expect(counts(source.buckets), [6, 1, 1]);
    expect(await db.kanbanDao.loadedPages(80), {1: 3, 2: 1, 3: 1});
  });

  test('a refresh stops at the pages a bucket still has', () async {
    await repository.refreshBoard(7, 80);
    await repository.loadMoreOfBucket(7, 80, 1);
    await repository.loadMoreOfBucket(7, 80, 1);
    read
      ..requests.clear()
      ..bucketSlots[80]!.removeWhere((id, slot) => id > 2 && id < 6);

    await repository.refreshBoard(7, 80);

    expect(read.requests, ['board project 7 view 80 per_page=2']);
    expect(await db.kanbanDao.loadedPages(80), {1: 1, 2: 1, 3: 1});
  });

  test('loading more of a board never downloaded does nothing', () async {
    await repository.loadMoreOfBucket(7, 80, 1);

    expect(read.requests, isEmpty);
  });

  test("the board's relative dates are rounded in the user's time zone "
      'setting', () async {
    await db.syncStateDao.write({
      SyncStateKeys.userSettings: encodeUserSettings(
        const UserSettings(timezone: 'Europe/Berlin'),
      ),
    });

    await repository.refreshBoard(7, 80);
    await repository.loadMoreOfBucket(7, 80, 1);

    expect(read.buckets.timezones, ['Europe/Berlin', 'Europe/Berlin']);
  });

  test('a failed sync or download passes through and keeps the previous '
      'board', () async {
    await db.kanbanDao.replaceBoard(
      80,
      buckets: const [todo],
      slots: const {1: (bucketId: 1, position: 1)},
      loadedPages: const {},
      loadedAt: monday,
    );

    sync.error = const ServerFailure(502);
    await expectLater(
      repository.refreshBoard(7, 80),
      throwsA(isA<ServerFailure>()),
    );
    expect(read.requests, isEmpty);

    sync.error = null;
    read.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    await expectLater(
      repository.refreshBoard(7, 80),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      repository.loadMoreOfBucket(7, 80, 1),
      throwsA(isA<NetworkFailure>()),
    );
    final source = await repository.watchBoard(7, 80).first;
    expect(source.loadedAt, monday);
    expect(source.snapshot, {1: (bucketId: 1, position: 1.0)});
  });

  test('placing a task queues the placement with the done change and the '
      'board shows it at once', () async {
    await repository.refreshBoard(7, 80);
    write.requests.clear();
    sender.pause();

    await repository.placeTask(
      2,
      viewId: 80,
      placement: const BucketPlacement(bucketId: 3, position: 0.5),
      done: true,
    );

    final row = (await db.tasksDao.findRow(2))!;
    expect(
      decodeTaskChanges(row.pendingChanges!),
      const TaskChanges(
        done: true,
        kanban: {80: BucketPlacement(bucketId: 3, position: 0.5)},
      ),
    );
    final source = await repository.watchBoard(7, 80).first;
    expect(source.queued, {
      2: const BucketPlacement(bucketId: 3, position: 0.5),
    });
    expect(source.projectTasks.firstWhere((task) => task.id == 2).done, isTrue);
    expect(write.requests, isEmpty);
  });

  test('undoing a drop into the done column drops the placement, whose '
      'move would mark the task done again', () async {
    await repository.refreshBoard(7, 80);
    sender.pause();
    await repository.placeTask(
      2,
      viewId: 80,
      placement: const BucketPlacement(bucketId: 3, position: 0.5),
      done: true,
    );

    await repository.undoDone((await db.tasksDao.find(2))!);

    final row = (await db.tasksDao.findRow(2))!;
    expect(
      decodeTaskChanges(row.pendingChanges!),
      const TaskChanges(done: false),
    );
    expect((await repository.watchBoard(7, 80).first).queued, isEmpty);
  });

  test('a task whose move into the project is not sent yet is marked as '
      'moved here', () async {
    await db.projectsDao.upsertAll([sampleProject(id: 8, title: 'Home')]);
    await db.tasksDao.upsertAll([
      sampleTask(id: 20, title: 'Elsewhere', projectId: 8, done: true),
    ], syncRunId: 'run');
    await repository.refreshBoard(7, 80);
    sender.pause();

    await repository.updateTask(20, const TaskChanges(projectId: 7));

    final source = await repository.watchBoard(7, 80).first;
    expect(source.movedHere, {20});
    expect(source.projectTasks.map((task) => task.id), contains(20));
  });

  test('the tasks whose done change is not sent yet are named, a title '
      'that reads "done" is not one', () async {
    await repository.refreshBoard(7, 80);
    sender.pause();

    await repository.updateTask(7, const TaskChanges(done: false));
    await repository.updateTask(1, const TaskChanges(title: 'done'));

    final source = await repository.watchBoard(7, 80).first;
    expect(source.queuedDoneChanges, {7});
    final reopened = buildBoard(
      view: board,
      buckets: source.buckets,
      snapshot: source.snapshot,
      loadedAt: source.loadedAt,
      projectTasks: source.projectTasks,
      queued: source.queued,
      queuedDoneChanges: source.queuedDoneChanges,
    ).firstWhere((column) => column.tasks.any((task) => task.id == 7));
    expect(reopened.bucket.id, todo.id);
  });
}
