import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

const _tempTask = NewTask(projectId: 5, title: 'Created here');

void main() {
  late AppDatabase db;
  const alice = User(id: 7, username: 'alice', name: 'Alice');
  const bob = User(id: 8, username: 'bob');
  const urgent = Label(id: 3, title: 'urgent', hexColor: 'e8323c');
  const later = Label(id: 4, title: 'later');
  final monday = DateTime.utc(2026, 10, 12, 9);
  final tuesday = DateTime.utc(2026, 10, 13, 9);

  setUp(() => db = testDatabase());

  Future<void> upsert(List<Task> tasks, {String run = 'run-1'}) =>
      db.tasksDao.upsertAll(tasks, syncRunId: run);

  group('hydration', () {
    test(
      'labels, assignees, reminders and users come back with the task',
      () async {
        final reminders = [
          TaskReminder(reminder: monday.subtract(const Duration(hours: 1))),
          const TaskReminder(
            relativePeriod: Duration(minutes: -30),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ];
        final task = Task(
          id: 1,
          title: 'Hydrated',
          projectId: 5,
          dueDate: monday,
          labels: const [urgent, later],
          assignees: const [bob, alice],
          reminders: reminders,
          createdBy: alice,
        );

        await upsert([task]);
        final found = await db.tasksDao.find(1);

        expect(found, task);
        expect(found!.labels, [urgent, later]);
        expect(found.assignees, [alice, bob]);
        expect(found.reminders, reminders);
        expect(found.createdBy, alice);
        expect(await db.usersDao.loadAll(), [alice, bob]);
        expect((await db.labelsDao.loadAll()).map((l) => l.id), [3, 4]);
      },
    );

    test('an upsert replaces the child rows', () async {
      await upsert([
        Task(
          id: 1,
          title: 'Before',
          projectId: 5,
          labels: const [urgent],
          assignees: const [alice],
          reminders: [TaskReminder(reminder: monday)],
        ),
      ]);

      await upsert([
        const Task(id: 1, title: 'After', projectId: 5, labels: [later]),
      ]);
      final found = (await db.tasksDao.find(1))!;

      expect(found.title, 'After');
      expect(found.labels, [later]);
      expect(found.assignees, isEmpty);
      expect(found.reminders, isEmpty);
    });

    test('an upsert clears fields that are null now', () async {
      await upsert([
        sampleTask(
          id: 1,
          title: 'Dated',
          due: monday,
          done: true,
          doneAt: monday,
        ),
      ]);

      await upsert([sampleTask(id: 1, title: 'Undated')]);
      final found = (await db.tasksDao.find(1))!;

      expect(found.dueDate, isNull);
      expect(found.doneAt, isNull);
      expect(found.done, isFalse);
    });

    test('relations are rebuilt only for tasks that are local', () async {
      const parent = Task(id: 10, title: 'Parent', projectId: 5);
      const child = Task(id: 11, title: 'Child', projectId: 5, done: true);
      const elsewhere = Task(id: 99, title: 'Not readable', projectId: 1);
      await upsert([
        const Task(
          id: 10,
          title: 'Parent',
          projectId: 5,
          relatedTasks: {
            TaskRelationKind.subtask: [child],
            TaskRelationKind.related: [elsewhere],
          },
        ),
        const Task(
          id: 11,
          title: 'Child',
          projectId: 5,
          done: true,
          labels: [urgent],
          relatedTasks: {
            TaskRelationKind.parentTask: [parent],
          },
        ),
      ]);

      final foundParent = (await db.tasksDao.find(10))!;
      final foundChild = (await db.tasksDao.find(11))!;

      expect(foundParent.subtasks, [child]);
      expect(foundParent.subtasks.single.done, isTrue);
      // The nested task is the row only: no labels or relations of its own.
      expect(foundParent.subtasks.single.labels, isEmpty);
      expect(foundParent.subtasks.single.relatedTasks, isEmpty);
      expect(
        foundParent.relatedTasks.containsKey(TaskRelationKind.related),
        isFalse,
      );
      expect(foundChild.parentTasks, [parent]);
      expect(foundChild.labels, [urgent]);
    });

    test('lists longer than one chunk are hydrated completely', () async {
      await upsert([
        for (var id = 1; id <= 1203; id++)
          Task(id: id, title: 'Task $id', projectId: 5, labels: const [urgent]),
      ]);

      final open = await db.tasksDao.loadOpenTasks();

      expect(open, hasLength(1203));
      expect(open.every((task) => task.labels.single == urgent), isTrue);
      expect(await db.tasksDao.count(), 1203);
    });
  });

  group('open tasks', () {
    test('are ordered by due date with undated last, newest first', () async {
      await upsert([
        sampleTask(id: 1, title: 'Undated old'),
        sampleTask(id: 2, title: 'Tuesday', due: tuesday),
        sampleTask(id: 3, title: 'Monday old', due: monday),
        sampleTask(id: 4, title: 'Done', due: monday, done: true),
        sampleTask(id: 5, title: 'Monday new', due: monday),
        sampleTask(id: 6, title: 'Undated new'),
      ]);

      final open = await db.tasksDao.loadOpenTasks();

      expect(open.map((t) => t.id), [5, 3, 2, 6, 1]);
    });

    test('the stream re-emits when tasks or their labels change', () async {
      final seen = <List<Task>>[];
      final subscription = db.tasksDao.watchOpenTasks().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen, [isEmpty]);

      await upsert([
        sampleTask(id: 1, title: 'One', labels: const [urgent]),
      ]);
      await pumpEventQueue();
      expect(seen.last.single.labels, [urgent]);

      await db.labelsDao.upsertAll(const [Label(id: 3, title: 'renamed')]);
      await pumpEventQueue();
      expect(seen.last.single.labels.single.title, 'renamed');

      await db.tasksDao.purgeNotInRun('other-run');
      await pumpEventQueue();
      expect(seen.last, isEmpty);
    });

    test('a load folds the changes that happen meanwhile into one', () async {
      final seen = <List<Task>>[];
      final subscription = db.tasksDao.watchOpenTasks().listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await Future.wait([
        upsert([sampleTask(id: 1, title: 'One')]),
        upsert([sampleTask(id: 2, title: 'Two')]),
        upsert([sampleTask(id: 3, title: 'Three')]),
      ]);
      await pumpEventQueue();

      expect(seen.last, hasLength(3));
      expect(seen.length, lessThanOrEqualTo(4));
    });
  });

  group('project tasks', () {
    setUp(
      () => upsert([
        sampleTask(id: 1, title: 'Open A', projectId: 5, position: 10),
        sampleTask(id: 2, title: 'Done', projectId: 5, done: true, position: 5),
        sampleTask(id: 3, title: 'Open B', projectId: 5, position: 10),
        sampleTask(id: 4, title: 'Other project', projectId: 6),
      ]),
    );

    test('without done tasks, by position then newest first', () async {
      final tasks = await db.tasksDao.loadProjectTasks(5, showDone: false);

      expect(tasks.map((t) => t.id), [3, 1]);
    });

    test('with done tasks', () async {
      final tasks = await db.tasksDao.loadProjectTasks(5, showDone: true);

      expect(tasks.map((t) => t.id), [2, 3, 1]);
    });

    test('the stream follows changes', () async {
      final seen = <List<Task>>[];
      final subscription = db.tasksDao
          .watchProjectTasks(5, showDone: false)
          .listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.single.map((t) => t.id), [3, 1]);

      await upsert([
        sampleTask(id: 3, title: 'Open B', projectId: 5, done: true),
      ]);
      await pumpEventQueue();

      expect(seen.last.map((t) => t.id), [1]);
    });
  });

  test('searchable tasks are every visible task, done ones included, newest '
      'first and without their child rows', () async {
    await upsert(const [
      Task(id: 1, title: 'Labelled', projectId: 5, labels: [urgent]),
      Task(id: 2, title: 'Done', projectId: 6, done: true),
      Task(
        id: 3,
        title: 'Related',
        projectId: 5,
        relatedTasks: {
          TaskRelationKind.related: [
            Task(id: 1, title: 'Labelled', projectId: 5),
          ],
        },
      ),
      Task(id: 4, title: 'Deleted here', projectId: 5),
    ]);
    await db.outboxDao.queueDelete(4, now: monday);
    await db.outboxDao.queueCreate(_tempTask, now: monday);

    final found = await db.tasksDao.watchSearchableTasks().first;

    expect([for (final task in found) task.id], [-1, 3, 2, 1]);
    expect(found.every((task) => task.labels.isEmpty), isTrue);
    expect(found.every((task) => task.relatedTasks.isEmpty), isTrue);
  });

  group('purge by run', () {
    test(
      'removes tasks another run or no run returned, with their rows',
      () async {
        await upsert([
          const Task(id: 1, title: 'Old', projectId: 5, labels: [urgent]),
        ]);
        await upsert([
          const Task(id: 2, title: 'Current', projectId: 5, labels: [later]),
        ], run: 'run-2');

        final purged = await db.tasksDao.purgeNotInRun('run-2');

        expect(purged, 1);
        expect(await db.tasksDao.find(1), isNull);
        expect((await db.tasksDao.find(2))!.labels, [later]);
        final labelRows = await db.select(db.taskLabels).get();
        expect(labelRows.map((r) => r.taskId), [2]);
      },
    );
  });

  group('per project', () {
    setUp(
      () => upsert([
        sampleTask(id: 1, title: 'A', projectId: 5, updated: monday),
        sampleTask(id: 2, title: 'B', projectId: 5, done: true),
        sampleTask(id: 3, title: 'C', projectId: 5, updated: tuesday),
        sampleTask(id: 4, title: 'D', projectId: 6, labels: const [urgent]),
      ]),
    );

    test('counts and lists ids, done tasks included', () async {
      expect(await db.tasksDao.countInProject(5), 3);
      expect(await db.tasksDao.countInProject(7), 0);
      expect(await db.tasksDao.idsInProject(5), [1, 2, 3]);
    });

    test('finds several by id, unknown ids left out', () async {
      final found = await db.tasksDao.findAll([1, 3, 99]);

      expect(found.keys, unorderedEquals([1, 3]));
      expect(found[3]!.title, 'C');
    });

    test('the newest updated can be bounded', () async {
      expect(await db.tasksDao.maxUpdated(notAfter: tuesday), tuesday);
      expect(await db.tasksDao.maxUpdated(notAfter: monday), monday);
      expect(
        await db.tasksDao.maxUpdated(
          notAfter: monday.subtract(const Duration(days: 1)),
        ),
        isNull,
      );
    });

    test('the newest updated ignores tasks without one', () async {
      expect(await db.tasksDao.maxUpdated(), tuesday);

      await db.tasksDao.purgeInProjects([5]);

      expect(await db.tasksDao.maxUpdated(), isNull);
    });

    test('purging a project takes its tasks and their rows', () async {
      expect(await db.tasksDao.purgeInProjects([5, 6]), 4);
      expect(await db.tasksDao.count(), 0);
      expect(await db.select(db.taskLabels).get(), isEmpty);
    });

    test('purging except keeps the given ids and other projects', () async {
      expect(await db.tasksDao.purgeInProjectExcept(5, {1, 3, 4}), 1);
      expect(await db.tasksDao.idsInProject(5), [1, 3]);
      expect(await db.tasksDao.idsInProject(6), [4]);
      expect(await db.tasksDao.purgeInProjectExcept(5, {1, 3}), 0);
    });
  });

  group('tasks created here', () {
    final now = DateTime.utc(2026, 10, 10, 12);

    Future<int> create(NewTask task) =>
        db.outboxDao.queueCreate(task, now: now);

    setUp(
      () => upsert([
        sampleTask(id: 1, title: 'Old', projectId: 5, updated: monday),
        sampleTask(id: 2, title: 'New', projectId: 5, due: monday),
        sampleTask(id: 3, title: 'Elsewhere', projectId: 6),
      ]),
    );

    test('come first in every list, the newest of them on top', () async {
      final first = await create(_tempTask);
      final second = await create(
        const NewTask(projectId: 5, title: 'Created later'),
      );
      final dated = await create(
        NewTask(projectId: 5, title: 'Created dated', dueDate: monday),
      );

      final open = await db.tasksDao.loadOpenTasks();
      final project = await db.tasksDao.loadProjectTasks(5, showDone: false);

      expect(open.map((t) => t.id), [dated, 2, second, first, 3, 1]);
      expect(project.map((t) => t.id), [dated, second, first, 2, 1]);
    });

    test('are left out of the counts, which mirror the server', () async {
      await create(_tempTask);

      expect(await db.tasksDao.count(), 3);
      expect(await db.tasksDao.countInProject(5), 2);
      expect(await db.tasksDao.countNotInProjects([6]), 2);
      expect(await db.tasksDao.maxUpdated(), monday);
    });

    test('are never purged', () async {
      final id = await create(_tempTask);

      await db.tasksDao.purgeNotInRun('other-run');
      await db.tasksDao.purgeInProjects([5]);
      await db.tasksDao.purgeInProjectExcept(5, {});

      expect((await db.tasksDao.find(id))!.title, 'Created here');
      expect(await db.tasksDao.count(), 0);
    });

    test('a watched task follows its remap and ends with null', () async {
      final id = await create(_tempTask);
      final seen = <Task?>[];
      final subscription = db.tasksDao.watchTask(id).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.single!.id, id);

      await db.outboxDao.queueUpdate(
        id,
        const TaskChanges(title: 'Renamed'),
        now: now,
      );
      await pumpEventQueue();
      expect(seen.last!.title, 'Renamed');

      final op = (await db.outboxDao.all()).single;
      await db.outboxDao.completeCreate(
        op.id,
        sampleTask(id: 50, title: 'Renamed', projectId: 5),
        at: now,
      );
      await pumpEventQueue();
      expect(seen.last!.id, 50);

      await upsert([
        sampleTask(id: 50, title: 'From the server', projectId: 5),
      ]);
      await pumpEventQueue();
      expect(seen.last!.title, 'From the server');

      await db.tasksDao.deleteRow(50);
      await pumpEventQueue();
      expect(seen.last, isNull);
    });

    test('a watched server task is just the row', () async {
      final seen = <Task?>[];
      final subscription = db.tasksDao.watchTask(2).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(seen.single!.title, 'New');

      await db.outboxDao.queueDelete(2, now: now);
      await pumpEventQueue();

      expect(seen.last, isNull);
    });
  });
}
