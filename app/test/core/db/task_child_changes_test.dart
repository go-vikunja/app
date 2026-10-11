import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

// Labels, assignees and reminders through the outbox: the local child rows
// change with the queue write, a create carries the reminders and leaves
// labels and assignees to an update behind it, the remap keeps what was
// chosen before it, and a pull keeps what is still queued.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 10, 12);
  final later = DateTime.utc(2026, 10, 10, 12, 5);
  final monday = DateTime.utc(2026, 10, 12, 9);
  final tuesday = DateTime.utc(2026, 10, 13, 9);
  final urgent = sampleLabel(id: 10, title: 'urgent');
  final home = sampleLabel(id: 11, title: 'home');
  const ana = User(id: 20, username: 'ana', name: 'Ana');
  const ben = User(id: 21, username: 'ben');
  final absolute = TaskReminder(reminder: DateTime.utc(2026, 10, 11, 18));
  const hourBeforeDue = TaskReminder(
    relativePeriod: Duration(hours: -1),
    relativeTo: ReminderRelativeTo.dueDate,
  );
  const dayAfterStart = TaskReminder(
    relativePeriod: Duration(days: 1),
    relativeTo: ReminderRelativeTo.startDate,
  );

  TaskReminder at(TaskReminder relative, DateTime? instant) => TaskReminder(
    reminder: instant,
    relativePeriod: relative.relativePeriod,
    relativeTo: relative.relativeTo,
  );

  setUp(() async {
    db = testDatabase();
    await db.labelsDao.upsertAll([urgent, home]);
    await db.usersDao.upsertAll([ana, ben]);
    await db.tasksDao.upsertAll([
      sampleTask(
        id: 1,
        title: 'One',
        projectId: 7,
        due: monday,
        labels: [urgent],
        assignees: [ana],
        reminders: [
          absolute,
          at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
        ],
      ),
      sampleTask(id: 2, title: 'Two', projectId: 7),
    ], syncRunId: 'run');
  });

  Future<bool> queue(int id, TaskChanges changes) =>
      db.outboxDao.queueUpdate(id, changes, now: now);

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  Future<Task> task(int id) async => (await db.tasksDao.find(id))!;

  Future<TaskChanges?> pendingOf(int id) async {
    final json = (await db.tasksDao.findRow(id))!.pendingChanges;
    return json == null ? null : decodeTaskChanges(json);
  }

  group('queueing', () {
    test(
      'labels are attached and detached at once and queued as a delta',
      () async {
        const changes = TaskChanges(
          labels: IdSetChange(added: {11}, removed: {10}),
        );

        expect(await queue(1, changes), isTrue);

        expect((await task(1)).labels, [home]);
        expect(await pendingOf(1), changes);
        final op = (await ops()).single;
        expect(op.kind, OutboxOperationKind.updateTask.name);
        expect(decodeTaskChanges(op.payload), changes);
      },
    );

    test('assignees likewise', () async {
      const changes = TaskChanges(
        assignees: IdSetChange(added: {21}, removed: {20}),
      );

      await queue(1, changes);

      expect((await task(1)).assignees, [ben]);
      expect(decodeTaskChanges((await ops()).single.payload), changes);
    });

    test('a label or user this device has no row for is skipped locally but '
        'still queued', () async {
      const changes = TaskChanges(
        labels: IdSetChange(added: {11, 99}),
        assignees: IdSetChange(added: {98}),
      );

      expect(await queue(2, changes), isTrue);

      expect((await task(2)).labels, [home]);
      expect((await task(2)).assignees, isEmpty);
      expect(decodeTaskChanges((await ops()).single.payload), changes);
      expect(await pendingOf(2), changes);
    });

    test('reminders replace the list; a relative one gets its instant from '
        'the date it refers to, none while that date is unset', () async {
      await queue(
        1,
        TaskChanges(reminders: [hourBeforeDue, dayAfterStart, absolute]),
      );

      expect((await task(1)).reminders, [
        at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
        at(dayAfterStart, null),
        absolute,
      ]);
      expect(decodeTaskChanges((await ops()).single.payload).reminders, [
        hourBeforeDue,
        dayAfterStart,
        absolute,
      ]);
    });

    test('an empty list removes every reminder', () async {
      await queue(1, const TaskChanges(reminders: []));

      expect((await task(1)).reminders, isEmpty);
      expect(await pendingOf(1), const TaskChanges(reminders: []));
    });

    test('a date change moves the relative reminders and leaves the absolute '
        'ones', () async {
      await queue(1, TaskChanges(dueDate: DateChange.set(tuesday)));

      expect((await task(1)).reminders, [
        absolute,
        at(hourBeforeDue, tuesday.subtract(const Duration(hours: 1))),
      ]);

      await queue(1, const TaskChanges(dueDate: DateChange.clear()));

      expect((await task(1)).reminders, [absolute, at(hourBeforeDue, null)]);
    });

    test('a date set with the reminders counts for their instants', () async {
      await queue(
        2,
        TaskChanges(
          startDate: DateChange.set(monday),
          reminders: const [dayAfterStart],
        ),
      );

      expect((await task(2)).reminders, [
        at(dayAfterStart, monday.add(const Duration(days: 1))),
      ]);
    });

    test('label changes merge per id: an add then a remove is a remove, a '
        'remove then an add an add', () async {
      await queue(2, const TaskChanges(labels: IdSetChange(added: {10})));
      await queue(2, const TaskChanges(labels: IdSetChange(removed: {10})));

      expect((await task(2)).labels, isEmpty);
      expect(
        decodeTaskChanges((await ops()).single.payload),
        const TaskChanges(labels: IdSetChange(removed: {10})),
      );

      await queue(1, const TaskChanges(labels: IdSetChange(removed: {10})));
      await queue(1, const TaskChanges(labels: IdSetChange(added: {10})));

      expect((await task(1)).labels, [urgent]);
      expect(
        decodeTaskChanges((await ops()).last.payload),
        const TaskChanges(labels: IdSetChange(added: {10})),
      );
      expect(
        await pendingOf(1),
        const TaskChanges(labels: IdSetChange(added: {10})),
      );
    });

    test('a failed label change behind a newer one folds into it, the newer '
        'intent winning per id', () async {
      await queue(
        1,
        const TaskChanges(
          labels: IdSetChange(added: {11}, removed: {10}),
        ),
      );
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await queue(
        1,
        const TaskChanges(
          labels: IdSetChange(removed: {11}),
          assignees: IdSetChange(added: {21}),
        ),
      );

      await db.outboxDao.markFailed(first.id, const NotFound(code: 8002));

      const folded = TaskChanges(
        labels: IdSetChange(removed: {10, 11}),
        assignees: IdSetChange(added: {21}),
      );
      final remaining = (await ops()).single;
      expect(remaining.id, isNot(first.id));
      expect(decodeTaskChanges(remaining.payload), folded);
      expect(await pendingOf(1), folded);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('a failed label change takes a later one and goes back to the '
        'queue', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      final op = (await ops()).single;
      await db.outboxDao.markFailed(op.id, const Forbidden());

      await queue(1, const TaskChanges(labels: IdSetChange(removed: {11})));

      final again = (await ops()).single;
      expect(again.id, op.id);
      expect(again.state, OutboxState.pending.name);
      expect(
        decodeTaskChanges(again.payload),
        const TaskChanges(labels: IdSetChange(removed: {11})),
      );
    });
  });

  // A label deleted on the server, or no longer visible, is purged by the
  // label sync; no draft can then remove it from a queued add.
  group('labels the sync purges', () {
    test('leave a failed op, which goes back to the queue with the edits '
        'merged into it', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      final op = (await ops()).single;
      await db.outboxDao.markFailed(op.id, const NotFound(code: 8002));
      await db.labelsDao.upsertAll([sampleLabel(id: 12, title: 'later')]);
      await queue(
        1,
        const TaskChanges(
          labels: IdSetChange(added: {12}),
          assignees: IdSetChange(added: {21}),
        ),
      );
      await db.outboxDao.markFailed(op.id, const NotFound(code: 8002));
      expect(await db.outboxDao.loadProblems(), hasLength(1));

      expect(await db.labelsDao.purgeNotIn([10, 12]), 1);

      const kept = TaskChanges(
        labels: IdSetChange(added: {12}),
        assignees: IdSetChange(added: {21}),
      );
      final again = (await ops()).single;
      expect(again.id, op.id);
      expect(again.state, OutboxState.pending.name);
      expect(again.attempts, 0);
      expect(again.lastError, isNull);
      expect(decodeTaskChanges(again.payload), kept);
      expect(await pendingOf(1), kept);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test(
      'an op that only changed them goes, and its problem with it',
      () async {
        await queue(1, const TaskChanges(labels: IdSetChange(removed: {10})));
        await queue(2, const TaskChanges(labels: IdSetChange(added: {11})));
        final failed = (await ops()).last;
        await db.outboxDao.markFailed(failed.id, const Forbidden());

        await db.labelsDao.purgeNotIn(const []);

        expect(await ops(), isEmpty);
        expect(await pendingOf(1), isNull);
        expect(await pendingOf(2), isNull);
        expect(await db.outboxDao.loadProblems(), isEmpty);
      },
    );

    test('leave a pending op pending and an op in flight alone', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      final sending = (await ops()).single;
      await db.outboxDao.markSending(sending.id, at: now);
      await queue(
        1,
        const TaskChanges(
          title: 'Renamed',
          labels: IdSetChange(removed: {11}),
        ),
      );

      await db.labelsDao.purgeNotIn([10]);

      final [inFlight, pending] = await ops();
      expect(inFlight.state, OutboxState.sending.name);
      expect(
        decodeTaskChanges(inFlight.payload),
        const TaskChanges(labels: IdSetChange(added: {11})),
      );
      expect(pending.state, OutboxState.pending.name);
      expect(
        decodeTaskChanges(pending.payload),
        const TaskChanges(title: 'Renamed'),
      );
      expect(
        await pendingOf(1),
        const TaskChanges(
          title: 'Renamed',
          labels: IdSetChange(added: {11}),
        ),
      );
    });
  });

  group('creates', () {
    final draft = NewTask(
      projectId: 7,
      title: 'Call back',
      dueDate: monday,
      reminders: [hourBeforeDue, absolute],
    );

    Future<int> create([NewTask? task]) =>
        db.outboxDao.queueCreate(task ?? draft, now: now);

    Future<OutboxRow> createOp(int localId) async => (await ops()).singleWhere(
      (op) => op.taskId == localId && op.kind == 'createTask',
    );

    test("a new task's reminders are stored with their instants", () async {
      final id = await create();

      expect((await task(id)).reminders, [
        at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
        absolute,
      ]);
      expect(decodeNewTask((await createOp(id)).payload), draft);
    });

    test('before the send, reminders fold into the create while labels and '
        'assignees queue behind it', () async {
      final id = await create(
        NewTask(projectId: 7, title: 'Call back', dueDate: monday),
      );

      await queue(
        id,
        const TaskChanges(
          title: 'Call Ana back',
          labels: IdSetChange(added: {10}),
          assignees: IdSetChange(added: {20}),
          reminders: [hourBeforeDue],
        ),
      );

      final all = await ops();
      expect(all.map((op) => op.kind), ['createTask', 'updateTask']);
      expect(
        decodeNewTask(all.first.payload),
        NewTask(
          projectId: 7,
          title: 'Call Ana back',
          dueDate: monday,
          reminders: const [hourBeforeDue],
        ),
      );
      const behind = TaskChanges(
        labels: IdSetChange(added: {10}),
        assignees: IdSetChange(added: {20}),
      );
      expect(all.last.taskId, id);
      expect(decodeTaskChanges(all.last.payload), behind);
      expect(await pendingOf(id), behind);
      final local = await task(id);
      expect(local.title, 'Call Ana back');
      expect(local.labels, [urgent]);
      expect(local.assignees, [ana]);
      expect(local.reminders, [
        at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
      ]);
      // The update waits for the create.
      expect((await db.outboxDao.nextPending())!.kind, 'createTask');
    });

    test('a reminder edit alone before the send is no op of its own', () async {
      final id = await create();

      await queue(id, const TaskChanges(reminders: []));

      expect((await ops()).single.kind, 'createTask');
      expect(decodeNewTask((await ops()).single.payload).reminders, isEmpty);
      expect((await task(id)).reminders, isEmpty);
      expect((await db.tasksDao.findRow(id))!.pendingChanges, isNull);
    });

    test('the remap keeps the labels and assignees chosen before it, and the '
        'update behind the create moves to the server id', () async {
      final id = await create();
      await queue(
        id,
        const TaskChanges(
          labels: IdSetChange(added: {10, 11}),
          assignees: IdSetChange(added: {21}),
        ),
      );
      final op = await createOp(id);
      final answer = sampleTask(
        id: 50,
        title: 'Call back',
        projectId: 7,
        due: monday,
        updated: later,
        reminders: [
          absolute,
          at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
        ],
      );

      await db.outboxDao.completeCreate(op.id, answer, at: later);

      expect(await db.tasksDao.findRow(id), isNull);
      final created = await task(50);
      expect(created.labels, [urgent, home]);
      expect(created.assignees, [ben]);
      expect(created.reminders, answer.reminders);
      final follower = (await ops()).single;
      expect(follower.kind, 'updateTask');
      expect(follower.taskId, 50);
      expect(
        decodeTaskChanges(follower.payload),
        const TaskChanges(
          labels: IdSetChange(added: {10, 11}),
          assignees: IdSetChange(added: {21}),
        ),
      );
      expect((await db.outboxDao.nextPending())!.id, follower.id);
    });

    test('reminders changed while the create is in flight stay on top of the '
        'answer', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await queue(id, const TaskChanges(reminders: [dayAfterStart]));

      await db.outboxDao.completeCreate(
        op.id,
        sampleTask(
          id: 50,
          title: 'Call back',
          projectId: 7,
          due: monday,
          start: monday,
          reminders: [absolute],
        ),
        at: later,
      );

      expect((await task(50)).reminders, [
        at(dayAfterStart, monday.add(const Duration(days: 1))),
      ]);
      expect(
        decodeTaskChanges((await ops()).single.payload),
        const TaskChanges(reminders: [dayAfterStart]),
      );
    });

    test('a rejected create takes the reminders queued while it was in '
        'flight; labels and assignees stay behind it', () async {
      final id = await create();
      final op = await createOp(id);
      await db.outboxDao.markSending(op.id, at: now);
      await queue(
        id,
        const TaskChanges(
          labels: IdSetChange(added: {10}),
          reminders: [dayAfterStart],
        ),
      );

      await db.outboxDao.markFailed(op.id, const Forbidden(code: 7003));

      final all = await ops();
      expect(all.map((o) => o.kind), ['createTask', 'updateTask']);
      expect(all.first.state, OutboxState.failed.name);
      expect(decodeNewTask(all.first.payload).reminders, [dayAfterStart]);
      expect(
        decodeTaskChanges(all.last.payload),
        const TaskChanges(labels: IdSetChange(added: {10})),
      );
      expect(
        await pendingOf(id),
        const TaskChanges(labels: IdSetChange(added: {10})),
      );
      expect((await task(id)).labels, [urgent]);
    });
  });

  group('sync upserts', () {
    Task incoming({
      List<Label> labels = const [],
      List<User> assignees = const [],
      List<TaskReminder> reminders = const [],
      DateTime? due,
    }) => sampleTask(
      id: 1,
      title: 'One, renamed',
      projectId: 7,
      due: due ?? monday,
      labels: labels,
      assignees: assignees,
      reminders: reminders,
      updated: later,
    );

    test(
      'queued label and assignee changes apply to the incoming sets',
      () async {
        await queue(
          1,
          const TaskChanges(
            labels: IdSetChange(added: {11, 99}, removed: {10}),
            assignees: IdSetChange(added: {21}),
          ),
        );
        final shared = sampleLabel(id: 12, title: 'shared');
        const cara = User(id: 22, username: 'cara');

        await db.tasksDao.upsertAll([
          incoming(labels: [urgent, shared], assignees: [ana, cara]),
        ], syncRunId: 'run2');

        final one = await task(1);
        expect(one.title, 'One, renamed');
        expect(one.labels, [home, shared]);
        expect(one.assignees, [ana, ben, cara]);
        expect(
          await pendingOf(1),
          const TaskChanges(
            labels: IdSetChange(added: {11, 99}, removed: {10}),
            assignees: IdSetChange(added: {21}),
          ),
        );
      },
    );

    test('queued reminders replace the incoming ones, with instants from the '
        'local dates', () async {
      await queue(
        1,
        TaskChanges(
          dueDate: DateChange.set(tuesday),
          reminders: const [hourBeforeDue],
        ),
      );

      await db.tasksDao.upsertAll([
        incoming(reminders: [absolute]),
      ]);

      final one = await task(1);
      expect(one.dueDate, tuesday);
      expect(one.reminders, [
        at(hourBeforeDue, tuesday.subtract(const Duration(hours: 1))),
      ]);
    });

    test('a queued date moves the incoming relative reminders', () async {
      await queue(1, TaskChanges(dueDate: DateChange.set(tuesday)));

      await db.tasksDao.upsertAll([
        incoming(
          reminders: [
            absolute,
            at(hourBeforeDue, monday.subtract(const Duration(hours: 1))),
          ],
        ),
      ]);

      expect((await task(1)).reminders, [
        absolute,
        at(hourBeforeDue, tuesday.subtract(const Duration(hours: 1))),
      ]);
    });

    test('a queued change of other fields leaves the incoming child rows as '
        'they come', () async {
      await queue(1, const TaskChanges(done: true));
      final server = incoming(
        labels: [home],
        assignees: [ben],
        reminders: [at(hourBeforeDue, DateTime.utc(2026, 10, 12, 7))],
      );

      await db.tasksDao.upsertAll([server]);

      final one = await task(1);
      expect(one.done, isTrue);
      expect(one.labels, [home]);
      expect(one.assignees, [ben]);
      expect(one.reminders, server.reminders);
    });

    test('an edit queued while an upsert runs is not overwritten', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(removed: {10})));

      await Future.wait([
        db.tasksDao.upsertAll([
          incoming(labels: [urgent]),
        ], syncRunId: 'run2'),
        queue(1, const TaskChanges(labels: IdSetChange(added: {11}))),
      ]);

      const both = TaskChanges(
        labels: IdSetChange(added: {11}, removed: {10}),
      );
      expect(await pendingOf(1), both);
      expect((await task(1)).labels, [home]);
    });

    test('once nothing is queued, the incoming child rows win', () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      await db.outboxDao.remove((await ops()).single.id);

      await db.tasksDao.upsertAll([
        incoming(labels: [urgent], reminders: [absolute]),
      ]);

      final one = await task(1);
      expect(one.labels, [urgent]);
      expect(one.reminders, [absolute]);
      expect((await db.tasksDao.findRow(1))!.pendingChanges, isNull);
    });

    test("the sender's apply keeps the changes of a later op", () async {
      await queue(1, const TaskChanges(labels: IdSetChange(added: {11})));
      final first = (await ops()).single;
      await db.outboxDao.markSending(first.id, at: now);
      await queue(1, const TaskChanges(assignees: IdSetChange(removed: {20})));

      // What the sender does with the answer to the first op.
      await db.transaction(() async {
        await db.outboxDao.remove(first.id);
        await db.tasksDao.upsertAll([
          incoming(labels: [urgent, home], assignees: [ana]),
        ]);
      });

      final one = await task(1);
      expect(one.labels, [urgent, home]);
      expect(one.assignees, isEmpty);
      expect(
        await pendingOf(1),
        const TaskChanges(assignees: IdSetChange(removed: {20})),
      );
    });
  });
}
