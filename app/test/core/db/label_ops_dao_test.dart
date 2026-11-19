import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/label_ops_dao.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 11, 19, 12);
  final later = DateTime.utc(2026, 11, 19, 12, 5);
  const me = User(id: 9, username: 'me', name: 'Me');
  const home = Label(id: 5, title: 'Home', createdBy: me);

  setUp(() async {
    db = testDatabase();
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'One', projectId: 7),
      sampleTask(id: 2, title: 'Two', projectId: 7, labels: const [home]),
    ], syncRunId: 'run');
  });

  Future<Label> queueLabel(String title, {bool adopt = false}) =>
      db.labelOpsDao.queueCreate(
        NewLabel(title: title, hexColor: '0072b2'),
        now: now,
        createdBy: me,
        adopt: adopt,
      );

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  Future<OutboxRow> createOp(int labelId) async =>
      (await db.labelOpsDao.createOf(labelId))!;

  Future<Set<int>> labelsOf(int taskId) async => {
    for (final label in (await db.tasksDao.find(taskId))!.labels) label.id,
  };

  Future<TaskChanges?> pendingOf(int id) async {
    final json = (await db.tasksDao.findRow(id))!.pendingChanges;
    return json == null ? null : decodeTaskChanges(json);
  }

  Future<void> attach(int taskId, IdSetChange labels) async {
    expect(
      await db.outboxDao.queueUpdate(
        taskId,
        TaskChanges(labels: labels),
        now: now,
      ),
      isTrue,
    );
  }

  Future<void> sending(int labelId) async {
    expect(
      await db.outboxDao.claim((await createOp(labelId)).id, at: now),
      isNotNull,
    );
  }

  Future<void> answer(int localId, Label server) async => await db.labelOpsDao
      .completeCreate((await createOp(localId)).id, server, at: later);

  group('a label created here', () {
    test('is stored at once under a temporary id from a counter of its own, '
        'never reused, created by the user, with its create queued', () async {
      await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New task'),
        now: now,
      );

      final errand = await queueLabel('Errand');

      expect(errand.id, -1);
      expect(errand.createdBy, me);
      final stored = (await db.labelsDao.find(-1))!;
      expect(stored.title, 'Errand');
      expect(stored.hexColor, '0072b2');
      expect(stored.createdBy, me);
      final op = (await ops()).last;
      expect(op.kind, OutboxOperationKind.createLabel.name);
      expect(op.labelId, -1);
      expect(op.taskId, 0);
      expect(op.state, OutboxState.pending.name);
      expect(
        decodeLabelCreate(op.payload),
        const QueuedLabelCreate(
          label: NewLabel(title: 'Errand', hexColor: '0072b2'),
        ),
      );
      expect(await db.outboxDao.loadPendingTaskIds(), {-1});
      expect(await db.labelOpsDao.watchPendingIds().first, {-1});

      expect(
        await db.labelOpsDao.queueDelete(-1, now: now),
        LabelQueueing.queued,
      );
      expect((await queueLabel('Errand')).id, -2);
    });

    test('remembers the server labels of exactly that title the device had '
        'and whether it may take one the server has', () async {
      await db.labelsDao.upsertAll(const [
        Label(id: 6, title: 'Errand'),
        Label(id: 7, title: 'errand'),
      ]);

      await queueLabel('Errand', adopt: true);

      final queued = decodeLabelCreate((await createOp(-1)).payload);
      expect(queued.known, {6});
      expect(queued.adopt, isTrue);
    });

    test('is an ordinary label: attached to a task it shows there, through a '
        'task update under its temporary id', () async {
      await queueLabel('Errand');

      await attach(1, const IdSetChange(added: {-1}));

      expect(await labelsOf(1), {-1});
      final update = (await ops()).last;
      expect(update.kind, OutboxOperationKind.updateTask.name);
      expect(
        decodeTaskChanges(update.payload).labels,
        const IdSetChange(added: {-1}),
      );
      expect((await pendingOf(1))!.labels, const IdSetChange(added: {-1}));
    });
  });

  group('an edit', () {
    test('folds into the create while it has not left the device, and puts '
        'a refused one back in the queue', () async {
      await queueLabel('Errand');

      final (taken, changed) = await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands', hexColor: ''),
        now: now,
      );

      expect(taken, LabelQueueing.queued);
      expect(changed!.title, 'Errands');
      expect((await db.labelsDao.find(-1))!.hexColor, '');
      final create = (await ops()).single;
      expect(
        decodeLabelCreate(create.payload).label,
        const NewLabel(title: 'Errands'),
      );

      await db.outboxDao.markFailed(
        create.id,
        const ValidationFailed(message: 'invalid'),
      );
      expect((await ops()).single.state, OutboxState.failed.name);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(description: '<p>Out</p>'),
        now: now,
      );

      final retaken = (await ops()).single;
      expect(retaken.state, OutboxState.pending.name);
      expect(retaken.lastError, isNull);
      expect(
        decodeLabelCreate(retaken.payload).label,
        const NewLabel(title: 'Errands', description: '<p>Out</p>'),
      );
    });

    test('queues behind a create that may be on the server, merged, and '
        'follows the remap, staying on the stored label', () async {
      await queueLabel('Errand');
      await sending(-1);

      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(hexColor: 'e69f00'),
        now: now,
      );

      final [create, edit] = await ops();
      expect(create.kind, OutboxOperationKind.createLabel.name);
      expect(decodeLabelCreate(create.payload).label.title, 'Errand');
      expect(edit.kind, OutboxOperationKind.updateLabel.name);
      expect(edit.labelId, -1);
      expect(
        decodeLabelChanges(edit.payload),
        const LabelChanges(title: 'Errands', hexColor: 'e69f00'),
      );
      expect((await db.labelsDao.find(-1))!.title, 'Errands');

      await answer(-1, const Label(id: 50, title: 'Errand'));

      final followed = (await ops()).single;
      expect(followed.labelId, 50);
      final stored = (await db.labelsDao.find(50))!;
      expect(stored.title, 'Errands');
      expect(stored.hexColor, 'e69f00');
      expect(stored.createdBy, me);
    });

    test('folded with a new title also counts the labels the device has of '
        'that title as known, which a lost answer never takes', () async {
      await db.labelsDao.upsertAll(const [
        Label(id: 6, title: 'Errands'),
        Label(id: 7, title: 'errands'),
      ]);
      await queueLabel('Errand');
      expect(decodeLabelCreate((await createOp(-1)).payload).known, isEmpty);

      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );

      final queued = decodeLabelCreate((await createOp(-1)).payload);
      expect(queued.label.title, 'Errands');
      expect(queued.known, {6});
    });

    test('of a label from findOrCreate is never folded into its create: it '
        'queues behind it and goes to the label the create gets', () async {
      await queueLabel('Errand', adopt: true);

      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(hexColor: 'e69f00'),
        now: now,
      );
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(description: '<p>Out</p>'),
        now: now,
      );

      final [create, edit] = await ops();
      expect(
        decodeLabelCreate(create.payload).label,
        const NewLabel(title: 'Errand', hexColor: '0072b2'),
      );
      expect(edit.kind, OutboxOperationKind.updateLabel.name);
      expect(edit.labelId, -1);
      expect(
        decodeLabelChanges(edit.payload),
        const LabelChanges(hexColor: 'e69f00', description: '<p>Out</p>'),
      );
      expect((await db.labelsDao.find(-1))!.hexColor, 'e69f00');

      await answer(
        -1,
        const Label(id: 40, title: 'Errand', hexColor: '000000'),
      );

      final moved = (await ops()).single;
      expect(moved.id, edit.id);
      expect(moved.labelId, 40);
      final stored = (await db.labelsDao.find(40))!;
      expect(stored.hexColor, 'e69f00');
      expect(stored.description, '<p>Out</p>');
    });

    test('of a label from findOrCreate stays queued behind its refused '
        'create', () async {
      await queueLabel('Errand', adopt: true);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(hexColor: 'e69f00'),
        now: now,
      );
      final [create, edit] = await ops();

      await db.outboxDao.markFailed(
        create.id,
        const ValidationFailed(message: 'invalid'),
      );

      expect((await ops()).map((op) => op.id), [create.id, edit.id]);
      expect(
        decodeLabelCreate((await createOp(-1)).payload).label.hexColor,
        '0072b2',
      );
      expect(
        (await db.outboxDao.find(edit.id))!.state,
        OutboxState.pending.name,
      );
    });

    test('of a server label goes online unless something of it is '
        'queued', () async {
      await db.labelsDao.upsertAll(const [home]);

      final (taken, label) = await db.labelOpsDao.queueUpdate(
        5,
        const LabelChanges(title: 'House'),
        now: now,
      );

      expect(taken, LabelQueueing.online);
      expect(label, isNull);
      expect(await ops(), isEmpty);
      expect((await db.labelsDao.find(5))!.title, 'Home');
    });

    test('of a label created here that is gone finds nothing', () async {
      final (taken, _) = await db.labelOpsDao.queueUpdate(
        -7,
        const LabelChanges(title: 'x'),
        now: now,
      );

      expect(taken, LabelQueueing.gone);
    });
  });

  group('a delete', () {
    test('of a create that never left the device drops the create, the row, '
        'its place on tasks and its queued adds, without a request', () async {
      await queueLabel('Errand');
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(
          title: 'One more',
          labels: IdSetChange(added: {-1}),
        ),
        now: now,
      );
      await attach(2, const IdSetChange(added: {-1}));
      expect(await labelsOf(2), {5, -1});

      expect(
        await db.labelOpsDao.queueDelete(-1, now: now),
        LabelQueueing.queued,
      );

      final remaining = await ops();
      expect(remaining.map((op) => op.kind), [
        OutboxOperationKind.updateTask.name,
      ]);
      expect(
        decodeTaskChanges(remaining.single.payload),
        const TaskChanges(title: 'One more'),
      );
      expect(await db.labelsDao.find(-1), isNull);
      expect(await labelsOf(1), isEmpty);
      expect(await labelsOf(2), {5});
      expect(await pendingOf(2), isNull);
    });

    test('of a create in flight queues behind it; the label leaves the tasks '
        'and the queued edits at once, and is never stored again', () async {
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );

      expect(
        await db.labelOpsDao.queueDelete(-1, now: now),
        LabelQueueing.queued,
      );

      final [create, delete] = await ops();
      expect(create.kind, OutboxOperationKind.createLabel.name);
      expect(delete.kind, OutboxOperationKind.deleteLabel.name);
      expect(delete.labelId, -1);
      expect(await db.labelsDao.find(-1), isNull);
      expect(await labelsOf(1), isEmpty);

      // The sync pulled the label meanwhile.
      await db.labelsDao.storeRows(const [Label(id: 50, title: 'Errand')]);
      await answer(-1, const Label(id: 50, title: 'Errand'));

      expect((await ops()).single.labelId, 50);
      expect(await db.labelsDao.find(50), isNull);
      expect(await db.labelsDao.resolveId(-1), 50);
      await db.labelsDao.upsertAll(const [Label(id: 50, title: 'Errand')]);
      expect(await db.labelsDao.find(50), isNull);
    });

    test('of a create sent without an answer, or given up, that is not on '
        'its way drops it at once with its row, its queued edits and adds, '
        'without a request: no sync problem stays', () async {
      await queueLabel('Errand');
      await queueLabel('Chores');
      await attach(1, const IdSetChange(added: {-1, -2}));
      final unanswered = await createOp(-1);
      await db.outboxDao.markUncertain(unanswered.id, sentAt: now);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      final givenUp = await createOp(-2);
      await db.outboxDao.markUncertain(givenUp.id, sentAt: now);
      await db.outboxDao.markGivenUp(givenUp.id, const ServerFailure(502));
      expect((await ops()).map((op) => (op.kind, op.labelId)), [
        (OutboxOperationKind.createLabel.name, -1),
        (OutboxOperationKind.createLabel.name, -2),
        (OutboxOperationKind.updateTask.name, null),
        (OutboxOperationKind.updateLabel.name, -1),
      ]);
      expect(await db.outboxDao.loadProblems(), hasLength(1));

      for (final id in [-1, -2]) {
        expect(
          await db.labelOpsDao.queueDelete(id, now: now),
          LabelQueueing.queued,
        );
      }

      expect(await ops(), isEmpty);
      expect(await db.outboxDao.loadProblems(), isEmpty);
      expect(await db.labelsDao.find(-1), isNull);
      expect(await db.labelsDao.find(-2), isNull);
      expect(await labelsOf(1), isEmpty);
      expect(await pendingOf(1), isNull);
    });

    test('keeps the title and the tasks the server has the label on: not '
        'one it was only added to here, and one it was removed from here; '
        'a discard gives the label back to those', () async {
      await queueLabel('Errand');
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(hexColor: 'e69f00'),
        now: now,
      );
      const errand = Label(id: 50, title: 'Errand');
      await answer(-1, errand);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'One', projectId: 7, labels: const [errand]),
        sampleTask(
          id: 2,
          title: 'Two',
          projectId: 7,
          labels: const [home, errand],
        ),
        sampleTask(id: 3, title: 'Three', projectId: 7),
      ], syncRunId: 'run 2');
      await attach(2, const IdSetChange(removed: {50}));
      await attach(3, const IdSetChange(added: {50}));
      expect(await labelsOf(3), {50});

      expect(
        await db.labelOpsDao.queueDelete(50, now: now),
        LabelQueueing.queued,
      );

      final delete = (await ops()).singleWhere(
        (op) => op.kind == OutboxOperationKind.deleteLabel.name,
      );
      final queued = decodeLabelDelete(delete.payload);
      expect(queued.title, 'Errand');
      expect(queued.taskIds, {1, 2});
      expect(await labelsOf(1), isEmpty);

      await db.outboxDao.markFailed(delete.id, const Forbidden());
      await db.labelOpsDao.completeUpdate(
        (await db.outboxDao.find(delete.id))!,
        errand,
      );

      expect(await db.labelsDao.find(50), isNotNull);
      expect(await labelsOf(1), {50});
      expect(await labelsOf(2), {5, 50});
      expect(await labelsOf(3), isEmpty);
    });

    test('of a label created here keeps no task: the server has it on '
        'none', () async {
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      await sending(-1);

      await db.labelOpsDao.queueDelete(-1, now: now);

      final delete = (await ops()).last;
      expect(decodeLabelDelete(delete.payload).title, 'Errand');
      expect(decodeLabelDelete(delete.payload).taskIds, isEmpty);
    });

    test('of a server label goes online unless something of it is '
        'queued', () async {
      await db.labelsDao.upsertAll(const [home]);

      expect(
        await db.labelOpsDao.queueDelete(5, now: now),
        LabelQueueing.online,
      );
      expect(await db.labelsDao.find(5), isNotNull);
    });
  });

  group('the answered create', () {
    test('moves the row, its tasks, every queued task edit and the pending '
        'changes to the server id, and records the remap', () async {
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      await attach(2, const IdSetChange(added: {-1}));
      await attach(2, const IdSetChange(removed: {-1}));

      await answer(-1, const Label(id: 50, title: 'Errand'));

      expect(await labelsOf(1), {50});
      expect(await labelsOf(2), {5});
      final [one, two] = await ops();
      expect(
        decodeTaskChanges(one.payload).labels,
        const IdSetChange(added: {50}),
      );
      expect(
        decodeTaskChanges(two.payload).labels,
        const IdSetChange(removed: {50}),
      );
      expect((await pendingOf(1))!.labels, const IdSetChange(added: {50}));
      expect((await pendingOf(2))!.labels, const IdSetChange(removed: {50}));
      expect(await db.labelsDao.find(-1), isNull);
      final stored = (await db.labelsDao.find(50))!;
      expect(stored.title, 'Errand');
      expect(stored.createdBy, me);
      expect(await db.labelsDao.resolveId(-1), 50);
      expect(await db.labelsDao.watchRemaps().first, {-1: 50});
      expect(await db.labelsDao.remappedServerIds(), {50});

      // An edit addressed to the temporary id follows it.
      await attach(1, const IdSetChange(removed: {-1}));
      expect(await labelsOf(1), isEmpty);
      expect(
        decodeTaskChanges((await ops()).first.payload).labels,
        const IdSetChange(removed: {50}),
      );
    });

    test('with a label the sync stored meanwhile merges into it', () async {
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      const pulled = Label(id: 50, title: 'Errand', hexColor: '0072b2');
      await db.tasksDao.upsertAll([
        sampleTask(id: 2, title: 'Two', projectId: 7, labels: const [pulled]),
      ], syncRunId: 'run');

      await answer(-1, pulled);

      expect(await labelsOf(1), {50});
      expect(await labelsOf(2), {50});
      expect(
        [
          for (final label in await db.labelsDao.loadAll())
            if (label.title == 'Errand') label.id,
        ],
        [50],
      );
    });

    test('of a label a task swapped for its twin the sync brought keeps the '
        'twin on the task, here and in the queued edit', () async {
      const twin = Label(id: 50, title: 'Errand');
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 2,
          title: 'Two',
          projectId: 7,
          labels: const [home, twin],
        ),
      ], syncRunId: 'run 2');
      await attach(1, const IdSetChange(added: {50}, removed: {-1}));
      await attach(2, const IdSetChange(added: {-1}, removed: {50}));
      expect(await labelsOf(1), {50});
      expect(await labelsOf(2), {5, -1});

      await answer(-1, twin);

      final [one, two] = await ops();
      expect(one.taskId, 1);
      expect(
        decodeTaskChanges(one.payload).labels,
        const IdSetChange(added: {50}),
      );
      expect(two.taskId, 2);
      expect(
        decodeTaskChanges(two.payload).labels,
        const IdSetChange(added: {50}),
      );
      expect((await pendingOf(1))!.labels, const IdSetChange(added: {50}));
      expect(await labelsOf(1), {50});
      expect(await labelsOf(2), {5, 50});
    });

    test('taken by its title from the server with a delete queued leaves that '
        'label alone and goes with its own', () async {
      await queueLabel('Errand', adopt: true);
      await attach(1, const IdSetChange(added: {-1}));
      await sending(-1);
      await db.labelOpsDao.queueDelete(-1, now: now);

      await db.labelOpsDao.completeCreate(
        (await createOp(-1)).id,
        const Label(id: 40, title: 'Errand'),
        at: later,
        takenByTitle: true,
      );

      expect(await ops(), isEmpty);
      expect(await db.labelsDao.resolveId(-1), -1);
      expect(await db.labelsDao.find(40), isNull);
      expect(await labelsOf(1), isEmpty);
    });

    test('taken by its title from the server, a label whose own delete is '
        'queued, stays on its tasks: only a delete of the temporary id drops '
        'it', () async {
      await db.labelsDao.upsertAll(const [Label(id: 40, title: 'Errand')]);
      await db.outboxDao.queueLabelOp(
        kind: OutboxOperationKind.updateLabel,
        labelId: 40,
        payload: encodeLabelChanges(const LabelChanges(hexColor: 'e69f00')),
        now: now,
      );
      await db.labelOpsDao.queueDelete(40, now: now);
      await queueLabel('Errand', adopt: true);
      await attach(1, const IdSetChange(added: {-1}));

      await db.labelOpsDao.completeCreate(
        (await createOp(-1)).id,
        const Label(id: 40, title: 'Errand'),
        at: later,
        takenByTitle: true,
      );

      expect(await db.labelsDao.resolveId(-1), 40);
      expect(await labelsOf(1), {40});
      expect(
        (await ops()).map((op) => (op.kind, op.labelId)),
        contains((OutboxOperationKind.deleteLabel.name, 40)),
      );
    });

    test('of a label a task created here carries in its update reaches that '
        'update, whichever create is answered first', () async {
      final taskId = await db.outboxDao.queueCreate(
        const NewTask(projectId: 7, title: 'New task'),
        now: now,
      );
      await queueLabel('Errand');
      await attach(taskId, const IdSetChange(added: {-1}));
      expect(await labelsOf(taskId), {-1});

      await answer(-1, const Label(id: 50, title: 'Errand'));

      final update = (await ops()).last;
      expect(update.taskId, taskId);
      expect(
        decodeTaskChanges(update.payload).labels,
        const IdSetChange(added: {50}),
      );
      expect(await labelsOf(taskId), {50});
    });
  });

  group('the queue', () {
    test('holds back a task update that names a label whose create is '
        "queued, also one queued before it, and the task's later ops; "
        'others go', () async {
      await db.outboxDao.queueUpdate(
        1,
        const TaskChanges(title: 'One more'),
        now: now,
      );
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));
      expect(await db.outboxDao.queueDelete(1, now: now), TaskDeletion.queued);
      await db.outboxDao.queueUpdate(
        2,
        const TaskChanges(isFavorite: true),
        now: now,
      );
      final [update, create, delete, other] = await ops();
      expect(decodeTaskChanges(update.payload).labels!.added, {-1});

      expect((await db.outboxDao.nextInLine())!.id, create.id);

      await db.outboxDao.markFailed(
        create.id,
        const ValidationFailed(message: 'invalid'),
      );
      expect((await db.outboxDao.nextInLine())!.id, other.id);

      await db.labelOpsDao.cancelCreate(-1);
      final next = (await db.outboxDao.nextInLine())!;
      expect(next.id, update.id);
      expect(
        decodeTaskChanges(next.payload),
        const TaskChanges(title: 'One more'),
      );
      expect(await db.outboxDao.find(delete.id), isNotNull);
    });

    test("holds a label's edit under its temporary id behind the create, "
        'which blocks while in flight', () async {
      await queueLabel('Errand');
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      final [create, edit] = await ops();

      expect((await db.outboxDao.nextInLine())!.id, create.id);
      await db.outboxDao.unclaim(create.id);
      expect((await db.outboxDao.nextInLine())!.id, create.id);

      await answer(-1, const Label(id: 50, title: 'Errand'));
      expect((await db.outboxDao.nextInLine())!.id, edit.id);
    });
  });

  group('a failure', () {
    test('of a create keeps the label as a sync problem named by it, which '
        'takes the edits queued behind it while in flight', () async {
      await queueLabel('Errand');
      final create = await createOp(-1);
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      await db.outboxDao.markUncertain(create.id, sentAt: now);

      await db.outboxDao.markFailed(
        create.id,
        const ValidationFailed(message: 'invalid'),
      );

      final failed = (await ops()).single;
      expect(failed.state, OutboxState.failed.name);
      expect(failed.sentAt, isNull);
      expect(decodeLabelCreate(failed.payload).label.title, 'Errands');
      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.kind, OutboxOperationKind.createLabel);
      expect(problem.taskTitle, 'Errands');
      expect(problem.labelId, -1);
      expect(problem.taskId, 0);
      expect((await db.labelsDao.find(-1))!.title, 'Errands');
    });

    test('of a create with a delete queued behind it takes the label '
        'along', () async {
      await queueLabel('Errand');
      final create = await createOp(-1);
      await sending(-1);
      await db.labelOpsDao.queueDelete(-1, now: now);

      await db.outboxDao.markFailed(create.id, const Forbidden());

      expect(await ops(), isEmpty);
      expect(await db.outboxDao.loadProblems(), isEmpty);
    });

    test('of a create given up after an attempt that may have reached the '
        'server keeps that mark, so its Retry looks first', () async {
      await queueLabel('Errand');
      final create = await createOp(-1);
      await db.outboxDao.markUncertain(create.id, sentAt: now);

      await db.outboxDao.markGivenUp(create.id, const ServerFailure(502));

      final failed = (await ops()).single;
      expect(failed.state, OutboxState.failed.name);
      expect(failed.sentAt, now);
    });

    test('of an edit folds into a newer one of the label, and a newer delete '
        'makes it moot', () async {
      await queueLabel('Errand');
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      await answer(-1, const Label(id: 50, title: 'Errand'));
      final first = (await ops()).single;
      await db.outboxDao.claim(first.id, at: now);
      await db.labelOpsDao.queueUpdate(
        50,
        const LabelChanges(hexColor: 'e69f00'),
        now: now,
      );

      await db.outboxDao.markFailed(first.id, const ServerFailure(500));

      final newer = (await ops()).single;
      expect(newer.id, isNot(first.id));
      expect(
        decodeLabelChanges(newer.payload),
        const LabelChanges(title: 'Errands', hexColor: 'e69f00'),
      );

      await db.outboxDao.claim(newer.id, at: now);
      await db.labelOpsDao.queueDelete(50, now: now);
      await db.outboxDao.markFailed(newer.id, const Forbidden());
      expect((await ops()).map((op) => op.kind), [
        OutboxOperationKind.deleteLabel.name,
      ]);
    });

    test('of a delete, or of an edit whose label is gone here, names the '
        'label by the title it had', () async {
      await queueLabel('Errand');
      await sending(-1);
      await db.labelOpsDao.queueDelete(-1, now: now);
      await answer(-1, const Label(id: 50, title: 'Errand'));
      final delete = (await ops()).single;
      await db.outboxDao.markFailed(delete.id, const Forbidden());
      await queueLabel('Chores');
      await sending(-2);
      await db.labelOpsDao.queueUpdate(
        -2,
        const LabelChanges(title: 'House chores'),
        now: now,
      );
      await answer(-2, const Label(id: 51, title: 'Chores'));
      final edit = (await ops()).last;
      await db.outboxDao.markFailed(edit.id, const Forbidden());
      await (db.delete(db.labels)..where((l) => l.id.equals(51))).go();

      final problems = await db.outboxDao.loadProblems();

      expect(
        [for (final problem in problems) (problem.kind, problem.taskTitle)],
        [
          (OutboxOperationKind.deleteLabel, 'Errand'),
          (OutboxOperationKind.updateLabel, 'House chores'),
        ],
      );
    });

    test('a kill while a create is on its way marks it uncertain', () async {
      await queueLabel('Errand');
      await sending(-1);

      await db.outboxDao.resetSending(now: later);

      final reset = (await ops()).single;
      expect(reset.state, OutboxState.pending.name);
      expect(reset.sentAt, now);
    });
  });

  group('the sync', () {
    test('never purges or overwrites a label created here and keeps it on '
        'its tasks', () async {
      await queueLabel('Errand');
      await attach(1, const IdSetChange(added: {-1}));

      await db.labelsDao.upsertAll(const [home]);
      await db.labelsDao.purgeNotIn([5]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: 'One', projectId: 7),
      ], syncRunId: 'run 2');

      expect((await db.labelsDao.find(-1))!.title, 'Errand');
      expect(await labelsOf(1), {-1});
      expect(decodeTaskChanges((await ops()).last.payload).labels!.added, {-1});
    });

    test("keeps a label a create of this device got while the run's read "
        'was under way', () async {
      final before = await db.labelsDao.remappedServerIds();
      await queueLabel('Errand');
      await answer(-1, const Label(id: 50, title: 'Errand'));

      await db.labelsDao.purgeNotIn([5], remappedBefore: before);
      expect(await db.labelsDao.find(50), isNotNull);

      await db.labelsDao.purgeNotIn([
        5,
      ], remappedBefore: await db.labelsDao.remappedServerIds());
      expect(await db.labelsDao.find(50), isNull);
    });

    test('stores a server label under the edits still queued for it, and '
        'leaves out one whose delete is queued, also from its tasks', () async {
      await queueLabel('Errand');
      await sending(-1);
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      await answer(-1, const Label(id: 50, title: 'Errand'));
      await queueLabel('Gone');
      await sending(-2);
      await db.labelOpsDao.queueDelete(-2, now: now);
      await answer(-2, const Label(id: 51, title: 'Gone'));

      await db.labelsDao.upsertAll(const [
        Label(id: 50, title: 'Errand', hexColor: 'e69f00'),
        Label(id: 51, title: 'Gone'),
      ]);
      await db.tasksDao.upsertAll([
        sampleTask(
          id: 1,
          title: 'One',
          projectId: 7,
          labels: const [
            Label(id: 50, title: 'Errand'),
            Label(id: 51, title: 'Gone'),
          ],
        ),
      ], syncRunId: 'run 2');

      final stored = (await db.labelsDao.find(50))!;
      expect(stored.title, 'Errands');
      expect(stored.hexColor, isEmpty);
      expect(await db.labelsDao.find(51), isNull);
      expect(await labelsOf(1), {50});
    });
  });
}
