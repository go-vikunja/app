import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

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

    test(
      "a project's progress counts its own tasks and the done ones",
      () async {
        expect(await db.tasksDao.watchProjectProgress(5).first, (
          done: 1,
          total: 3,
        ));
        expect(await db.tasksDao.watchProjectProgress(7).first, (
          done: 0,
          total: 0,
        ));
      },
    );

    test('the open tasks are counted per project', () async {
      expect(await db.tasksDao.watchOpenTaskCounts().first, {5: 2, 6: 1});
    });

    test('the counts and the progress follow only writes that change them, '
        'not every write to the tasks', () async {
      final counts = <Map<int, int>>[];
      final progress = <ProjectProgress>[];
      final subscriptions = [
        db.tasksDao.watchOpenTaskCounts().listen(counts.add),
        db.tasksDao.watchProjectProgress(5).listen(progress.add),
      ];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      });
      await pumpEventQueue();

      await upsert([sampleTask(id: 1, title: 'A renamed', projectId: 5)]);
      await pumpEventQueue();
      expect(counts, [
        {5: 2, 6: 1},
      ]);
      expect(progress, [(done: 1, total: 3)]);

      await upsert([sampleTask(id: 1, title: 'A', projectId: 5, done: true)]);
      await pumpEventQueue();
      expect(counts.last, {5: 1, 6: 1});
      expect(progress.last, (done: 2, total: 3));
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
      final project = await projectTasksIn(db, 5, showDone: false);

      expect(open.map((t) => t.id), [dated, 2, second, first, 3, 1]);
      expect(project.map((t) => t.id), [dated, second, first, 2, 1]);
    });

    test('count in the progress and the open tasks, unlike a task queued '
        'for deletion', () async {
      await create(_tempTask);
      await db.outboxDao.queueDelete(2, now: now);

      expect(await db.tasksDao.watchProjectProgress(5).first, (
        done: 0,
        total: 2,
      ));
      expect(await db.tasksDao.watchOpenTaskCounts().first, {5: 2, 6: 1});
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

  group('comment count and unread flag', () {
    test('a sync takes them, any other upsert keeps the stored ones, a new '
        'row starts without', () async {
      await db.tasksDao.upsertAll(
        [
          sampleTask(
            id: 1,
            title: 'Talked about',
            commentCount: 3,
            isUnread: true,
          ),
        ],
        syncRunId: 'run-1',
        withCommentState: true,
      );
      expect((await db.tasksDao.find(1))!.commentCount, 3);
      expect((await db.tasksDao.find(1))!.isUnread, isTrue);

      // A write's answer or a task read on its own carries neither.
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'Renamed'),
        sampleTask(id: 2, title: 'Fresh'),
      ]);
      final renamed = (await db.tasksDao.find(1))!;
      expect(renamed.title, 'Renamed');
      expect(renamed.commentCount, 3);
      expect(renamed.isUnread, isTrue);
      final fresh = (await db.tasksDao.find(2))!;
      expect(fresh.commentCount, 0);
      expect(fresh.isUnread, isFalse);

      await db.tasksDao.upsertAll(
        [sampleTask(id: 1, title: 'Renamed', commentCount: 4)],
        syncRunId: 'run-2',
        withCommentState: true,
      );
      final read = (await db.tasksDao.find(1))!;
      expect(read.commentCount, 4);
      expect(read.isUnread, isFalse, reason: 'read on the web meanwhile');
    });

    test('a queued change keeps its fields while a sync brings the comment '
        'state', () async {
      await upsert([sampleTask(id: 1, title: 'Before')]);
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Mine'),
        now: monday,
      );

      await db.tasksDao.upsertAll(
        [sampleTask(id: 1, title: 'Theirs', commentCount: 2, isUnread: true)],
        syncRunId: 'run-2',
        withCommentState: true,
      );

      final task = (await db.tasksDao.find(1))!;
      expect(task.title, 'Mine');
      expect(task.commentCount, 2);
      expect(task.isUnread, isTrue);
    });

    test('stored on their own, written only when they differ', () async {
      await upsert([sampleTask(id: 1, title: 'Talked about')]);
      final seen = <Task?>[];
      final subscription = db.tasksDao.watchTask(1).listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await db.tasksDao.storeCommentState(1, commentCount: 2, isUnread: true);
      await pumpEventQueue();
      await db.tasksDao.storeCommentState(1, commentCount: 2, isUnread: true);
      await db.tasksDao.storeCommentState(1, isUnread: true);
      await db.tasksDao.storeCommentState(1);
      await pumpEventQueue();
      await db.tasksDao.storeCommentState(1, isUnread: false);
      await pumpEventQueue();
      await db.tasksDao.storeCommentState(99, commentCount: 1);

      expect(seen.map((task) => (task!.commentCount, task.isUnread)), [
        (0, false),
        (2, true),
        (2, false),
      ]);
    });

    test('the count moves by a delta and never below 0', () async {
      await upsert([sampleTask(id: 1, title: 'Talked about')]);

      await db.tasksDao.addToCommentCount(1, 1);
      await db.tasksDao.addToCommentCount(1, 1);
      expect((await db.tasksDao.find(1))!.commentCount, 2);
      await db.tasksDao.addToCommentCount(1, -3);
      expect((await db.tasksDao.find(1))!.commentCount, 0);
      await db.tasksDao.addToCommentCount(99, 1);
    });
  });

  group("the user's own subscription", () {
    const followed = 5;
    const unfollowed = 6;
    const own = Subscription(entity: SubscriptionEntity.task, entityId: 1);
    const inherited = Subscription(
      entity: SubscriptionEntity.project,
      entityId: followed,
    );

    setUp(() async {
      await db.projectsDao.upsertAll([
        sampleProject(
          id: followed,
          title: 'Followed',
        ).copyWith(subscription: inherited),
        sampleProject(id: unfollowed, title: 'Not followed'),
      ]);
    });

    test('a read is judged with the stored project and assignees', () async {
      await upsert([
        sampleTask(id: 1, title: 'Own row', projectId: unfollowed),
        sampleTask(id: 2, title: 'Through the project', projectId: followed),
        sampleTask(
          id: 3,
          title: 'Through the project, assigned',
          projectId: followed,
          assignees: const [alice],
        ),
        sampleTask(id: 4, title: 'Opted out', projectId: followed),
        sampleTask(
          id: 5,
          title: 'Nothing, assigned to bob',
          projectId: unfollowed,
          assignees: const [bob],
        ),
        sampleTask(
          id: 6,
          title: 'Nothing, assigned',
          projectId: unfollowed,
          assignees: const [alice],
        ),
      ]);

      final dao = db.tasksDao;
      await dao.storeOwnSubscription(1, own, userId: alice.id);
      await dao.storeOwnSubscription(2, inherited, userId: alice.id);
      await dao.storeOwnSubscription(3, inherited, userId: alice.id);
      await dao.storeOwnSubscription(4, null, userId: alice.id);
      await dao.storeOwnSubscription(5, null, userId: alice.id);
      await dao.storeOwnSubscription(6, null, userId: alice.id);

      expect(await dao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
        2: OwnTaskSubscription.none,
        3: OwnTaskSubscription.noneWhileAssigned,
        4: OwnTaskSubscription.optedOut,
        5: OwnTaskSubscription.none,
        6: OwnTaskSubscription.noneWhileAssigned,
      });
      expect((await dao.findRow(4))!.ownSubscription, 'opted_out');
    });

    test("a read through a project stores it for the task's project first, "
        'so that an unfollow read back as none counts as an opt-out', () async {
      const viaUnfollowed = Subscription(
        entity: SubscriptionEntity.project,
        entityId: unfollowed,
      );
      await db.projectsDao.upsertAll([
        sampleProject(id: 7, title: 'Below', parent: unfollowed),
        sampleProject(id: 8, title: 'Elsewhere'),
      ]);
      await upsert([
        sampleTask(id: 1, title: 'In the project', projectId: unfollowed),
        sampleTask(id: 2, title: 'In a subproject', projectId: 7),
        sampleTask(id: 3, title: 'Moved since', projectId: 8),
      ]);
      final dao = db.tasksDao;

      await dao.storeOwnSubscription(1, viaUnfollowed, userId: alice.id);
      await dao.storeOwnSubscription(2, viaUnfollowed, userId: alice.id);
      await dao.storeOwnSubscription(3, inherited, userId: alice.id);
      final stored = {
        for (final project in await db.projectsDao.loadAll())
          project.id: project.subscription,
      };
      expect(stored, {
        followed: inherited,
        unfollowed: viaUnfollowed,
        7: viaUnfollowed,
        8: null,
      });

      await dao.storeOwnSubscription(1, null, userId: alice.id);
      await dao.storeOwnSubscription(2, null, userId: alice.id);
      await dao.storeOwnSubscription(3, null, userId: alice.id);
      expect(await dao.ownSubscriptions(), {
        1: OwnTaskSubscription.optedOut,
        2: OwnTaskSubscription.optedOut,
        3: OwnTaskSubscription.none,
      });
    });

    test('a task not stored here is left alone', () async {
      await db.tasksDao.storeOwnSubscription(99, own, userId: alice.id);

      expect(await db.tasksDao.findRow(99), isNull);
      expect(await db.tasksDao.ownSubscriptions(), isEmpty);
    });

    test('written only when it changes', () async {
      await upsert([sampleTask(id: 1, title: 'Read', projectId: unfollowed)]);
      var writes = 0;
      final updates = db
          .tableUpdates(TableUpdateQuery.onTable(db.tasks))
          .listen((_) => writes++);
      addTearDown(updates.cancel);
      final dao = db.tasksDao;

      await dao.storeOwnSubscription(1, own, userId: alice.id);
      await pumpEventQueue();
      expect(writes, 1);
      await dao.storeOwnSubscription(1, own, userId: alice.id);
      await pumpEventQueue();
      expect(writes, 1);
      await dao.storeOwnSubscription(1, null, userId: alice.id);
      await pumpEventQueue();
      expect(writes, 2);
      expect(await dao.ownSubscriptions(), {1: OwnTaskSubscription.none});
    });

    test('a sync page, a write answer and a queued change keep it; a new row '
        'starts unknown', () async {
      await upsert([
        sampleTask(id: 1, title: 'Read', projectId: followed),
        sampleTask(id: 2, title: 'Also read', projectId: followed),
      ]);
      await db.tasksDao.storeOwnSubscription(1, own, userId: alice.id);
      await db.tasksDao.storeOwnSubscription(2, null, userId: alice.id);

      await db.tasksDao.upsertAll(
        [
          sampleTask(id: 1, title: 'Synced', projectId: followed),
          sampleTask(id: 3, title: 'New', projectId: followed),
        ],
        syncRunId: 'run-2',
        withCommentState: true,
      );
      await db.tasksDao.upsertAll([
        sampleTask(id: 2, title: 'Answered', projectId: followed),
      ]);
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'Mine'),
        now: monday,
      );

      expect((await db.tasksDao.find(1))!.title, 'Mine');
      expect((await db.tasksDao.find(2))!.title, 'Answered');
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
        2: OwnTaskSubscription.optedOut,
      });
    });

    test('a name this build does not know counts as unknown', () async {
      await upsert([
        sampleTask(id: 1, title: 'Known', projectId: unfollowed),
        sampleTask(id: 2, title: 'From a newer build', projectId: unfollowed),
      ]);
      await db.tasksDao.storeOwnSubscription(1, own, userId: alice.id);
      await db.customStatement(
        "UPDATE tasks SET own_subscription = 'muted_forever' WHERE id = 2",
      );

      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
      });
    });
  });
}
