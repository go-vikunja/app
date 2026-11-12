import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/local/local_label_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';

import '../../../helpers/fake_sync_client.dart';
import '../../../helpers/fake_timers.dart';
import '../../../helpers/fake_write_client.dart';
import '../../../helpers/recording_sync_engine.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/zero_random.dart';
import 'fake_grammar.dart';

// The quick add over the real local task repository and outbox, with a
// server-like write client behind them.
void main() {
  final now = DateTime(2026, 10, 12, 10, 15);
  final garage = sampleProject(id: 3, title: 'Garage');
  const wichtig = Label(id: 10, title: 'wichtig');
  const alice = User(id: 20, username: 'alice');
  const bob = User(id: 21, username: 'bob');
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  late LocalTaskRepository tasks;
  late RequestGate gate;

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()
      ..allProjects = [garage]
      ..projectUsers[3] = const [alice, bob];
    gate = RequestGate();
    write.beforeRequest = gate.call;
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: RecordingSyncEngine(),
      now: () => now,
      createTimer: FakeTimers().create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    tasks = LocalTaskRepository(
      db,
      RecordingSyncEngine(),
      sender,
      write,
      now: () => now,
    );
    addTearDown(tasks.dispose);
    await db.projectsDao.upsertAll([garage]);
    await db.labelsDao.upsertAll(const [wichtig]);
    await db.usersDao.upsertAll(const [alice]);
    write
      ..serverLabels[wichtig.id] = wichtig
      ..serverUsers.addAll({alice.id: alice, bob.id: bob});
  });

  Future<LocalQuickAddService> service() async => LocalQuickAddService(
    snapshot: QuickAddSnapshot(
      projects: await db.projectsDao.loadAll(),
      labels: await db.labelsDao.loadAll(),
      knownUsers: await db.usersDao.loadAll(),
    ),
    tasks: tasks,
    labels: LocalLabelRepository(db, write, read, now: () => now),
    users: LocalUserRepository(db, read),
    now: () => now,
    grammar: fakeGrammar,
    random: ZeroRandom(),
  );

  test('one create op and the label and assignee update behind it, sent '
      'after the remap', () async {
    gate.pattern = 'create Reifen';

    final result = await (await service()).submit(
      'Reifen wechseln *wichtig *neu +Garage @alice @bob !3 tomorrow',
    );
    while (!gate.isHolding) {
      await pumpEventQueue();
    }

    final localId = result.createdTaskIds.single;
    expect(localId, isNegative);
    expect(write.requests, ['create label neu', 'create Reifen wechseln']);
    final ops = await db.outboxDao.all();
    expect(ops.map((op) => (op.kind, op.taskId)), [
      ('createTask', localId),
      ('updateTask', localId),
    ]);
    // On screen at once, with the labels and people stored here.
    final local = (await db.tasksDao.find(localId))!;
    expect(local.title, 'Reifen wechseln');
    expect(local.priority, TaskPriority.high);
    expect(local.labels.map((label) => label.title), {'wichtig', 'neu'});
    expect(local.assignees.map((user) => user.id), {20, 21});

    gate.release();
    await sender.drain();

    expect(write.requests, [
      'create label neu',
      'create Reifen wechseln',
      'update 100',
    ]);
    expect(await db.outboxDao.count(), 0);
    final onServer = write.serverTasks[100]!;
    expect(onServer.projectId, 3);
    expect(onServer.title, 'Reifen wechseln');
    expect(onServer.dueDate, DateTime(2026, 10, 13, 9).toUtc());
    expect(onServer.labels.map((label) => label.id), {10, 900});
    expect(onServer.assignees.map((user) => user.id), {20, 21});
    final remapped = await tasks.watchTask(localId).first;
    expect(remapped!.id, 100);
    expect(remapped.labels.map((label) => label.id), {10, 900});
  });

  test('offline: the create and the update wait and go out on '
      'reconnect', () async {
    read.beforeRequest = (_) =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    write.beforeRequest = (request) =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    final result = await (await service()).submit(
      'Offline erledigen *wichtig *neu @alice @bob +Garage',
    );
    await pumpEventQueue();

    expect(result.labelsKept, ['*neu']);
    expect(result.unresolvedAssignees, ['bob']);
    expect(await db.outboxDao.count(), 2);
    expect(write.serverTasks, isEmpty);

    read.beforeRequest = null;
    write.beforeRequest = null;
    expect(await sender.sendNow(), isNull);

    expect(await db.outboxDao.count(), 0);
    final onServer = write.serverTasks.values.single;
    expect(onServer.title, 'Offline erledigen @bob *neu');
    expect(onServer.labels.map((label) => label.id), [10]);
    expect(onServer.assignees.map((user) => user.id), [20]);
  });

  test(
    'offline: a tree is on screen at once with its subtasks and goes '
    'out as creates, each child naming its parent with the server id',
    () async {
      write.beforeRequest = (request) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      final result = await (await service()).submit(
        'Parent +Garage\n  Child one\n    Grandchild\n  Child two',
      );
      await pumpEventQueue();

      final [parent, one, grandchild, two] = result.createdTaskIds;
      final ops = await db.outboxDao.all();
      expect(ops.map((op) => (op.kind, op.taskId)), [
        ('createTask', parent),
        ('createTask', one),
        ('updateTask', one),
        ('createTask', grandchild),
        ('updateTask', grandchild),
        ('createTask', two),
        ('updateTask', two),
      ]);
      final local = (await db.tasksDao.find(parent))!;
      expect(
        local.subtasks.map((task) => task.id),
        unorderedEquals([one, two]),
      );
      expect((await db.tasksDao.find(one))!.subtasks.single.id, grandchild);
      expect((await db.tasksDao.find(grandchild))!.projectId, 3);

      write
        ..beforeRequest = null
        ..requests.clear();
      expect(await sender.sendNow(), isNull);

      expect(write.requests, [
        'create Parent',
        'create Child one',
        'update 101',
        'create Grandchild',
        'update 102',
        'create Child two',
        'update 103',
      ]);
      expect(await db.outboxDao.count(), 0);
      List<int> serverSubtasks(int id) => [
        for (final task in write.serverTasks[id]!.subtasks) task.id,
      ];
      expect(serverSubtasks(100), unorderedEquals([101, 103]));
      expect(serverSubtasks(101), [102]);
      expect(write.serverTasks.values.map((task) => task.projectId), {3});
      final remapped = (await tasks.watchTask(parent).first)!;
      expect(remapped.id, 100);
      expect(
        remapped.subtasks.map((task) => task.id),
        unorderedEquals([101, 103]),
      );
      expect((await db.tasksDao.find(102))!.parentTasks.single.id, 101);
    },
  );
}
