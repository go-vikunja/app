import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

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
    test('hides the row and drops the unsent update', () async {
      await queue(1, done);

      expect(await db.outboxDao.queueDelete(1, now: now), isTrue);

      expect(await db.tasksDao.find(1), isNull);
      final row = (await db.tasksDao.findRow(1))!;
      expect(row.pendingDelete, isTrue);
      expect(row.pendingChanges, isNull);
      final op = (await ops()).single;
      expect(op.kind, OutboxOperationKind.deleteTask.name);
      expect(op.taskId, 1);
      expect((await db.tasksDao.loadOpenTasks()).map((t) => t.id), [2]);
      expect(await db.tasksDao.idsInProject(7), [2]);
      expect(await db.tasksDao.findAll([1, 2]), hasLength(1));
      // The counts mirror the server, which still holds the task.
      expect(await db.tasksDao.count(), 3);
      expect(await db.tasksDao.countInProject(7), 2);
      expect(await db.tasksDao.countNotInProjects([8]), 2);
    });

    test('is final: a second delete and later edits are refused', () async {
      await db.outboxDao.queueDelete(1, now: now);

      expect(await db.outboxDao.queueDelete(1, now: now), isFalse);
      expect(await queue(1, favorite), isFalse);
      expect(await ops(), hasLength(1));
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

  group('the queue', () {
    test('hands out the oldest pending op; failed ones are skipped', () async {
      await queue(1, done);
      await queue(2, done);
      final first = (await ops()).first;

      expect((await db.outboxDao.nextPending())!.id, first.id);

      await db.outboxDao.markFailed(first.id, const NotFound(code: 3001));
      expect((await db.outboxDao.nextPending())!.taskId, 2);

      await db.outboxDao.retry(first.id);
      final retried = (await db.outboxDao.nextPending())!;
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
      final read = (await db.outboxDao.nextPending())!;
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

    test('ops left in flight by a killed app go back to pending', () async {
      await queue(1, done);
      await db.outboxDao.markSending((await ops()).single.id, at: now);

      expect(await db.outboxDao.resetSending(), 1);

      expect((await ops()).single.state, OutboxState.pending.name);
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
}
