import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/label_op_json.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

// Labels created on the device go through the outbox like tasks: these
// cover the order with task edits, the lost answer, refusals and edits or
// deletes queued behind a create.
void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late RecordingSyncEngine sync;
  late DateTime now;
  const me = User(id: 5, username: 'me');
  const ana = User(id: 6, username: 'ana');
  final tasks = [
    sampleTask(id: 1, title: 'One', projectId: 7),
    sampleTask(id: 2, title: 'Two', projectId: 7),
  ];

  OutboxSender sender({
    int? userId,
    bool headless = false,
    int? processId,
    DateTime Function()? clock,
  }) {
    final sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: clock ?? () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
      currentUserId: () => userId,
      headless: headless,
      processId: processId,
    );
    addTearDown(sender.dispose);
    return sender;
  }

  Future<Label> queueLabel(String title, {bool adopt = false}) =>
      db.labelOpsDao.queueCreate(
        NewLabel(title: title, hexColor: '0072b2'),
        now: now,
        createdBy: me,
        adopt: adopt,
      );

  Future<void> queue(int taskId, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(taskId, changes, now: now), isTrue);
  }

  Future<Set<int>> labelsOf(int taskId) async => {
    for (final label in (await db.tasksDao.find(taskId))!.labels) label.id,
  };

  Set<int> serverLabelsOf(int taskId) => {
    for (final label in write.serverTasks[taskId]!.labels) label.id,
  };

  /// The server stores the label, then the answer is lost.
  void loseCreateAnswers() {
    write.afterRequest = (request) async {
      if (!request.startsWith('create label')) return;
      read.allLabels = [
        for (final label in write.serverLabels.values)
          Label(
            id: label.id,
            title: label.title,
            hexColor: label.hexColor,
            createdBy: me,
            created: label.created,
          ),
      ];
      throw const NetworkFailure(NetworkProblem.timeout);
    };
  }

  setUp(() async {
    db = testDatabase();
    now = DateTime.utc(2026, 11, 19, 12);
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    sync = RecordingSyncEngine();
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    write.serverTasks.addEntries(tasks.map((t) => MapEntry(t.id, t)));
  });

  test('a label created offline goes first once online, then the task '
      'update that attaches it, under the server id; the row and the task '
      'follow', () async {
    write.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    final outbox = sender();
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));

    await outbox.drain();

    expect(write.requests, ['create label Errand']);
    expect(await labelsOf(1), {-1});
    expect((await db.outboxDao.all()).first.sentAt, now);

    write.beforeRequest = null;
    expect(await outbox.sendNow(), isNull);

    expect(read.requests, ['labels page 1 search Errand']);
    expect(write.requests, [
      'create label Errand',
      'create label Errand',
      'update 1',
    ]);
    expect(serverLabelsOf(1), {900});
    expect(write.serverLabels[900]!.hexColor, '0072b2');
    expect(await db.outboxDao.count(), 0);
    expect(await labelsOf(1), {900});
    expect(await db.labelsDao.find(-1), isNull);
    expect(await db.labelsDao.find(900), isNotNull);
    expect(await db.labelsDao.resolveId(-1), 900);
    expect(sync.refreshAfterWriteCalls, 1);
  });

  test("a task's update queued before the label's create waits for it and "
      'goes after it, under the server id; other tasks go in order', () async {
    await queue(1, const TaskChanges(title: 'One more'));
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));
    await queue(2, const TaskChanges(isFavorite: true));

    await sender().drain();

    expect(write.requests, ['create label Errand', 'update 1', 'update 2']);
    expect(write.serverTasks[1]!.title, 'One more');
    expect(serverLabelsOf(1), {900});
    expect(await db.outboxDao.count(), 0);
  });

  test('a task created offline with a new label: the task, the label, then '
      'the update that attaches it', () async {
    final taskId = await db.outboxDao.queueCreate(
      const NewTask(projectId: 7, title: 'New task'),
      now: now,
    );
    await queueLabel('Errand');
    await queue(taskId, const TaskChanges(labels: IdSetChange(added: {-1})));

    await sender().drain();

    expect(write.requests, [
      'create New task',
      'create label Errand',
      'update 100',
    ]);
    expect(serverLabelsOf(100), {900});
    expect(await labelsOf(100), {900});
  });

  test('a create whose answer was lost is looked for before the next '
      'attempt and adopted: the server has the label once', () async {
    loseCreateAnswers();
    final outbox = sender();
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));

    await outbox.drain();
    expect(write.requests, ['create label Errand']);
    final waiting = (await db.outboxDao.all()).first;
    expect(waiting.sentAt, now);
    expect(waiting.state, OutboxState.pending.name);

    write.afterRequest = null;
    await outbox.sendNow();

    expect(write.requests, ['create label Errand', 'update 1']);
    expect(write.serverLabels.keys, [900]);
    expect(serverLabelsOf(1), {900});
    expect(await labelsOf(1), {900});
  });

  test('the lookup takes the newest label of exactly that title by this '
      'user, created inside the window, that the device did not have when '
      'it was created and no other create took', () async {
    Label mine(int id, String title, Duration ago) =>
        Label(id: id, title: title, createdBy: me, created: now.subtract(ago));
    // Another create of this device got 36; the label is gone here.
    await queueLabel('Errand');
    await db.labelOpsDao.completeCreate(
      (await db.labelOpsDao.createOf(-1))!.id,
      mine(36, 'Errand', Duration.zero),
      at: now,
    );
    await db.labelsDao.remove(36);
    await db.labelsDao.upsertAll([mine(38, 'Errand', Duration.zero)]);
    await queueLabel('Errand');
    final create = (await db.labelOpsDao.createOf(-2))!;
    await db.labelOpsDao.markCreatePosted(create.id, at: now);
    await db.outboxDao.markUncertain(create.id, sentAt: now);
    // Each one passed over has a higher id than the one taken.
    read.allLabels = [
      mine(34, 'Errand', const Duration(minutes: 30)),
      mine(35, 'Errand', const Duration(minutes: 50)),
      mine(36, 'Errand', Duration.zero),
      mine(38, 'Errand', Duration.zero),
      Label(id: 39, title: 'Errand', createdBy: ana, created: now),
      mine(40, 'errand', Duration.zero),
      mine(41, 'Errand', const Duration(hours: 2)),
      mine(42, 'Errand run', Duration.zero),
    ];

    await sender(userId: me.id).drain();

    expect(write.requests, isEmpty);
    expect(await db.labelsDao.resolveId(-2), 35);
    expect(await db.labelsDao.find(35), isNotNull);
  });

  test('a label the sync stored after the lost answer is still the one the '
      'create made: adopted and merged, not made twice', () async {
    loseCreateAnswers();
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));
    await outbox.drain();
    write.afterRequest = null;
    await db.labelsDao.upsertAll([read.allLabels.single]);
    expect(
      (await db.labelsDao.loadAll()).map((label) => label.id),
      unorderedEquals([-1, 900]),
    );

    await outbox.sendNow();

    expect(write.serverLabels.keys, [900]);
    expect((await db.labelsDao.loadAll()).map((label) => label.id), [900]);
    expect(await labelsOf(1), {900});
  });

  test("another member's label of that title is no answer: the create is "
      'sent again', () async {
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    final create = (await db.labelOpsDao.createOf(-1))!;
    await db.labelOpsDao.markCreatePosted(create.id, at: now);
    await db.outboxDao.markUncertain(create.id, sentAt: now);
    read.allLabels = [
      Label(id: 31, title: 'Errand', createdBy: ana, created: now),
    ];

    await outbox.drain();

    expect(read.requests, ['labels page 1 search Errand']);
    expect(write.requests, ['create label Errand']);
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test('from findOrCreate a label the server has under that title, ignoring '
      'case, is taken without a create; the same case first', () async {
    read.allLabels = [
      const Label(id: 40, title: 'einkaufen'),
      const Label(id: 41, title: 'Einkauf'),
      const Label(id: 42, title: 'einkauf'),
    ];
    await queueLabel('einkauf', adopt: true);
    await queueLabel('EINKAUF', adopt: true);

    await sender().drain();

    expect(write.requests, isEmpty);
    expect(await db.labelsDao.resolveId(-1), 42);
    expect(await db.labelsDao.resolveId(-2), 41);
  });

  test('a refused create is a sync problem naming the label; the edits that '
      'need it wait, others go; Discard drops it from its tasks and the '
      'queued edits, and what waited goes', () async {
    write.beforeRequest = (request) async {
      if (request.startsWith('create label')) {
        throw const ValidationFailed(message: 'invalid');
      }
    };
    final outbox = sender();
    await queueLabel('Errand');
    await queue(
      1,
      const TaskChanges(
        title: 'One more',
        labels: IdSetChange(added: {-1}),
      ),
    );
    await queue(2, const TaskChanges(isFavorite: true));

    await outbox.drain();

    expect(write.requests, ['create label Errand', 'update 2']);
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.kind, OutboxOperationKind.createLabel);
    expect(problem.taskTitle, 'Errand');
    expect(problem.labelId, -1);
    expect(await labelsOf(1), {-1});
    expect(await db.outboxDao.count(), 2);

    await outbox.discard(problem.operationId);
    await outbox.drain();

    expect(write.requests, ['create label Errand', 'update 2', 'update 1']);
    expect(write.serverTasks[1]!.title, 'One more');
    expect(serverLabelsOf(1), isEmpty);
    expect(await db.labelsDao.find(-1), isNull);
    expect(await labelsOf(1), isEmpty);
    expect(await db.outboxDao.count(), 0);
  });

  test('Retry sends a refused create again, then what waited', () async {
    write.beforeRequest = (request) async {
      if (request.startsWith('create label')) {
        throw const DomainError(400, code: 8001, message: 'refused');
      }
    };
    final outbox = sender();
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));
    await outbox.drain();
    final problem = (await db.outboxDao.loadProblems()).single;

    write.beforeRequest = null;
    await outbox.retry(problem.operationId);

    expect(write.requests, [
      'create label Errand',
      'create label Errand',
      'update 1',
    ]);
    expect(serverLabelsOf(1), {900});
  });

  test('an edit while the create is on its way goes after it, to the server '
      'id', () async {
    final gate = RequestGate()..pattern = 'create label';
    write.beforeRequest = gate.call;
    final outbox = sender();
    await queueLabel('Errand');
    final draining = outbox.drain();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }

    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(title: 'Errands'),
      now: now,
    );
    gate.release();
    await draining;
    await outbox.drain();

    expect(write.requests, [
      'create label Errand',
      'update label 900 LabelChanges(title)',
    ]);
    expect(write.serverLabels[900]!.title, 'Errands');
    expect((await db.labelsDao.find(900))!.title, 'Errands');
    expect(await db.outboxDao.count(), 0);
  });

  test('a delete while the create is on its way deletes the label once it '
      'is created', () async {
    final gate = RequestGate()..pattern = 'create label';
    write.beforeRequest = gate.call;
    final outbox = sender();
    await queueLabel('Errand');
    final draining = outbox.drain();
    while (!gate.isHolding) {
      await pumpEventQueue();
    }

    await db.labelOpsDao.queueDelete(-1, now: now);
    gate.release();
    await draining;
    await outbox.drain();

    expect(write.requests, ['create label Errand', 'delete label 900']);
    expect(write.serverLabels, isEmpty);
    expect(await db.labelsDao.loadAll(), isEmpty);
    expect(await db.outboxDao.count(), 0);
  });

  test('a delete of a create without an answer goes with it, without a '
      'lookup or a request: a label of that title made on the web meanwhile '
      'stays on its tasks', () async {
    write.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    await outbox.drain();
    expect((await db.outboxDao.all()).single.sentAt, now);
    await db.labelOpsDao.queueDelete(-1, now: now);
    now = now.add(const Duration(minutes: 30));
    final web = Label(id: 950, title: 'Errand', createdBy: me, created: now);
    write.serverLabels[950] = web;
    write.serverTasks[2] = write.serverTasks[2]!.copyWith(labels: [web]);
    read.allLabels = [web];

    write.beforeRequest = null;
    await outbox.sendNow();

    expect(write.requests, ['create label Errand']);
    expect(read.requests, isEmpty);
    expect(await db.outboxDao.count(), 0);
    expect(write.serverLabels.keys, [950]);
    expect(serverLabelsOf(2), {950});
  });

  test('a rename queued behind a create without an answer goes to the label '
      'the create makes, not to one of that title made on the web hours '
      'later', () async {
    write.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    await outbox.drain();
    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(title: 'Errands'),
      now: now,
    );
    now = now.add(const Duration(hours: 3));
    final web = Label(id: 950, title: 'Errand', createdBy: me, created: now);
    write.serverLabels[950] = web;
    read.allLabels = [web];
    now = now.add(const Duration(minutes: 5));

    write.beforeRequest = null;
    await outbox.sendNow();

    expect(write.requests, [
      'create label Errand',
      'create label Errand',
      'update label 900 LabelChanges(title)',
    ]);
    expect(write.serverLabels[950]!.title, 'Errand');
    expect(write.serverLabels[900]!.title, 'Errands');
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test('attempts that only looked, offline, for hours do not widen the '
      'lookup: a rename queued behind the create does not reach a label of '
      'that title made on the web meanwhile', () async {
    Future<void> offline(String _) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    write.beforeRequest = offline;
    read.beforeRequest = offline;
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    await outbox.drain();
    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(title: 'Errands'),
      now: now,
    );
    for (var i = 0; i < 12; i++) {
      now = now.add(const Duration(minutes: 15));
      await outbox.sendNow();
    }
    expect(write.requests, ['create label Errand']);
    expect(read.requests, hasLength(12));
    final web = Label(id: 950, title: 'Errand', createdBy: me, created: now);
    write.serverLabels[950] = web;
    read.allLabels = [web];
    now = now.add(const Duration(minutes: 5));

    write.beforeRequest = null;
    read.beforeRequest = null;
    await outbox.sendNow();

    expect(write.requests, [
      'create label Errand',
      'create label Errand',
      'update label 900 LabelChanges(title)',
    ]);
    expect(write.serverLabels[950]!.title, 'Errand');
    expect(write.serverLabels[900]!.title, 'Errands');
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test(
    'a label of that title the lookup saw before a request that was '
    'lost again is not taken later, when the window has grown over it',
    () async {
      Future<void> offline(String _) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      write.beforeRequest = offline;
      read.beforeRequest = offline;
      final outbox = sender(userId: me.id);
      await queueLabel('Errand');
      await outbox.drain();
      await db.labelOpsDao.queueUpdate(
        -1,
        const LabelChanges(title: 'Errands'),
        now: now,
      );
      Future<void> retries(int count) async {
        for (var i = 0; i < count; i++) {
          now = now.add(const Duration(minutes: 15));
          await outbox.sendNow();
        }
      }

      await retries(6);
      final web = Label(id: 950, title: 'Errand', createdBy: me, created: now);
      write.serverLabels[950] = web;
      read.allLabels = [web];
      await retries(14);
      read.beforeRequest = null;
      write.beforeRequest = (request) async =>
          throw const NetworkFailure(NetworkProblem.timeout);
      now = now.add(const Duration(minutes: 5));
      await outbox.sendNow();
      expect(write.requests, ['create label Errand', 'create label Errand']);

      write.beforeRequest = null;
      now = now.add(const Duration(minutes: 15));
      await outbox.sendNow();

      expect(write.requests, [
        'create label Errand',
        'create label Errand',
        'create label Errand',
        'update label 900 LabelChanges(title)',
      ]);
      expect(write.serverLabels[950]!.title, 'Errand');
      expect(await db.labelsDao.resolveId(-1), 900);
    },
  );

  test('a search the server refuses before a create that may have reached '
      'it is no refusal of the create: Retry looks again and takes the '
      'label the lost request made', () async {
    loseCreateAnswers();
    final outbox = sender(userId: me.id);
    await queueLabel('Errand');
    await outbox.drain();
    write.afterRequest = null;
    read.beforeRequest = (request) async =>
        throw const UnexpectedResponse(400, message: 'refused');

    now = now.add(const Duration(minutes: 1));
    await outbox.sendNow();
    final failed = (await db.labelOpsDao.createOf(-1))!;
    expect(failed.state, OutboxState.failed.name);
    expect(failed.sentAt, isNotNull);

    read.beforeRequest = null;
    await db.outboxDao.retry(failed.id);
    await outbox.sendNow();

    expect(write.requests, ['create label Errand']);
    expect(write.serverLabels.keys, [900]);
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test('the lookup reaches from an hour before the first unanswered attempt '
      'to an hour after the create was last sent; a later attempt that did '
      'not send it moves nothing', () async {
    final first = now.subtract(const Duration(hours: 6));
    final last = now.subtract(const Duration(hours: 4));
    final lookedOnly = now.subtract(const Duration(hours: 2));
    const window = OutboxSender.lostResponseWindow;
    const second = Duration(seconds: 1);
    Label mine(int id, String title, DateTime created) =>
        Label(id: id, title: title, createdBy: me, created: created);
    await queueLabel('Errand');
    await queueLabel('Garden');
    for (final id in [-1, -2]) {
      final create = (await db.labelOpsDao.createOf(id))!;
      await db.outboxDao.claim(create.id, at: first);
      await db.labelOpsDao.markCreatePosted(create.id, at: first);
      await db.outboxDao.markUncertain(create.id, sentAt: first);
      await db.outboxDao.unclaim(create.id);
      await db.outboxDao.claim(create.id, at: last);
      await db.labelOpsDao.markCreatePosted(create.id, at: last);
      await db.outboxDao.unclaim(create.id);
      await db.outboxDao.claim(create.id, at: lookedOnly);
      await db.outboxDao.unclaim(create.id);
    }
    // Each one passed over has a higher id than the one taken.
    read.allLabels = [
      mine(50, 'Errand', first.subtract(window)),
      mine(51, 'Errand', first.subtract(window).subtract(second)),
      mine(60, 'Garden', last.add(window)),
      mine(61, 'Garden', last.add(window).add(second)),
    ];

    await sender(userId: me.id).drain();

    expect(write.requests, isEmpty);
    expect(await db.labelsDao.resolveId(-1), 50);
    expect(await db.labelsDao.resolveId(-2), 60);
  });

  test('from findOrCreate a label whose delete is queued here is not taken: '
      'the create goes, and its tasks keep the new label', () async {
    final shared = Label(id: 40, title: 'Errand', createdBy: ana, created: now);
    write.serverLabels[40] = shared;
    write.labels.othersLabels.add(40);
    read.allLabels = [shared];
    await db.labelsDao.upsertAll([shared]);
    await db.outboxDao.queueLabelOp(
      kind: OutboxOperationKind.updateLabel,
      labelId: 40,
      payload: encodeLabelChanges(const LabelChanges(hexColor: 'e69f00')),
      now: now,
    );
    await db.labelOpsDao.queueDelete(40, now: now);
    final outbox = sender();
    await outbox.drain();
    expect(
      (await db.outboxDao.loadProblems()).single.kind,
      OutboxOperationKind.deleteLabel,
    );

    await queueLabel('Errand', adopt: true);
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));
    await outbox.drain();

    expect(write.requests, [
      'delete label 40',
      'create label Errand',
      'update 1',
    ]);
    expect(await db.labelsDao.resolveId(-1), 900);
    expect(serverLabelsOf(1), {900});
    expect(await labelsOf(1), {900});
  });

  test(
    'a lost answer is not looked for among labels whose delete is queued '
    'here: the create goes again, and its tasks keep the new label',
    () async {
      loseCreateAnswers();
      final outbox = sender(userId: me.id);
      await queueLabel('Errand');
      await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));
      await outbox.drain();
      write.afterRequest = null;
      // The sync brought what the attempt made, and it was edited and deleted
      // here.
      await db.labelsDao.upsertAll([read.allLabels.single]);
      await db.outboxDao.queueLabelOp(
        kind: OutboxOperationKind.updateLabel,
        labelId: 900,
        payload: encodeLabelChanges(const LabelChanges(hexColor: 'e69f00')),
        now: now,
      );
      await db.labelOpsDao.queueDelete(900, now: now);

      await outbox.sendNow();

      expect(write.requests, [
        'create label Errand',
        'create label Errand',
        'update 1',
        'delete label 900',
      ]);
      expect(await db.labelsDao.resolveId(-1), 901);
      expect(write.serverLabels.keys, [901]);
      expect(serverLabelsOf(1), {901});
      expect(await labelsOf(1), {901});
    },
  );

  test('a create a run that died left on its way is looked for after the '
      'restart', () async {
    await queueLabel('Errand');
    final create = (await db.labelOpsDao.createOf(-1))!;
    await db.outboxDao.claim(create.id, at: now);
    await db.labelOpsDao.markCreatePosted(create.id, at: now);
    await db.outboxDao.resetSending(now: now, process: 1);
    await db.outboxDao.claim(create.id, at: now);
    write.serverLabels[900] = Label(id: 900, title: 'Errand', created: now);
    read.allLabels = [Label(id: 900, title: 'Errand', created: now)];

    await sender(processId: 2).drain();

    expect(write.requests, isEmpty);
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test('a create that a run which died before sending it left on its way '
      'is sent without a lookup: no attempt can have made a label', () async {
    await queueLabel('Errand');
    final create = (await db.labelOpsDao.createOf(-1))!;
    await db.outboxDao.claim(create.id, at: now);
    await db.outboxDao.resetSending(now: now, process: 1);
    expect((await db.outboxDao.all()).single.sentAt, now);
    final web = Label(id: 950, title: 'Errand', createdBy: me, created: now);
    write.serverLabels[950] = web;
    read.allLabels = [web];

    await sender(userId: me.id, processId: 2).drain();

    expect(read.requests, isEmpty);
    expect(write.requests, ['create label Errand']);
    expect(await db.labelsDao.resolveId(-1), 900);
  });

  test('a headless sender, as in a background run, sends a label create '
      'and what waited for it', () async {
    await queueLabel('Errand');
    await queue(1, const TaskChanges(labels: IdSetChange(added: {-1})));

    await sender(headless: true).sendNow(refreshAfter: false);

    expect(write.requests, ['create label Errand', 'update 1']);
    expect(sync.refreshAfterWriteCalls, 0);
  });

  test('an edit the server answers with "gone" removes the label here as '
      'well', () async {
    await queueLabel('Errand');
    final create = (await db.labelOpsDao.createOf(-1))!;
    await db.outboxDao.claim(create.id, at: now);
    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(title: 'Errands'),
      now: now,
    );
    await db.labelOpsDao.completeCreate(
      create.id,
      const Label(id: 50, title: 'Errand'),
      at: now,
    );
    await queue(1, const TaskChanges(labels: IdSetChange(added: {50})));

    await sender().drain();

    expect(write.requests.first, 'update label 50 LabelChanges(title)');
    expect(await db.labelsDao.find(50), isNull);
    expect(await db.outboxDao.loadProblems(), isEmpty);
    final rest = await db.outboxDao.all();
    expect(
      rest.every(
        (op) =>
            decodeTaskChanges(op.payload).labels?.added.contains(50) != true,
      ),
      isTrue,
    );
  });

  group('a create whose label was deleted here', () {
    final older = Label(
      id: 40,
      title: 'Errand',
      hexColor: '000000',
      createdBy: me,
      created: DateTime.utc(2026, 10, 2),
    );

    setUp(() {
      write.serverLabels[40] = older;
      read.allLabels = [older];
    });

    /// A quick-add label deleted while its create was on its way; the
    /// create is back in the queue, [sentAt] when its attempt may have
    /// reached the server.
    Future<void> deletedWhileSending({DateTime? sentAt}) async {
      final label = await queueLabel('Errand', adopt: true);
      final create = (await db.labelOpsDao.createOf(label.id))!;
      await db.outboxDao.claim(create.id, at: now);
      await db.labelOpsDao.queueDelete(label.id, now: now);
      if (sentAt != null) {
        await db.outboxDao.markUncertain(create.id, sentAt: sentAt);
      }
      await db.outboxDao.unclaim(create.id);
    }

    test('never sent goes without a request: an older label of that title '
        'stays', () async {
      await deletedWhileSending();

      await sender(userId: me.id).drain();

      expect(read.requests, isEmpty);
      expect(write.requests, isEmpty);
      expect(write.serverLabels.keys, [40]);
      expect(await db.outboxDao.count(), 0);
      expect(await db.labelsDao.loadAll(), isEmpty);
    });

    test('sent without an answer goes without a lookup or a request too: a '
        'label its attempt made is left for the sync', () async {
      final made = Label(id: 900, title: 'Errand', createdBy: me, created: now);
      write.serverLabels[900] = made;
      read.allLabels = [older, made];
      await deletedWhileSending(sentAt: now);

      await sender(userId: me.id).drain();

      expect(read.requests, isEmpty);
      expect(write.requests, isEmpty);
      expect(write.serverLabels.keys, unorderedEquals([40, 900]));
      expect(await db.outboxDao.count(), 0);
      expect(await db.labelsDao.loadAll(), isEmpty);
    });

    test('deleted while a create without an answer is looked for leaves the '
        'label found there alone', () async {
      final made = Label(id: 900, title: 'Errand', createdBy: me, created: now);
      write.serverLabels[900] = made;
      read.allLabels = [older, made];
      await queueLabel('Errand');
      final create = (await db.labelOpsDao.createOf(-1))!;
      await db.labelOpsDao.markCreatePosted(create.id, at: now);
      await db.outboxDao.markUncertain(create.id, sentAt: now);
      read.beforeRequest = (request) async {
        if (request.startsWith('labels page')) {
          await db.labelOpsDao.queueDelete(-1, now: now);
        }
      };

      await sender(userId: me.id).drain();

      expect(read.requests, ['labels page 1 search Errand']);
      expect(write.requests, isEmpty);
      expect(write.serverLabels.keys, unorderedEquals([40, 900]));
      expect(await db.outboxDao.count(), 0);
      expect(await db.labelsDao.loadAll(), isEmpty);
    });

    test('deleted while the server is searched for its title leaves the '
        'label found there alone', () async {
      await queueLabel('Errand', adopt: true);
      read.beforeRequest = (request) async {
        if (request.startsWith('labels page')) {
          await db.labelOpsDao.queueDelete(-1, now: now);
        }
      };

      await sender(userId: me.id).drain();

      expect(read.requests, ['labels page 1 search Errand']);
      expect(write.requests, isEmpty);
      expect(write.serverLabels.keys, [40]);
      expect(await db.outboxDao.count(), 0);
      expect(await db.labelsDao.loadAll(), isEmpty);
      expect(await db.labelsDao.resolveId(-1), -1);
    });
  });

  test('an edit of a label from findOrCreate goes to the label the server '
      'had under that title', () async {
    final mine = Label(
      id: 40,
      title: 'Errand',
      hexColor: '000000',
      createdBy: me,
      created: now,
    );
    write.serverLabels[40] = mine;
    read.allLabels = [mine];
    await queueLabel('Errand', adopt: true);
    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(hexColor: 'e69f00'),
      now: now,
    );

    await sender().drain();

    expect(write.requests, ['update label 40 LabelChanges(hexColor)']);
    expect(write.serverLabels[40]!.hexColor, 'e69f00');
    expect(await db.labelsDao.resolveId(-1), 40);
    expect((await db.labelsDao.find(40))!.hexColor, 'e69f00');
    expect(await db.outboxDao.count(), 0);
  });

  test("an edit of a label from findOrCreate that took another member's "
      'label is a sync problem saying so; Discard reads the label '
      'back', () async {
    final anas = Label(
      id: 41,
      title: 'Errand',
      hexColor: '000000',
      createdBy: ana,
      created: now,
    );
    write.serverLabels[41] = anas;
    write.labels.othersLabels.add(41);
    read.allLabels = [anas];
    await queueLabel('Errand', adopt: true);
    await db.labelOpsDao.queueUpdate(
      -1,
      const LabelChanges(hexColor: 'e69f00'),
      now: now,
    );
    final outbox = sender();

    await outbox.drain();

    expect(write.requests, ['update label 41 LabelChanges(hexColor)']);
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.kind, OutboxOperationKind.updateLabel);
    expect(problem.taskTitle, 'Errand');
    expect(problem.labelId, 41);
    expect(
      describeSyncProblem(en, problem),
      '${en.syncProblemLabelUpdateFailed} ${en.labelsNotCreator}',
    );
    expect((await db.labelsDao.find(41))!.hexColor, 'e69f00');

    await outbox.discard(problem.operationId);

    expect(write.requests.last, 'update label 41 LabelChanges()');
    expect((await db.labelsDao.find(41))!.hexColor, '000000');
    expect(await db.outboxDao.count(), 0);
  });

  test('Discard of a failed delete gives the label back to the tasks the '
      'server has it on', () async {
    final errand = Label(id: 50, title: 'Errand', createdBy: ana, created: now);
    write.serverLabels[50] = errand;
    write.labels.othersLabels.add(50);
    final carrying = [
      sampleTask(id: 1, title: 'One', projectId: 7, labels: [errand]),
      sampleTask(id: 2, title: 'Two', projectId: 7, labels: [errand]),
    ];
    await db.tasksDao.upsertAll(carrying, syncRunId: 'run 2');
    write.serverTasks.addEntries(carrying.map((t) => MapEntry(t.id, t)));
    await db.labelsDao.upsertAll([errand]);
    // An edit of the label is queued, so its delete queues too.
    await db.outboxDao.queueLabelOp(
      kind: OutboxOperationKind.updateLabel,
      labelId: 50,
      payload: encodeLabelChanges(const LabelChanges(hexColor: 'e69f00')),
      now: now,
    );
    await db.labelOpsDao.queueDelete(50, now: now);
    expect(await labelsOf(1), isEmpty);
    final outbox = sender();

    await outbox.drain();

    expect(write.requests, ['delete label 50']);
    final problem = (await db.outboxDao.loadProblems()).single;
    expect(problem.kind, OutboxOperationKind.deleteLabel);
    expect(problem.taskTitle, 'Errand');

    await outbox.discard(problem.operationId);

    expect(write.requests.last, 'update label 50 LabelChanges()');
    expect(await db.labelsDao.find(50), isNotNull);
    expect(await labelsOf(1), {50});
    expect(await labelsOf(2), {50});
    expect(await db.outboxDao.count(), 0);
  });

  test('a task update that an edit merged in between the queue read and the '
      'claim made name a label not created yet waits for it', () async {
    await queue(1, const TaskChanges(title: 'One more'));
    await queueLabel('Errand');
    var reads = 0;
    final outbox = sender(
      clock: () {
        // The second read is the claim's, after the queue was read.
        if (++reads == 2) {
          unawaited(
            db.outboxDao.queueUpdate(
              1,
              const TaskChanges(labels: IdSetChange(added: {-1})),
              now: now,
            ),
          );
        }
        return now;
      },
    );

    await outbox.drain();

    expect(write.requests, ['create label Errand', 'update 1']);
    expect(write.serverTasks[1]!.title, 'One more');
    expect(serverLabelsOf(1), {900});
    expect(await db.outboxDao.count(), 0);
  });
}
