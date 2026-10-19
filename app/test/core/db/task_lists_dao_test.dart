import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final monday = DateTime.utc(2026, 10, 12, 9);
  final tuesday = DateTime.utc(2026, 10, 13, 9);
  final now = DateTime.utc(2026, 10, 13, 12);

  setUp(() => db = testDatabase());

  Future<void> upsert(List<Task> tasks) =>
      db.tasksDao.upsertAll(tasks, syncRunId: 'run-1');

  Future<void> projects(List<Project> projects) =>
      db.projectsDao.upsertAll(projects);

  List<int> ids(Iterable<Task> tasks) => [for (final task in tasks) task.id];

  group('active open tasks', () {
    test('leave out archived projects and their subprojects, done and '
        'deleted tasks', () async {
      await projects([
        sampleProject(id: 1, title: 'Work'),
        sampleProject(id: 2, title: 'Old', archived: true),
        sampleProject(id: 3, title: 'Under old', parent: 2),
        sampleProject(id: 4, title: 'Under under old', parent: 3),
        sampleProject(id: 5, title: 'Under work', parent: 1),
      ]);
      await upsert([
        sampleTask(id: 10, title: 'Work'),
        sampleTask(id: 11, title: 'Archived', projectId: 2),
        sampleTask(id: 12, title: 'Archived child', projectId: 3),
        sampleTask(id: 13, title: 'Archived grandchild', projectId: 4),
        sampleTask(id: 14, title: 'Live child', projectId: 5),
        sampleTask(id: 15, title: 'Unknown project', projectId: 99),
        sampleTask(id: 16, title: 'Done', done: true),
        sampleTask(id: 17, title: 'Deleted'),
      ]);
      await db.outboxDao.queueDelete(17, now: now);

      expect(ids(await db.tasksDao.loadActiveOpenTasks()), [15, 14, 10]);
      expect(ids(await db.tasksDao.loadOpenTasks()), [15, 14, 13, 12, 11, 10]);
    });

    test('nearest due date first, none last, then newest first with a task '
        'created here on top', () async {
      await upsert([
        sampleTask(id: 1, title: 'Undated'),
        sampleTask(id: 2, title: 'Tuesday', due: tuesday),
        sampleTask(id: 3, title: 'Monday', due: monday),
        sampleTask(id: 4, title: 'Also Monday', due: monday),
        sampleTask(id: 5, title: 'Undated too'),
      ]);
      await db.outboxDao.queueCreate(
        const NewTask(projectId: 1, title: 'Here'),
        now: now,
      );

      expect(ids(await db.tasksDao.loadActiveOpenTasks()), [4, 3, 2, -1, 5, 1]);
    });

    test('follow a project being archived', () async {
      await projects([sampleProject(id: 1, title: 'Work')]);
      await upsert([sampleTask(id: 10, title: 'Work')]);
      final seen = <List<int>>[];
      final subscription = db.tasksDao.watchActiveOpenTasks().listen(
        (tasks) => seen.add(ids(tasks)),
      );
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await projects([sampleProject(id: 1, title: 'Work', archived: true)]);
      await pumpEventQueue();

      expect(seen, [
        [10],
        <int>[],
      ]);
    });
  });

  group('project list', () {
    test('holds the project tasks with the done ones and the subtasks they '
        'reach in any project, recursively', () async {
      await upsert([
        sampleTask(id: 1, title: 'Parent', projectId: 7, subtaskIds: [2, 3]),
        sampleTask(
          id: 2,
          title: 'Open child',
          projectId: 7,
          parentIds: [1],
          subtaskIds: [4],
        ),
        sampleTask(
          id: 3,
          title: 'Done child',
          projectId: 7,
          done: true,
          parentIds: [1],
        ),
        sampleTask(
          id: 4,
          title: 'Grandchild elsewhere',
          projectId: 8,
          parentIds: [2],
          subtaskIds: [5],
        ),
        sampleTask(
          id: 5,
          title: 'Great-grandchild elsewhere',
          projectId: 9,
          parentIds: [4],
        ),
        sampleTask(id: 6, title: 'Unrelated elsewhere', projectId: 8),
        sampleTask(id: 7, title: 'Deleted', projectId: 7),
      ]);
      await db.outboxDao.queueDelete(7, now: now);

      final list = await db.tasksDao.loadProjectList(7, viewId: 70);

      expect(ids(list.projectTasks), [3, 2, 1]);
      expect(list.tasksById.keys.toSet(), {1, 2, 3, 4, 5});
      expect(list.tasksById[4]!.projectId, 8);
      expect(ids(list.tasksById[2]!.subtasks), [4]);
      expect(list.snapshot.loadedAt, isNull);
      expect(list.snapshot.positions, isEmpty);
    });

    test('a subtask that is not here, or queued for deletion, is left '
        'out', () async {
      await upsert([
        sampleTask(id: 1, title: 'Parent', projectId: 7, subtaskIds: [2, 99]),
        sampleTask(id: 2, title: 'Child', projectId: 8, parentIds: [1]),
      ]);
      await db.outboxDao.queueDelete(2, now: now);

      final list = await db.tasksDao.loadProjectList(7, viewId: 70);

      expect(list.tasksById.keys, [1]);
    });

    test('a relation cycle ends', () async {
      await upsert([
        sampleTask(
          id: 1,
          title: 'A',
          projectId: 7,
          subtaskIds: [2],
          parentIds: [3],
        ),
        sampleTask(
          id: 2,
          title: 'B',
          projectId: 8,
          subtaskIds: [3],
          parentIds: [1],
        ),
        sampleTask(
          id: 3,
          title: 'C',
          projectId: 9,
          subtaskIds: [1],
          parentIds: [2],
        ),
      ]);

      final list = await db.tasksDao.loadProjectList(7, viewId: 70);

      expect(list.tasksById.keys.toSet(), {1, 2, 3});
    });

    test(
      'without the done tasks keeps the open ones, the done ones of the '
      "view's download and every subtask, and says it left some out",
      () async {
        await upsert([
          sampleTask(
            id: 1,
            title: 'Open parent',
            projectId: 7,
            subtaskIds: [2],
          ),
          sampleTask(
            id: 2,
            title: 'Done child',
            projectId: 7,
            parentIds: [1],
            done: true,
          ),
          sampleTask(
            id: 3,
            title: 'Done, downloaded',
            projectId: 7,
            done: true,
          ),
          sampleTask(id: 4, title: 'Done long ago', projectId: 7, done: true),
          sampleTask(id: 5, title: 'Open', projectId: 7),
        ]);
        await db.listSnapshotsDao.replace('view:70', {
          3: 1,
          5: 2,
        }, loadedAt: now);

        final list = await db.tasksDao.loadProjectList(
          7,
          viewId: 70,
          includeDone: false,
        );

        expect(ids(list.projectTasks), [5, 3, 1]);
        expect(list.tasksById.keys.toSet(), {1, 2, 3, 5});
        expect(list.omitsDoneTasks, isTrue);

        final all = await db.tasksDao.loadProjectList(7, viewId: 70);
        expect(ids(all.projectTasks), [5, 4, 3, 2, 1]);
        expect(all.omitsDoneTasks, isFalse);

        await db.outboxDao.queueDelete(4, now: now);
        await db.outboxDao.queueDelete(2, now: now);
        final rest = await db.tasksDao.loadProjectList(
          7,
          viewId: 70,
          includeDone: false,
        );
        expect(rest.omitsDoneTasks, isFalse);
      },
    );

    test('carries the view snapshot and follows its replacement', () async {
      await upsert([sampleTask(id: 1, title: 'Task', projectId: 7)]);
      final seen = <ListSnapshot>[];
      final subscription = db.tasksDao
          .watchProjectList(7, viewId: 70)
          .listen((list) => seen.add(list.snapshot));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.listSnapshotsDao.replace('view:70', {
        1: 2.5,
        42: 1,
      }, loadedAt: now);
      await db.listSnapshotsDao.replace('view:71', {1: 9}, loadedAt: now);
      await pumpEventQueue();

      expect(seen.first.loadedAt, isNull);
      expect(seen.last.positions, {1: 2.5, 42: 1});
      expect(seen.last.loadedAt, now);
    });

    test("carries the view's unsent positions and follows the queue", () async {
      await upsert([
        sampleTask(id: 1, title: 'Moved', projectId: 7),
        sampleTask(id: 2, title: 'Moved elsewhere', projectId: 7),
        sampleTask(id: 3, title: 'Deleted', projectId: 7),
      ]);
      final seen = <Map<int, double>>[];
      final subscription = db.tasksDao
          .watchProjectList(7, viewId: 70)
          .listen((list) => seen.add(list.queuedPositions));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(positions: {70: 1.5, 71: 9}),
        now: now,
      );
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(positions: {71: 4}),
        now: now,
      );
      await db.outboxDao.queueUpdate(
        3,
        const TaskChanges(positions: {70: 3}),
        now: now,
      );
      await db.outboxDao.queueDelete(3, now: now);
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Renamed'),
        now: now,
      );
      await pumpEventQueue();
      expect(seen.last, {1: 1.5});

      final op = (await db.outboxDao.all()).first;
      await db.outboxDao.remove(op.id);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      expect(seen.first, isEmpty);
    });

    test('a project without a list view has no queued positions', () async {
      await upsert([sampleTask(id: 1, title: 'Task', projectId: 7)]);
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(positions: {0: 1}),
        now: now,
      );

      final list = await db.tasksDao.loadProjectList(7, viewId: 0);

      expect(list.queuedPositions, isEmpty);
    });
  });

  group('relations', () {
    test('come back in the order the server sent them', () async {
      await upsert([
        sampleTask(
          id: 1,
          title: 'Parent',
          projectId: 7,
          subtaskIds: [30, 10, 20],
        ),
        sampleTask(id: 10, title: 'B', projectId: 7, parentIds: [1]),
        sampleTask(id: 20, title: 'C', projectId: 7, parentIds: [1]),
        sampleTask(id: 30, title: 'A', projectId: 7, parentIds: [1]),
      ]);

      expect(ids((await db.tasksDao.find(1))!.subtasks), [30, 10, 20]);
    });

    test('keep their order when the subtasks are pulled again on their '
        'own', () async {
      await upsert([
        sampleTask(
          id: 1,
          title: 'Parent',
          projectId: 7,
          subtaskIds: [30, 10, 20],
        ),
      ]);
      await upsert([
        sampleTask(id: 10, title: 'B', projectId: 7, parentIds: [1]),
        sampleTask(id: 20, title: 'C', projectId: 7, parentIds: [1]),
        sampleTask(id: 30, title: 'A', projectId: 7, parentIds: [1]),
      ]);
      await upsert([sampleTask(id: 10, title: 'B again', projectId: 7)]);

      expect(ids((await db.tasksDao.find(1))!.subtasks), [30, 20]);

      await upsert([
        sampleTask(id: 10, title: 'B back', projectId: 7, parentIds: [1]),
      ]);

      expect(ids((await db.tasksDao.find(1))!.subtasks), [30, 20, 10]);
      expect(ids((await db.tasksDao.find(30))!.parentTasks), [1]);
    });
  });

  group('open tasks of a list', () {
    test('are the open, visible tasks of its snapshot by due date', () async {
      await upsert([
        sampleTask(id: 1, title: 'Undated'),
        sampleTask(id: 2, title: 'Tuesday', due: tuesday),
        sampleTask(id: 3, title: 'Monday', due: monday),
        sampleTask(id: 4, title: 'Done', done: true),
        sampleTask(id: 5, title: 'Deleted'),
        sampleTask(id: 6, title: 'Not listed'),
      ]);
      await db.outboxDao.queueDelete(5, now: now);
      await db.listSnapshotsDao.replace('overview:-14', {
        2: 0,
        3: 1,
        1: 2,
        4: 3,
        5: 4,
        77: 5,
      }, loadedAt: now);

      final list = await db.tasksDao.loadOpenTasksInList('overview:-14');

      expect(ids(list.tasks), [3, 2, 1]);
      expect(list.loadedAt, now);
    });

    test('a list never downloaded is empty without a time', () async {
      await upsert([sampleTask(id: 1, title: 'Task')]);

      final list = await db.tasksDao.loadOpenTasksInList('overview:-14');

      expect(list.tasks, isEmpty);
      expect(list.loadedAt, isNull);
    });

    test('a task done here leaves at once', () async {
      await upsert([sampleTask(id: 1, title: 'Task')]);
      await db.listSnapshotsDao.replace('overview:-14', {1: 0}, loadedAt: now);
      final seen = <List<int>>[];
      final subscription = db.tasksDao
          .watchOpenTasksInList('overview:-14')
          .listen((list) => seen.add(ids(list.tasks)));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(done: true),
        now: now,
      );
      await pumpEventQueue();

      expect(seen, [
        [1],
        <int>[],
      ]);
    });
  });

  group('snapshots', () {
    test('sent positions go into the downloaded views only', () async {
      await db.listSnapshotsDao.replace('view:70', {
        1: 1,
        2: 2,
      }, loadedAt: monday);

      await db.listSnapshotsDao.applySentPositions(1, {70: 3, 71: 5});
      await db.listSnapshotsDao.applySentPositions(9, {70: 0.5});

      final snapshot = await db.listSnapshotsDao.load('view:70');
      expect(snapshot.positions, {9: 0.5, 2: 2, 1: 3});
      expect(snapshot.taskIds, [9, 2, 1]);
      expect(snapshot.loadedAt, monday);
      expect((await db.listSnapshotsDao.load('view:71')).loadedAt, isNull);
    });

    test("a sent position keeps a board card's bucket", () async {
      await db.kanbanDao.replaceBoard(
        80,
        buckets: const [Bucket(id: 5, viewId: 80, title: 'To-Do', position: 1)],
        slots: {1: (bucketId: 5, position: 1)},
        loadedPages: const {},
        loadedAt: monday,
      );

      await db.listSnapshotsDao.applySentPositions(1, {80: 7});

      expect((await db.kanbanDao.load(80)).slots, {
        1: (bucketId: 5, position: 7.0),
      });
    });

    test('a replacement drops the tasks of the previous download', () async {
      await db.listSnapshotsDao.replace('view:70', {
        1: 1,
        2: 2,
      }, loadedAt: monday);
      await db.listSnapshotsDao.replace('view:70', {3: 0.5}, loadedAt: tuesday);

      final snapshot = await db.listSnapshotsDao.load('view:70');

      expect(snapshot.positions, {3: 0.5});
      expect(snapshot.loadedAt, tuesday);
    });

    test('a watcher sees each download of its list', () async {
      final seen = <ListSnapshot>[];
      final subscription = db.listSnapshotsDao
          .watch('view:70')
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.listSnapshotsDao.replace('view:70', {
        2: 1,
        1: 2,
      }, loadedAt: monday);
      await pumpEventQueue();

      expect(seen.first.loadedAt, isNull);
      expect(seen.last.taskIds, [2, 1]);
      expect(seen.last.loadedAt, monday);
    });

    test('an empty download still counts as downloaded', () async {
      await db.listSnapshotsDao.replace('view:70', {}, loadedAt: monday);

      final snapshot = await db.listSnapshotsDao.load('view:70');

      expect(snapshot.positions, isEmpty);
      expect(snapshot.loadedAt, monday);
    });

    test('a large download is stored whole', () async {
      final positions = {for (var id = 1; id <= 1200; id++) id: id * 1.5};

      await db.listSnapshotsDao.replace('view:70', positions, loadedAt: now);

      expect((await db.listSnapshotsDao.load('view:70')).positions, positions);
    });

    test(
      'removing by prefix keeps the one asked for and other kinds',
      () async {
        for (final key in ['overview:-2', 'overview:-14', 'view:70', 'over']) {
          await db.listSnapshotsDao.replace(key, {1: 1}, loadedAt: now);
        }

        await db.listSnapshotsDao.removeAll(
          'overview:',
          keep: {'overview:-14'},
        );

        expect(
          (await db.listSnapshotsDao.load('overview:-2')).loadedAt,
          isNull,
        );
        expect((await db.listSnapshotsDao.load('overview:-14')).loadedAt, now);
        expect((await db.listSnapshotsDao.load('view:70')).loadedAt, now);
        expect((await db.listSnapshotsDao.load('over')).loadedAt, now);

        await db.listSnapshotsDao.removeAll('overview:');

        expect(
          (await db.listSnapshotsDao.load('overview:-14')).loadedAt,
          isNull,
        );
        expect(
          (await db.listSnapshotsDao.load('overview:-14')).positions,
          isEmpty,
        );
      },
    );

    test('removing by prefix can keep several', () async {
      for (final key in ['filter:-2', 'filter:-3', 'filter:-14', 'view:70']) {
        await db.listSnapshotsDao.replace(key, {1: 1}, loadedAt: now);
      }

      await db.listSnapshotsDao.removeAll(
        'filter:',
        keep: {'filter:-2', 'filter:-14', 'filter:-99'},
      );

      Future<DateTime?> loaded(String key) async =>
          (await db.listSnapshotsDao.load(key)).loadedAt;
      expect(await loaded('filter:-2'), now);
      expect(await loaded('filter:-3'), isNull);
      expect(await loaded('filter:-14'), now);
      expect(await loaded('view:70'), now);
    });
  });
}
