import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 10, 12);
  final later = DateTime.utc(2026, 10, 10, 12, 5);
  final monday = DateTime.utc(2026, 10, 12, 9);
  const done = TaskChanges(done: true);
  const favorite = TaskChanges(isFavorite: true);

  setUp(() async {
    db = testDatabase();
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'One', projectId: 7, due: monday),
      sampleTask(id: 2, title: 'Two', projectId: 7),
      sampleTask(id: 3, title: 'Three', projectId: 8, done: true),
    ], syncRunId: 'run');
  });

  Future<bool> queue(int id, TaskChanges changes) =>
      db.outboxDao.queueUpdate(id, changes, now: now);

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  Future<TaskChanges?> pendingOf(int id) async {
    final json = (await db.tasksDao.findRow(id))!.pendingChanges;
    return json == null ? null : decodeTaskChanges(json);
  }

  group('queueing an update', () {
    test('applies the change to the row and records it as pending', () async {
      expect(await queue(1, done), isTrue);

      final task = (await db.tasksDao.find(1))!;
      expect(task.done, isTrue);
      expect(task.doneAt, now);
      expect(await pendingOf(1), done);
      final op = (await ops()).single;
      expect(op.kind, OutboxOperationKind.updateTask.name);
      expect(op.taskId, 1);
      expect(op.sequence, 1);
      expect(op.state, OutboxState.pending.name);
      expect(op.attempts, 0);
      expect(op.createdAt, now);
      expect(decodeTaskChanges(op.payload), done);
      expect(await db.outboxDao.count(), 1);
      expect(await db.outboxDao.loadPendingTaskIds(), {1});
    });

    test('undoing clears done_at', () async {
      await queue(1, done);
      await queue(1, const TaskChanges(done: false));

      final task = (await db.tasksDao.find(1))!;
      expect(task.done, isFalse);
      expect(task.doneAt, isNull);
      expect(await pendingOf(1), const TaskChanges(done: false));
      expect(
        decodeTaskChanges((await ops()).single.payload),
        const TaskChanges(done: false),
      );
    });

    test('a later edit of the same task merges into its unsent op', () async {
      await queue(1, done);
      await queue(1, favorite);
      await queue(2, favorite);

      final all = await ops();
      expect(all.map((op) => op.taskId), [1, 2]);
      expect(all.map((op) => op.sequence), [1, 2]);
      expect(
        decodeTaskChanges(all.first.payload),
        const TaskChanges(done: true, isFavorite: true),
      );
      expect(
        await pendingOf(1),
        const TaskChanges(done: true, isFavorite: true),
      );
      final task = (await db.tasksDao.find(1))!;
      expect(task.done, isTrue);
      expect(task.isFavorite, isTrue);
    });

    test('a failed op takes the edit and goes back to pending', () async {
      await queue(1, done);
      final op = (await ops()).single;
      await db.outboxDao.markFailed(op.id, const Forbidden(code: 7003));

      await queue(1, favorite);

      final again = (await ops()).single;
      expect(again.id, op.id);
      expect(again.state, OutboxState.pending.name);
      expect(again.attempts, 0);
      expect(again.lastError, isNull);
      expect(
        decodeTaskChanges(again.payload),
        const TaskChanges(done: true, isFavorite: true),
      );
    });

    test('a failed op behind a newer edit folds into it: the newer intent wins '
        'and a third edit merges into the newest op', () async {
      await queue(1, done);
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await queue(1, const TaskChanges(done: false));

      await db.outboxDao.markFailed(first.id, const Forbidden(code: 7003));

      final folded = (await ops()).single;
      expect(folded.id, isNot(first.id));
      expect(folded.state, OutboxState.pending.name);
      expect(decodeTaskChanges(folded.payload), const TaskChanges(done: false));
      expect(await pendingOf(1), const TaskChanges(done: false));
      expect(await db.outboxDao.loadProblems(), isEmpty);

      await queue(1, favorite);

      final merged = (await ops()).single;
      expect(merged.id, folded.id);
      expect(
        decodeTaskChanges(merged.payload),
        const TaskChanges(done: false, isFavorite: true),
      );
    });

    test('a failed op keeps the fields the newer op does not set', () async {
      await queue(1, favorite);
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await queue(1, done);

      await db.outboxDao.markFailed(first.id, const Forbidden(code: 7003));

      expect(
        decodeTaskChanges((await ops()).single.payload),
        const TaskChanges(done: true, isFavorite: true),
      );
    });

    test('a failed update behind a queued delete is moot', () async {
      await queue(1, done);
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await db.outboxDao.queueDelete(1, now: now);

      await db.outboxDao.markFailed(first.id, const Forbidden(code: 7003));

      final all = await ops();
      expect(all.map((op) => op.kind), ['deleteTask']);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test(
      'an op being sent is left alone; the edit gets one of its own',
      () async {
        await queue(1, done);
        final sending = (await ops()).single;
        await db.outboxDao.markSending(sending.id, at: now);

        await queue(1, favorite);

        final all = await ops();
        expect(all.map((op) => op.state), ['sending', 'pending']);
        expect(decodeTaskChanges(all.first.payload), done);
        expect(decodeTaskChanges(all.last.payload), favorite);
        expect(
          await pendingOf(1),
          const TaskChanges(done: true, isFavorite: true),
        );
      },
    );

    test('an unknown task takes no change', () async {
      expect(await queue(99, done), isFalse);
      expect(await db.outboxDao.count(), 0);
    });
  });

  group('queueing a delete', () {
    test('hides the row and keeps the queued update ahead of it, with its '
        'pending changes', () async {
      await queue(1, done);

      expect(await db.outboxDao.queueDelete(1, now: now), TaskDeletion.queued);

      expect(await db.tasksDao.find(1), isNull);
      final row = (await db.tasksDao.findRow(1))!;
      expect(row.pendingDelete, isTrue);
      expect(row.done, isTrue);
      expect(await pendingOf(1), done);
      final all = await ops();
      expect(all.map((op) => op.kind), ['updateTask', 'deleteTask']);
      expect(all.map((op) => op.taskId), [1, 1]);
      expect(decodeTaskChanges(all.first.payload), done);
      expect((await db.outboxDao.nextInLine())!.kind, 'updateTask');
      expect((await db.tasksDao.loadOpenTasks()).map((t) => t.id), [2]);
      expect(await db.tasksDao.idsInProject(7), [2]);
      expect(await db.tasksDao.findAll([1, 2]), hasLength(1));
      // The counts mirror the server, which still holds the task.
      expect(await db.tasksDao.count(), 3);
      expect(await db.tasksDao.countInProject(7), 2);
      expect(await db.tasksDao.countNotInProjects([8]), 2);
    });

    test('a second delete changes nothing', () async {
      expect(await db.outboxDao.queueDelete(1, now: now), TaskDeletion.queued);

      expect(await db.outboxDao.queueDelete(1, now: now), TaskDeletion.none);
      expect(await db.outboxDao.queueDelete(99, now: now), TaskDeletion.none);
      expect(await ops(), hasLength(1));
    });

    test('edits are refused while the delete is queued and taken again once '
        'it was taken back', () async {
      await db.outboxDao.queueDelete(1, now: now);

      expect(await queue(1, favorite), isFalse);
      expect(await db.outboxDao.takesUploads(1), isFalse);
      expect(await ops(), hasLength(1));

      expect(await db.outboxDao.unqueueDelete(1), DeleteUnqueue.cancelled);

      expect(await queue(1, favorite), isTrue);
      expect(await db.outboxDao.takesUploads(1), isTrue);
      expect((await ops()).single.kind, 'updateTask');
      expect((await db.tasksDao.find(1))!.isFavorite, isTrue);
    });

    test('keeps an update that is being sent', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);

      await db.outboxDao.queueDelete(1, now: now);

      final all = await ops();
      expect(all.map((op) => op.kind), ['updateTask', 'deleteTask']);
      expect(all.map((op) => op.state), ['sending', 'pending']);
    });
  });

  group('taking a delete back', () {
    test(
      'a queued delete goes; the row shows again with its queued update',
      () async {
        await queue(1, done);
        await db.outboxDao.queueDelete(1, now: now);

        expect(await db.outboxDao.unqueueDelete(1), DeleteUnqueue.cancelled);

        final task = (await db.tasksDao.find(1))!;
        expect(task.done, isTrue);
        expect((await db.tasksDao.findRow(1))!.pendingDelete, isFalse);
        expect(await pendingOf(1), done);
        final op = (await ops()).single;
        expect(op.kind, 'updateTask');
        expect(decodeTaskChanges(op.payload), done);
        expect(await db.outboxDao.queuedDeleteOf(1), isNull);
        expect(await db.outboxDao.hasQueuedDelete(1), isFalse);
      },
    );

    test('a delete the server refused is taken back too', () async {
      await db.outboxDao.queueDelete(1, now: now);
      final delete = (await ops()).single;
      await db.outboxDao.markSending(delete.id, at: now);
      await db.outboxDao.markFailed(delete.id, const Forbidden());
      expect(await db.outboxDao.loadProblems(), hasLength(1));

      expect(await db.outboxDao.unqueueDelete(1), DeleteUnqueue.cancelled);

      expect(await ops(), isEmpty);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect((await db.tasksDao.find(1))!.title, 'One');
    });

    test('a delete back in the queue after an attempt that may have '
        'reached the server says so', () async {
      await db.outboxDao.queueDelete(1, now: now);
      final delete = (await ops()).single;
      await db.outboxDao.markSending(delete.id, at: now);
      await db.outboxDao.scheduleRetry(
        delete.id,
        attempts: 1,
        failure: const NetworkFailure(NetworkProblem.timeout),
        nextAttemptAt: later,
      );
      expect((await ops()).single.sentAt, isNull);

      expect(
        await db.outboxDao.unqueueDelete(1),
        DeleteUnqueue.cancelledAfterAttempt,
      );

      expect(await ops(), isEmpty);
      expect((await db.tasksDao.find(1))!.title, 'One');
    });

    test('so does a delete a killed app left in flight, once reset', () async {
      await db.outboxDao.queueDelete(1, now: now);
      final delete = (await ops()).single;
      await db.outboxDao.markSending(delete.id, at: now);
      expect(await db.outboxDao.resetSending(now: later), 1);
      final reset = (await ops()).single;
      expect(reset.state, OutboxState.pending.name);
      expect(reset.attempts, 0);
      expect(reset.sentAt, isNull);
      expect(reset.lastError, isNull);

      expect(
        await db.outboxDao.unqueueDelete(1),
        DeleteUnqueue.cancelledAfterAttempt,
      );
      expect((await db.tasksDao.find(1))!.title, 'One');
    });

    test('a delete on its way is left alone', () async {
      await db.outboxDao.queueDelete(1, now: now);
      final delete = (await ops()).single;
      await db.outboxDao.markSending(delete.id, at: now);

      expect(await db.outboxDao.unqueueDelete(1), DeleteUnqueue.sending);

      expect((await db.outboxDao.queuedDeleteOf(1))!.id, delete.id);
      expect((await ops()).single.state, OutboxState.sending.name);
      expect(await db.tasksDao.find(1), isNull);
    });

    test('without a queued delete there is nothing to take back', () async {
      await queue(1, done);

      expect(await db.outboxDao.unqueueDelete(1), DeleteUnqueue.notQueued);
      expect(await db.outboxDao.unqueueDelete(99), DeleteUnqueue.notQueued);

      expect((await ops()).single.kind, 'updateTask');
      expect(await db.outboxDao.queuedDeleteOf(1), isNull);
    });

    test(
      'follows a temporary id whose create was answered meanwhile',
      () async {
        final id = await db.outboxDao.queueCreate(
          const NewTask(projectId: 7, title: 'New'),
          now: now,
        );
        final create = (await ops()).single;
        await db.outboxDao.markSending(create.id, at: now);
        expect(
          await db.outboxDao.queueDelete(id, now: now),
          TaskDeletion.queued,
        );
        await db.outboxDao.completeCreate(
          create.id,
          sampleTask(id: 50, title: 'New', projectId: 7),
          at: later,
        );
        expect((await db.outboxDao.queuedDeleteOf(id))!.taskId, 50);
        expect(await db.tasksDao.find(50), isNull);

        expect(await db.outboxDao.unqueueDelete(id), DeleteUnqueue.cancelled);

        expect(await ops(), isEmpty);
        expect((await db.tasksDao.find(50))!.title, 'New');
      },
    );
  });

  group('the queue', () {
    test('hands out the oldest pending op; failed ones are skipped', () async {
      await queue(1, done);
      await queue(2, done);
      final first = (await ops()).first;

      expect((await db.outboxDao.nextInLine())!.id, first.id);

      await db.outboxDao.markFailed(first.id, const NotFound(code: 3001));
      expect((await db.outboxDao.nextInLine())!.taskId, 2);

      await db.outboxDao.retry(first.id);
      final retried = (await db.outboxDao.nextInLine())!;
      expect(retried.id, first.id);
      expect(retried.attempts, 0);
      expect(retried.lastError, isNull);
    });

    test('a retry schedule keeps the op pending with its error', () async {
      await queue(1, done);
      final op = (await ops()).single;

      await db.outboxDao.scheduleRetry(
        op.id,
        attempts: 1,
        failure: const NetworkFailure(NetworkProblem.timeout),
        nextAttemptAt: later,
      );

      final scheduled = (await ops()).single;
      expect(scheduled.state, OutboxState.pending.name);
      expect(scheduled.attempts, 1);
      expect(scheduled.nextAttemptAt, later);
      expect(
        decodeFailure(scheduled.lastError!),
        isA<NetworkFailure>().having(
          (f) => f.problem,
          'problem',
          NetworkProblem.timeout,
        ),
      );

      expect(await db.outboxDao.clearBackoff(), 1);
      expect((await ops()).single.nextAttemptAt, isNull);
    });

    test('claiming an op takes it as it is now, once', () async {
      await queue(1, done);
      final read = (await db.outboxDao.nextInLine())!;
      // An undo lands between the read and the claim.
      await queue(1, const TaskChanges(done: false));

      final claimed = (await db.outboxDao.claim(read.id, at: later))!;

      expect(claimed.state, OutboxState.sending.name);
      expect(claimed.lastAttemptAt, later);
      expect(
        decodeTaskChanges(claimed.payload),
        const TaskChanges(done: false),
      );
      expect(await db.outboxDao.claim(read.id, at: later), isNull);
      expect(await db.outboxDao.claim('missing', at: later), isNull);
    });

    test('removing every op of a task', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);
      await queue(1, favorite);
      await queue(2, done);

      await db.outboxDao.removeAllOf(1);

      expect((await ops()).map((op) => op.taskId), [2]);
    });

    test(
      'only ops in flight for at least the given age go back to pending',
      () async {
        await queue(1, done);
        await db.outboxDao.markSending((await ops()).single.id, at: now);

        expect(
          await db.outboxDao.resetSending(
            now: later,
            olderThan: const Duration(minutes: 6),
          ),
          0,
        );
        expect((await ops()).single.state, OutboxState.sending.name);
        expect(
          await db.outboxDao.resetSending(
            now: later,
            olderThan: const Duration(minutes: 5),
          ),
          1,
        );
      },
    );

    test(
      'an op whose attempt lies ahead of a clock set back is reset',
      () async {
        await queue(1, done);
        await db.outboxDao.markSending((await ops()).single.id, at: later);

        expect(
          await db.outboxDao.resetSending(
            now: later.subtract(const Duration(hours: 1)),
            olderThan: const Duration(minutes: 5),
          ),
          1,
        );
      },
    );

    test('ops left in flight by a killed app go back to pending', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);

      expect(await db.outboxDao.resetSending(now: later), 1);

      final op = (await ops()).single;
      expect(op.state, OutboxState.pending.name);
      expect(op.sentAt, isNull);
    });

    test("removing an op recomputes the task's pending changes", () async {
      await queue(1, done);
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await queue(1, favorite);
      final second = (await ops()).last;

      await db.outboxDao.remove(first.id);
      expect(await pendingOf(1), favorite);
      expect(await db.outboxDao.pendingChangesFor(1), favorite);

      await db.outboxDao.remove(second.id);
      expect(await pendingOf(1), isNull);
      expect(await db.outboxDao.pendingChangesFor(1), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('a delete op can be taken back', () async {
      await db.outboxDao.queueDelete(1, now: now);
      final op = (await ops()).single;

      await db.outboxDao.remove(op.id);
      await db.outboxDao.clearPendingDelete(1);

      expect((await db.tasksDao.find(1))!.title, 'One');
    });
  });

  group('problems', () {
    test('ops refused because the task or its project was gone or in the '
        'trash go back to the queue for that task only', () async {
      await queue(1, done);
      await queue(2, favorite);
      await queue(3, favorite);
      final [one, two, three] = await ops();
      await db.outboxDao.markFailed(one.id, const NotFound(code: 4040));
      await db.outboxDao.markFailed(two.id, const NotFound(code: 3018));
      await db.outboxDao.markFailed(three.id, const Forbidden(code: 7003));

      expect(await db.outboxDao.retryRefusedAsGone(1), 1);
      expect(await db.outboxDao.retryRefusedAsGone(3), 0);

      final [backOne, stillTwo, stillThree] = await ops();
      expect(backOne.state, OutboxState.pending.name);
      expect(backOne.attempts, 0);
      expect(backOne.lastError, isNull);
      expect(stillTwo.state, OutboxState.failed.name);
      expect(stillThree.state, OutboxState.failed.name);

      expect(await db.outboxDao.retryRefusedAsGone(2), 1);
      expect((await ops())[1].state, OutboxState.pending.name);
    });

    test('an edge to another task that is gone is not the task gone', () async {
      await queue(
        1,
        TaskChanges(
          relations: RelationChange(
            added: {const TaskRelationRef(TaskRelationKind.related, 2)},
          ),
        ),
      );
      await db.outboxDao.markFailed(
        (await ops()).single.id,
        const RelatedTaskMissing(2, code: 4040),
      );

      expect(await db.outboxDao.retryRefusedAsGone(1), 0);
      expect((await ops()).single.state, OutboxState.failed.name);
    });

    test('failed ops are listed with the task title, oldest first', () async {
      await queue(1, done);
      await queue(2, done);
      final all = await ops();
      await db.outboxDao.markSending(all.last.id, at: later);
      await db.outboxDao.markFailed(all.last.id, const Forbidden(code: 7003));
      await db.outboxDao.markFailed(
        all.first.id,
        const NotFound(code: 3001, message: 'project does not exist'),
      );

      final problems = await db.outboxDao.loadProblems();

      expect(problems.map((p) => p.taskTitle), ['One', 'Two']);
      expect(problems.map((p) => p.taskId), [1, 2]);
      expect(problems.map((p) => p.operationId), [all.first.id, all.last.id]);
      expect(problems.first.kind, OutboxOperationKind.updateTask);
      expect(
        problems.first.failure,
        isA<NotFound>()
            .having((f) => f.code, 'code', 3001)
            .having((f) => f.message, 'message', 'project does not exist'),
      );
      expect(problems.first.failedAt, now);
      expect(problems.last.failedAt, later);
      expect(problems.last.failure, isA<Forbidden>());
    });

    test('the count, the problems and the pending ids are streams', () async {
      final counts = <int>[];
      final problems = <List<SyncProblem>>[];
      final ids = <Set<int>>[];
      db.outboxDao.watchCount().listen(counts.add);
      db.outboxDao.watchProblems().listen(problems.add);
      db.outboxDao.watchPendingTaskIds().listen(ids.add);
      await pumpEventQueue();
      expect(counts, [0]);
      expect(problems, [isEmpty]);
      expect(ids, [isEmpty]);

      await queue(2, done);
      await pumpEventQueue();
      expect(counts.last, 1);
      expect(ids.last, {2});

      final op = (await ops()).single;
      await db.outboxDao.markFailed(op.id, const Forbidden(code: 7003));
      await pumpEventQueue();
      expect(problems.last.single.taskTitle, 'Two');

      await db.outboxDao.remove(op.id);
      await pumpEventQueue();
      expect(counts.last, 0);
      expect(problems.last, isEmpty);
      expect(ids.last, isEmpty);
    });
  });

  group('creates', () {
    const draft = NewTask(
      projectId: 7,
      title: 'Buy milk',
      priority: TaskPriority.high,
      hexColor: 'ff4136',
      isFavorite: true,
    );

    Future<int> create([NewTask task = draft]) =>
        db.outboxDao.queueCreate(task, now: now);

    Future<OutboxRow> createOp(int localId) async => (await ops()).singleWhere(
      (op) => op.taskId == localId && op.kind == 'createTask',
    );

    test('a new task gets the next temporary id and a create op', () async {
      final first = await create();
      final second = await create(const NewTask(projectId: 8, title: 'Two'));

      expect(first, -1);
      expect(second, -2);
      final task = (await db.tasksDao.find(-1))!;
      expect(task.title, 'Buy milk');
      expect(task.projectId, 7);
      expect(task.priority, TaskPriority.high);
      expect(task.hexColor, 'ff4136');
      expect(task.isFavorite, isTrue);
      expect(task.identifier, '');
      expect(task.created, now);
      expect(task.updated, isNull);
      expect((await db.tasksDao.findRow(-1))!.pendingChanges, isNull);
      final op = await createOp(-1);
      expect(op.state, OutboxState.pending.name);
      expect(op.sentAt, isNull);
      expect(decodeNewTask(op.payload), draft);
      expect(await db.outboxDao.count(), 2);
      expect(await db.outboxDao.loadPendingTaskIds(), {-1, -2});
      expect((await db.outboxDao.nextInLine())!.taskId, -1);
    });

    test(
      'temporary ids are never reused, even once the rows are gone',
      () async {
        final first = await create();
        await db.outboxDao.completeCreate(
          (await createOp(first)).id,
          sampleTask(id: 50, title: 'Buy milk', projectId: 7),
          at: later,
        );
        await db.outboxDao.cancelCreate(await create());

        expect(await create(), -3);
      },
    );

    test('an edit before the send folds into the create', () async {
      final id = await create();

      expect(
        await queue(
          id,
          TaskChanges(
            title: 'Buy oat milk',
            projectId: 8,
            dueDate: DateChange.set(monday),
            repeatAfter: const Duration(days: 1),
            isFavorite: false,
          ),
        ),
        isTrue,
      );

      final op = (await ops()).single;
      expect(op.kind, 'createTask');
      expect(
        decodeNewTask(op.payload),
        NewTask(
          projectId: 8,
          title: 'Buy oat milk',
          priority: TaskPriority.high,
          hexColor: 'ff4136',
          dueDate: monday,
          repeatAfter: const Duration(days: 1),
        ),
      );
      final task = (await db.tasksDao.find(id))!;
      expect(task.title, 'Buy oat milk');
      expect(task.projectId, 8);
      expect(task.dueDate, monday);
      expect(task.repeatAfter, const Duration(days: 1));
      expect(task.isFavorite, isFalse);
      expect((await db.tasksDao.findRow(id))!.pendingChanges, isNull);
    });

    test(
      'a done before the send is the one update a create cannot carry',
      () async {
        final id = await create();

        await queue(id, const TaskChanges(done: true, title: 'Bought'));
        await queue(id, const TaskChanges(done: false));

        final all = await ops();
        expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
        expect(decodeNewTask(all.first.payload).title, 'Bought');
        expect(
          decodeTaskChanges(all.last.payload),
          const TaskChanges(done: false),
        );
        expect(await pendingOf(id), const TaskChanges(done: false));
        expect((await db.tasksDao.find(id))!.done, isFalse);
        // The update waits for the create: it cannot go under a temporary id.
        expect((await db.outboxDao.nextInLine())!.kind, 'createTask');
        await db.outboxDao.markSending(all.first.id, at: now);
        expect((await db.outboxDao.nextInLine())!.kind, 'createTask');
      },
    );

    test('a delete before the send queues behind the create', () async {
      final id = await create();
      await queue(id, const TaskChanges(done: true));

      expect(await db.outboxDao.queueDelete(id, now: now), TaskDeletion.queued);

      expect(await db.tasksDao.find(id), isNull);
      expect((await db.tasksDao.findRow(id))!.pendingDelete, isTrue);
      final all = await ops();
      expect(all.map((op) => op.kind), [
        'createTask',
        'updateTask',
        'deleteTask',
      ]);
      expect(all.map((op) => op.taskId), [id, id, id]);
      expect(await db.outboxDao.queueDelete(id, now: now), TaskDeletion.none);

      expect(await db.outboxDao.unqueueDelete(id), DeleteUnqueue.cancelled);

      expect((await db.tasksDao.find(id))!.done, isTrue);
      expect((await ops()).map((op) => op.kind), ['createTask', 'updateTask']);
    });

    test('a rejected create takes the edit and goes back to pending; a delete '
        'discards it', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await db.outboxDao.markFailed(op.id, const DomainError(412, code: 3008));
      expect((await db.outboxDao.loadProblems()).single.taskTitle, 'Buy milk');

      await queue(id, const TaskChanges(projectId: 9));

      final retaken = (await ops()).single;
      expect(retaken.id, op.id);
      expect(retaken.state, OutboxState.pending.name);
      expect(retaken.lastError, isNull);
      expect(decodeNewTask(retaken.payload).projectId, 9);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      await db.outboxDao.markFailed(op.id, const DomainError(412, code: 3008));

      expect(
        await db.outboxDao.queueDelete(id, now: now),
        TaskDeletion.discarded,
      );

      expect(await db.outboxDao.count(), 0);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await db.outboxDao.unqueueDelete(id), DeleteUnqueue.notQueued);
    });

    test(
      'a create refused with a delete queued behind it goes with the row',
      () async {
        final id = await create();
        final op = await createOp(id);
        await db.outboxDao.markSending(op.id, at: now);
        await db.outboxDao.markUncertain(op.id, sentAt: now);
        await queue(id, done);
        await db.outboxDao.queueDelete(id, now: now);

        await db.outboxDao.markFailed(
          op.id,
          const DomainError(412, code: 3008),
        );

        expect(await ops(), isEmpty);
        expect(await db.tasksDao.findRow(id), isNull);
      },
    );

    test('while the create is in flight, edits and a delete queue behind it '
        'under the temporary id', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);

      await queue(id, const TaskChanges(title: 'Edited in flight'));
      await queue(id, favorite);
      expect(await db.outboxDao.queueDelete(id, now: now), TaskDeletion.queued);

      final all = await ops();
      expect(all.map((op) => op.kind), [
        'createTask',
        'updateTask',
        'deleteTask',
      ]);
      expect(all.map((op) => op.taskId), [id, id, id]);
      expect(decodeNewTask(all.first.payload), draft);
      expect(
        decodeTaskChanges(all[1].payload),
        const TaskChanges(title: 'Edited in flight', isFavorite: true),
      );
      expect((await db.tasksDao.findRow(id))!.pendingDelete, isTrue);
      expect(await db.tasksDao.find(id), isNull);
    });

    group('cancelDeletedCreate', () {
      test(
        'drops a create never sent with its queued delete and the row',
        () async {
          final id = await create();
          await queue(id, done);
          await db.outboxDao.queueDelete(id, now: now);
          final op = await createOp(id);
          await db.outboxDao.claim(op.id, at: now);

          expect(await db.outboxDao.cancelDeletedCreate(op.id), isTrue);

          expect(await ops(), isEmpty);
          expect(await db.tasksDao.findRow(id), isNull);
        },
      );

      test('leaves a create alone that may have reached the server', () async {
        final id = await create();
        final op = await createOp(id);
        await db.outboxDao.markUncertain(op.id, sentAt: now);
        await db.outboxDao.queueDelete(id, now: now);

        expect(await db.outboxDao.cancelDeletedCreate(op.id), isFalse);

        expect((await ops()).map((op) => op.kind), [
          'createTask',
          'deleteTask',
        ]);
      });

      test('leaves a create alone whose delete was taken back first', () async {
        final id = await create();
        await db.outboxDao.queueDelete(id, now: now);
        final op = await createOp(id);
        await db.outboxDao.claim(op.id, at: now);
        await db.outboxDao.unqueueDelete(id);

        expect(await db.outboxDao.cancelDeletedCreate(op.id), isFalse);

        expect((await ops()).single.id, op.id);
        expect((await db.tasksDao.find(id))!.title, 'Buy milk');
      });

      test('leaves a create alone without a delete, and an op that is no '
          'create', () async {
        final id = await create();
        final op = await createOp(id);
        await queue(1, done);
        await db.outboxDao.queueDelete(1, now: now);
        final update = (await ops()).firstWhere((op) => op.taskId == 1);

        expect(await db.outboxDao.cancelDeletedCreate(op.id), isFalse);
        expect(await db.outboxDao.cancelDeletedCreate(update.id), isFalse);
        expect(await db.outboxDao.cancelDeletedCreate('gone'), isFalse);

        expect(await ops(), hasLength(3));
      });
    });

    test('an unanswered create keeps its payload: the lookup needs the title '
        'as sent', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await db.outboxDao.markUncertain(op.id, sentAt: now);
      await db.outboxDao.scheduleRetry(
        op.id,
        attempts: 1,
        failure: const NetworkFailure(NetworkProblem.timeout),
        nextAttemptAt: later,
      );
      // A second uncertain attempt keeps the first time.
      await db.outboxDao.markUncertain(op.id, sentAt: later);

      await queue(id, const TaskChanges(title: 'Renamed meanwhile'));

      final all = await ops();
      expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
      expect(all.first.sentAt, now);
      expect(decodeNewTask(all.first.payload).title, 'Buy milk');
      expect(
        decodeTaskChanges(all.last.payload),
        const TaskChanges(title: 'Renamed meanwhile'),
      );
      expect((await db.tasksDao.find(id))!.title, 'Renamed meanwhile');
      expect(
        await pendingOf(id),
        const TaskChanges(title: 'Renamed meanwhile'),
      );
    });

    test('a create left in flight by a killed app is uncertain as of its '
        'attempt, and an edit queues behind it', () async {
      final id = await create();
      final createOpId = (await createOp(id)).id;
      await db.outboxDao.markSending(createOpId, at: now);
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).last.id, at: now);

      expect(await db.outboxDao.resetSending(now: later), 2);

      final all = await ops();
      expect(all.map((op) => op.state), ['pending', 'pending']);
      expect(all.first.sentAt, now);
      expect(all.first.lastAttemptAt, now);
      expect(all.last.sentAt, isNull);
      // The server may have the task: the edit is not folded into the create.
      await queue(id, const TaskChanges(title: 'Edited after the restart'));
      expect((await ops()).map((op) => op.kind), [
        'createTask',
        'updateTask',
        'updateTask',
      ]);
      expect(decodeNewTask((await createOp(id)).payload).title, 'Buy milk');
    });

    test('a create reset after a restart keeps an earlier sent_at', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markUncertain(op.id, sentAt: now);
      await db.outboxDao.markSending(op.id, at: later);

      await db.outboxDao.resetSending(now: later);

      expect((await createOp(id)).sentAt, now);
    });

    test('a create left in flight without an attempt time takes the reset '
        'time', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await db.customStatement(
        'UPDATE outbox SET last_attempt_at = NULL WHERE id = ?',
        [op.id],
      );

      await db.outboxDao.resetSending(now: later);

      expect((await createOp(id)).sentAt, later);
    });

    test('a rejected create takes the edit queued while it was in flight, so '
        'a later edit folded into it is not reverted', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await queue(id, const TaskChanges(title: 'B', done: true));
      expect((await ops()).map((op) => op.kind), ['createTask', 'updateTask']);

      await db.outboxDao.markFailed(op.id, const DomainError(412, code: 3008));

      var all = await ops();
      expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
      expect(decodeNewTask(all.first.payload).title, 'B');
      expect(
        decodeTaskChanges(all.last.payload),
        const TaskChanges(done: true),
      );
      expect(await pendingOf(id), const TaskChanges(done: true));

      await queue(id, const TaskChanges(title: 'C'));

      all = await ops();
      expect(decodeNewTask(all.first.payload).title, 'C');
      expect(all.first.state, OutboxState.pending.name);
      await db.outboxDao.completeCreate(
        all.first.id,
        sampleTask(id: 50, title: 'C', projectId: 7),
        at: later,
      );
      final task = (await db.tasksDao.find(50))!;
      expect(task.title, 'C');
      expect(task.done, isTrue);
      expect(await pendingOf(50), const TaskChanges(done: true));
    });

    test('a rejected create with only a rename behind it carries the rename '
        'and the update op goes', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await queue(id, const TaskChanges(title: 'B'));

      await db.outboxDao.markFailed(op.id, const NotFound(code: 3001));

      final failed = (await ops()).single;
      expect(failed.kind, 'createTask');
      expect(failed.state, OutboxState.failed.name);
      expect(decodeNewTask(failed.payload).title, 'B');
      expect(await pendingOf(id), isNull);
      expect((await db.tasksDao.find(id))!.title, 'B');
    });

    test('an edit or a delete under a remapped temporary id lands on the '
        'server row', () async {
      final id = await create();
      await db.outboxDao.completeCreate(
        (await createOp(id)).id,
        sampleTask(id: 50, title: 'Buy milk', projectId: 7),
        at: later,
      );

      expect(await queue(id, done), isTrue);

      final op = (await ops()).single;
      expect(op.kind, 'updateTask');
      expect(op.taskId, 50);
      expect((await db.tasksDao.find(50))!.done, isTrue);
      expect(await pendingOf(50), done);

      expect(await db.outboxDao.queueDelete(id, now: now), TaskDeletion.queued);

      expect((await ops()).map((op) => op.kind), ['updateTask', 'deleteTask']);
      expect((await ops()).map((op) => op.taskId), [50, 50]);
      expect((await db.tasksDao.findRow(50))!.pendingDelete, isTrue);
      expect(await queue(id, done), isFalse);
    });

    test('a rejection clears the uncertainty: the server said no', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markUncertain(op.id, sentAt: now);

      await db.outboxDao.markFailed(op.id, const NotFound(code: 3001));

      expect((await createOp(id)).sentAt, isNull);
    });

    test(
      'a rejected create behind which a delete waits goes with it',
      () async {
        final id = await create();
        final op = await createOp(id);
        await db.outboxDao.markSending(op.id, at: now);
        await db.outboxDao.queueDelete(id, now: now);

        await db.outboxDao.markFailed(op.id, const NotFound(code: 3001));

        expect(await db.outboxDao.count(), 0);
        expect(await db.tasksDao.findRow(id), isNull);
      },
    );

    test('completing a create moves the row to the server id with the '
        'response applied and records the remap', () async {
      final id = await create();
      final op = await createOp(id);
      final created = sampleTask(
        id: 50,
        title: 'Buy milk',
        projectId: 7,
        priority: TaskPriority.high,
        favorite: true,
        identifier: 'SHOP-4',
        updated: later,
      );

      await db.outboxDao.completeCreate(op.id, created, at: later);

      expect(await db.tasksDao.findRow(id), isNull);
      final task = (await db.tasksDao.find(50))!;
      expect(task.title, 'Buy milk');
      expect(task.identifier, 'SHOP-4');
      expect(task.index, 50);
      expect(task.updated, later);
      expect((await db.tasksDao.findRow(50))!.pendingChanges, isNull);
      expect(await db.outboxDao.count(), 0);
      expect(await db.tasksDao.resolveId(id), 50);
      expect(await db.tasksDao.resolveId(50), 50);
      expect(await db.tasksDao.resolveId(-99), -99);
    });

    test('the ops queued behind the create follow it to the server id and '
        'their fields stay on top of the response', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await queue(id, const TaskChanges(done: true, title: 'Edited in flight'));

      await db.outboxDao.completeCreate(
        op.id,
        sampleTask(id: 50, title: 'Buy milk', projectId: 7, updated: later),
        at: later,
      );

      final follower = (await ops()).single;
      expect(follower.kind, 'updateTask');
      expect(follower.taskId, 50);
      expect(follower.state, OutboxState.pending.name);
      expect((await db.outboxDao.nextInLine())!.id, follower.id);
      final task = (await db.tasksDao.find(50))!;
      expect(task.title, 'Edited in flight');
      expect(task.done, isTrue);
      expect(task.doneAt, now);
      expect(task.updated, later);
      expect(
        await pendingOf(50),
        const TaskChanges(done: true, title: 'Edited in flight'),
      );
      expect(await db.outboxDao.loadPendingTaskIds(), {50});
    });

    test(
      'a delete queued behind the create keeps the server row hidden',
      () async {
        final id = await create();
        final op = await createOp(id);
        await db.outboxDao.markSending(op.id, at: now);
        await db.outboxDao.queueDelete(id, now: now);

        await db.outboxDao.completeCreate(
          op.id,
          sampleTask(id: 50, title: 'Buy milk', projectId: 7),
          at: later,
        );

        expect(await db.tasksDao.find(50), isNull);
        expect((await db.tasksDao.findRow(50))!.pendingDelete, isTrue);
        final follower = (await ops()).single;
        expect(follower.kind, 'deleteTask');
        expect(follower.taskId, 50);
      },
    );

    test(
      'a row the sync pulled under the server id meanwhile is replaced',
      () async {
        final id = await create();
        final op = await createOp(id);
        await db.tasksDao.upsertAll([
          sampleTask(id: 50, title: 'Buy milk', projectId: 7, updated: now),
        ], syncRunId: 'run');

        await db.outboxDao.completeCreate(
          op.id,
          sampleTask(id: 50, title: 'Buy milk', projectId: 7, updated: later),
          at: later,
        );

        expect((await db.tasksDao.find(50))!.updated, later);
        expect(await db.tasksDao.findRow(id), isNull);
        expect(await db.tasksDao.count(), 4);
      },
    );

    test('a create is listed as a problem under its title', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: later);

      await db.outboxDao.markFailed(
        op.id,
        const ValidationFailed(code: 4001, message: 'title empty'),
      );

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.kind, OutboxOperationKind.createTask);
      expect(problem.taskId, id);
      expect(problem.taskTitle, 'Buy milk');
      expect(problem.failedAt, later);
      expect(await db.outboxDao.nextInLine(), isNull);
    });
  });

  group('kanban placements', () {
    const toDoing = TaskChanges(
      kanban: {80: BucketPlacement(bucketId: 2, position: 32768)},
    );

    test('are queued and kept as pending, without touching the row', () async {
      await queue(1, toDoing);

      expect(await pendingOf(1), toDoing);
      expect(decodeTaskChanges((await ops()).single.payload), toDoing);
      final task = (await db.tasksDao.find(1))!;
      expect(task.done, isFalse);
      expect(task.bucketId, 0);
    });

    test('merge per view: the later placement on a view wins, other views '
        'and fields stay', () async {
      await queue(1, toDoing);
      await queue(
        1,
        const TaskChanges(
          done: true,
          kanban: {81: BucketPlacement(bucketId: 13)},
        ),
      );
      await queue(
        1,
        const TaskChanges(
          kanban: {80: BucketPlacement(bucketId: 3, position: 1)},
        ),
      );

      const merged = TaskChanges(
        done: true,
        kanban: {
          80: BucketPlacement(bucketId: 3, position: 1),
          81: BucketPlacement(bucketId: 13),
        },
      );
      expect(decodeTaskChanges((await ops()).single.payload), merged);
      expect(await pendingOf(1), merged);
    });

    test('wait behind a create that has not left the device', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );

      await queue(id, const TaskChanges(title: 'Renamed').merge(toDoing));

      final all = await ops();
      expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
      expect(decodeNewTask(all.first.payload).title, 'Renamed');
      expect(decodeTaskChanges(all.last.payload), toDoing);
      expect(await pendingOf(id), toDoing);
    });

    test('are dropped by a later project move, as they name the previous '
        "project's views", () async {
      await queue(1, toDoing.merge(done));

      await queue(1, const TaskChanges(projectId: 8));

      const moved = TaskChanges(done: true, projectId: 8);
      expect(decodeTaskChanges((await ops()).single.payload), moved);
      expect(await pendingOf(1), moved);
    });

    test('behind an unsent create are dropped when the create moves to '
        'another project', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );
      await queue(id, toDoing);
      final other = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'Other'),
        now: now,
      );
      await queue(other, toDoing.merge(done));

      await queue(id, const TaskChanges(projectId: 8));
      await queue(other, const TaskChanges(projectId: 8));

      final all = await ops();
      expect(all.map((op) => (op.kind, op.taskId)), [
        ('createTask', id),
        ('createTask', other),
        ('updateTask', other),
      ]);
      expect(decodeNewTask(all.first.payload).projectId, 8);
      expect(decodeTaskChanges(all.last.payload), done);
      expect(await pendingOf(id), isNull);
      expect(await pendingOf(other), done);
    });

    test('follow the create to the server id', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );
      await queue(id, toDoing);
      final create = (await ops()).first;

      await db.outboxDao.completeCreate(
        create.id,
        sampleTask(id: 50, title: 'New', projectId: 7),
        at: later,
      );

      final follower = (await ops()).single;
      expect(follower.taskId, 50);
      expect(decodeTaskChanges(follower.payload), toDoing);
      expect(await pendingOf(50), toDoing);
    });

    test('stay pending over a sync and when the op fails, until it is '
        'removed', () async {
      await queue(1, toDoing);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'One', projectId: 7, due: monday),
      ], syncRunId: 'run-2');
      expect(await pendingOf(1), toDoing);

      final op = (await ops()).single;
      await db.outboxDao.markSending(op.id, at: now);
      await db.outboxDao.markFailed(op.id, const DomainError(412, code: 10004));
      expect(await pendingOf(1), toDoing);
      expect(
        (await db.outboxDao.loadProblems()).single.failure,
        isA<DomainError>().having((failure) => failure.code, 'code', 10004),
      );

      await db.outboxDao.remove(op.id);
      expect(await pendingOf(1), isNull);
    });

    group('give way to a later change of the done state, whose move would '
        'set it back', () {
      const intoDone = TaskChanges(
        done: true,
        kanban: {80: BucketPlacement(bucketId: 3, position: 1)},
      );
      const open = TaskChanges(done: false);

      test('a drop into the done column, then marked open', () async {
        await queue(1, intoDone);
        await queue(1, open);

        expect(decodeTaskChanges((await ops()).single.payload), open);
        expect(await pendingOf(1), open);
        expect((await db.tasksDao.find(1))!.done, isFalse);
      });

      test('a drop out of the done column, then marked done', () async {
        await queue(3, const TaskChanges(done: false).merge(toDoing));
        await queue(3, done);

        expect(decodeTaskChanges((await ops()).single.payload), done);
        expect(await pendingOf(3), done);
      });

      test('a reorder without a done change, then marked done', () async {
        await queue(1, toDoing);
        await queue(1, done);

        expect(decodeTaskChanges((await ops()).single.payload), done);
        expect(await pendingOf(1), done);
      });

      test('behind a create that has not left the device', () async {
        final id = await db.outboxDao.queueCreate(
          const NewTask(projectId: 7, title: 'New'),
          now: now,
        );
        await queue(id, intoDone);
        await queue(id, open);

        final all = await ops();
        expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
        expect(decodeTaskChanges(all.last.payload), open);
        expect(await pendingOf(id), open);
      });

      test('folded in when the placement failed', () async {
        await queue(1, intoDone);
        final failed = (await ops()).single;
        await db.outboxDao.markSending(failed.id, at: now);
        await queue(1, open);
        expect(await pendingOf(1), open);

        await db.outboxDao.markFailed(
          failed.id,
          const DomainError(412, code: 10004),
        );

        expect(decodeTaskChanges((await ops()).single.payload), open);
        expect(await pendingOf(1), open);
      });
    });

    test('survive the labels and edges a sync forgets', () async {
      await queue(
        1,
        toDoing.merge(const TaskChanges(labels: IdSetChange(added: {5, 6}))),
      );

      await db.outboxDao.forgetLabels({5});

      expect(
        decodeTaskChanges((await ops()).single.payload),
        toDoing.merge(const TaskChanges(labels: IdSetChange(added: {6}))),
      );
    });

    test('stay queued ahead of a delete of the task', () async {
      await queue(1, toDoing);

      await db.outboxDao.queueDelete(1, now: now);

      expect((await ops()).map((op) => op.kind), ['updateTask', 'deleteTask']);
      expect(await pendingOf(1), toDoing);
    });
  });

  group('list positions', () {
    const reordered = TaskChanges(positions: {70: 1.5});

    test('are queued and kept as pending, without touching the row', () async {
      await queue(1, reordered);

      expect(await pendingOf(1), reordered);
      expect(decodeTaskChanges((await ops()).single.payload), reordered);
      expect((await db.tasksDao.find(1))!.position, 0);
    });

    test('merge per view: the later position on a view wins, other views '
        'and fields stay', () async {
      await queue(1, reordered);
      await queue(1, const TaskChanges(title: 'Renamed', positions: {71: 4}));
      await queue(1, const TaskChanges(positions: {70: 0.75}));

      const merged = TaskChanges(
        title: 'Renamed',
        positions: {70: 0.75, 71: 4},
      );
      expect(decodeTaskChanges((await ops()).single.payload), merged);
      expect(await pendingOf(1), merged);
    });

    test('stay when the task is marked done or open, which no position '
        'sets back', () async {
      await queue(1, reordered);
      await queue(1, done);
      await queue(1, const TaskChanges(done: false));

      const kept = TaskChanges(done: false, positions: {70: 1.5});
      expect(decodeTaskChanges((await ops()).single.payload), kept);
      expect(await pendingOf(1), kept);
    });

    test('are dropped by a later project move, as they name the previous '
        "project's views", () async {
      await queue(1, reordered.merge(favorite));

      await queue(1, const TaskChanges(projectId: 8));

      const moved = TaskChanges(isFavorite: true, projectId: 8);
      expect(decodeTaskChanges((await ops()).single.payload), moved);
      expect(await pendingOf(1), moved);
    });

    test('wait behind a create that has not left the device, and go when it '
        'moves to another project', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );
      await queue(id, const TaskChanges(title: 'Renamed').merge(reordered));

      var all = await ops();
      expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
      expect(decodeNewTask(all.first.payload).title, 'Renamed');
      expect(decodeTaskChanges(all.last.payload), reordered);
      expect(await pendingOf(id), reordered);

      await queue(id, const TaskChanges(projectId: 8));

      all = await ops();
      expect(all.map((op) => op.kind), ['createTask']);
      expect(decodeNewTask(all.single.payload).projectId, 8);
      expect(await pendingOf(id), isNull);
    });

    test('follow the create to the server id', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );
      await queue(id, reordered);
      final create = (await ops()).first;

      await db.outboxDao.completeCreate(
        create.id,
        sampleTask(id: 50, title: 'New', projectId: 7),
        at: later,
      );

      final follower = (await ops()).single;
      expect(follower.taskId, 50);
      expect(decodeTaskChanges(follower.payload), reordered);
      expect(await pendingOf(50), reordered);
    });

    test('a rejected create keeps them queued behind it', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New'),
        now: now,
      );
      final create = (await ops()).single;
      await db.outboxDao.markSending(create.id, at: now);
      await queue(id, const TaskChanges(title: 'Renamed').merge(reordered));

      await db.outboxDao.markFailed(create.id, const ValidationFailed());

      final all = await ops();
      expect(decodeNewTask(all.first.payload).title, 'Renamed');
      expect(decodeTaskChanges(all.last.payload), reordered);
    });

    test('survive the labels and edges a sync forgets', () async {
      await queue(
        1,
        reordered.merge(const TaskChanges(labels: IdSetChange(added: {5}))),
      );
      await queue(
        2,
        reordered.merge(
          TaskChanges(
            relations: RelationChange(
              added: {const TaskRelationRef(TaskRelationKind.related, 3)},
            ),
          ),
        ),
      );

      await db.outboxDao.forgetLabels({5});
      await db.outboxDao.forgetRelatedTasks({3});

      expect(
        [for (final op in await ops()) decodeTaskChanges(op.payload)],
        [reordered, reordered],
      );
    });

    test('a refused one names its changes in the sync problem', () async {
      await queue(1, reordered);
      final op = (await ops()).single;
      await db.outboxDao.markSending(op.id, at: now);

      await db.outboxDao.markFailed(op.id, const Forbidden());

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.changes, reordered);
      expect(await pendingOf(1), reordered);
    });
  });

  group('description changes', () {
    const tap = TaskChanges(
      description: '<p>tapped</p>',
      descriptionBase: '',
      checklistToggles: [ChecklistToggle.byId('a', checked: true)],
    );

    test('a guarded change goes only on the description it was made '
        'from', () async {
      expect(
        await db.outboxDao.queueUpdate(1, tap, now: now, ifDescription: 'x'),
        isFalse,
      );
      expect(await ops(), isEmpty);
      expect((await db.tasksDao.find(1))!.description, '');

      expect(
        await db.outboxDao.queueUpdate(1, tap, now: now, ifDescription: ''),
        isTrue,
      );
      expect((await db.tasksDao.find(1))!.description, '<p>tapped</p>');
      expect(await pendingOf(1), tap);
    });

    test('a second guarded change made from the same description is refused '
        'once the first applied', () async {
      await db.outboxDao.queueUpdate(1, tap, now: now, ifDescription: '');

      expect(
        await db.outboxDao.queueUpdate(1, tap, now: now, ifDescription: ''),
        isFalse,
      );
      expect(decodeTaskChanges((await ops()).single.payload), tap);
    });

    test('folds into a create that has not left the device, without base '
        'and taps', () async {
      final id = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New', description: '<p>a</p>'),
        now: now,
      );

      expect(
        await db.outboxDao.queueUpdate(
          id,
          const TaskChanges(
            description: '<p>b</p>',
            descriptionBase: '<p>a</p>',
            checklistToggles: [],
          ),
          now: now,
          ifDescription: '<p>a</p>',
        ),
        isTrue,
      );

      final op = (await ops()).single;
      expect(op.kind, 'createTask');
      expect(decodeNewTask(op.payload).description, '<p>b</p>');
      expect((await db.tasksDao.findRow(id))!.pendingChanges, isNull);
    });

    test('survive the labels and edges a sync forgets', () async {
      await queue(
        1,
        tap.merge(const TaskChanges(labels: IdSetChange(added: {5}))),
      );

      await db.outboxDao.forgetLabels({5});

      expect(decodeTaskChanges((await ops()).single.payload), tap);
    });

    Future<OutboxRow> failedWith(TaskChanges changes) async {
      await queue(1, changes);
      final op = (await ops()).single;
      await db.outboxDao.markSending(op.id, at: now);
      await db.outboxDao.markFailed(op.id, const DescriptionConflict());
      return op;
    }

    test('a conflict is a problem that names it', () async {
      await failedWith(tap);

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.failure, isA<DescriptionConflict>());
      expect(problem.changes, tap);
    });

    test('Keep mine queues the change again with the web description as '
        'its base, which later changes keep', () async {
      final op = await failedWith(tap.merge(favorite));

      await db.outboxDao.retryOverwritingDescription(op.id, base: '<p>web</p>');

      final retaken = (await ops()).single;
      expect(retaken.state, OutboxState.pending.name);
      expect(retaken.lastError, isNull);
      const rebased = TaskChanges(
        description: '<p>tapped</p>',
        descriptionBase: '<p>web</p>',
        isFavorite: true,
      );
      expect(decodeTaskChanges(retaken.payload), rebased);
      expect(await pendingOf(1), rebased);
      expect(await db.outboxDao.loadProblems(), isEmpty);

      await queue(
        1,
        const TaskChanges(
          description: '<p>later</p>',
          descriptionBase: '<p>tapped</p>',
        ),
      );
      expect(
        decodeTaskChanges((await ops()).single.payload).descriptionBase,
        '<p>web</p>',
      );
    });

    test("Use the web's takes the description out of the change and queues "
        'the rest again', () async {
      final op = await failedWith(tap.merge(favorite));

      expect(await db.outboxDao.dropDescription(op.id), isTrue);

      final rest = (await ops()).single;
      expect(rest.state, OutboxState.pending.name);
      expect(decodeTaskChanges(rest.payload), favorite);
      expect(await pendingOf(1), favorite);
    });

    test(
      "Use the web's drops a change that was only the description",
      () async {
        final op = await failedWith(tap);

        expect(await db.outboxDao.dropDescription(op.id), isTrue);

        expect(await ops(), isEmpty);
        expect(await pendingOf(1), isNull);
      },
    );

    test('both leave an op alone that is no longer failed', () async {
      await queue(1, tap);
      final op = (await ops()).single;

      await db.outboxDao.retryOverwritingDescription(op.id, base: '<p>web</p>');
      expect(await db.outboxDao.dropDescription(op.id), isFalse);
      expect(await db.outboxDao.dropDescription('gone'), isFalse);

      expect(decodeTaskChanges((await ops()).single.payload), tap);
    });
  });
}
