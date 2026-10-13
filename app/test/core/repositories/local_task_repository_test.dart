import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

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
  late FakeTimers timers;
  late OutboxSender sender;
  late LocalTaskRepository repository;
  final monday = DateTime.utc(2026, 10, 12, 9);
  final now = DateTime.utc(2026, 10, 10, 12);
  final tasks = [
    sampleTask(id: 1, title: 'Undated', projectId: 7),
    sampleTask(id: 2, title: 'Monday', projectId: 7, due: monday),
    sampleTask(id: 3, title: 'Done', projectId: 7, done: true),
    sampleTask(id: 4, title: 'Elsewhere', projectId: 8),
  ];
  final daily = sampleTask(
    id: 5,
    title: 'Daily',
    projectId: 7,
    due: monday,
    start: monday.subtract(const Duration(hours: 1)),
    repeatAfter: const Duration(days: 1),
  );

  setUp(() async {
    db = testDatabase();
    sync = RecordingSyncEngine();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient();
    timers = FakeTimers();
    sender = OutboxSender(
      db: db,
      writeClient: write,
      readClient: read,
      sync: sync,
      now: () => now,
      createTimer: timers.create,
      random: ZeroRandom(),
    );
    addTearDown(sender.dispose);
    repository = LocalTaskRepository(db, sync, sender, write, now: () => now);
    addTearDown(repository.dispose);
    await db.tasksDao.upsertAll(tasks, syncRunId: 'run');
    write.serverTasks.addEntries(tasks.map((t) => MapEntry(t.id, t)));
    read
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = tasks;
  });

  test('open tasks come from the database, nearest due date first', () async {
    final seen = <List<Task>>[];
    repository.watchOpenTasks().listen(seen.add);
    await pumpEventQueue();
    expect(seen.single.map((t) => t.id), [2, 4, 1]);

    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'Undated', projectId: 7, done: true),
    ], syncRunId: 'run');
    await pumpEventQueue();

    expect(seen.last.map((t) => t.id), [2, 4]);
  });

  test('every refresh is a sync run whose failure passes through', () async {
    final errors = <Object>[];
    repository.watchOpenTasks().listen((_) {}, onError: errors.add);
    await pumpEventQueue();

    await repository.refreshOpenTasks();
    await repository.refreshProjectList(7, viewId: 0);
    expect(sync.refreshCalls, 2);

    sync.error = const ServerFailure(502);
    await expectLater(
      repository.refreshOpenTasks(),
      throwsA(isA<ServerFailure>()),
    );
    await expectLater(
      repository.refreshProjectList(7, viewId: 0),
      throwsA(isA<ServerFailure>()),
    );

    expect(sync.refreshCalls, 4);
    expect(errors, isEmpty);
  });

  group('writes', () {
    test('mark done shows at once, then goes to the server', () async {
      final open = <List<Task>>[];
      final pending = <int>[];
      final pendingIds = <Set<int>>[];
      repository.watchOpenTasks().listen(open.add);
      repository.watchPendingChanges().listen(pending.add);
      repository.watchPendingTaskIds().listen(pendingIds.add);
      await pumpEventQueue();
      // The server is slow: the row changes before it answers.
      final gate = RequestGate()..pattern = 'update';
      write.beforeRequest = gate.call;

      await repository.setDone(2, done: true);
      await pumpEventQueue();

      expect(open.last.map((t) => t.id), [4, 1]);
      expect(pending.last, 1);
      expect(pendingIds.last, {2});
      expect(write.requests, ['update 2']);

      gate.release();
      await pumpEventQueue();

      expect(write.updates.single, (2, const TaskChanges(done: true)));
      expect(write.serverTasks[2]!.done, isTrue);
      expect(pending.last, 0);
      expect(pendingIds.last, isEmpty);
      expect((await db.tasksDao.find(2))!.updated, now);
      expect(sync.refreshCalls, 1);
    });

    test('an undo before the send merges into one change', () async {
      await repository.setDone(2, done: true);
      await repository.setDone(2, done: false);
      await pumpEventQueue();

      expect(write.updates.map((u) => u.$2.done), [false]);
      expect(write.serverTasks[2]!.done, isFalse);
      expect((await db.tasksDao.find(2))!.done, isFalse);
      expect(await db.outboxDao.count(), 0);
    });

    test('undoing a repeating task the server already moved on restores '
        'its dates', () async {
      await db.tasksDao.upsertAll([daily], syncRunId: 'run');
      write.serverTasks[5] = daily;
      final previous = (await db.tasksDao.find(5))!;
      await repository.setDone(5, done: true);
      await pumpEventQueue();
      final shifted = (await db.tasksDao.find(5))!;
      expect(shifted.done, isFalse);
      expect(shifted.dueDate, monday.add(const Duration(days: 1)));

      await repository.undoDone(previous);
      final restored = (await db.tasksDao.find(5))!;
      expect(restored.dueDate, monday);
      expect(restored.startDate, previous.startDate);
      await pumpEventQueue();

      expect(write.updates.last, (
        5,
        TaskChanges(
          done: false,
          dueDate: DateChange.set(monday),
          startDate: DateChange.set(previous.startDate!),
        ),
      ));
      final server = write.serverTasks[5]!;
      expect(server.done, isFalse);
      expect(server.dueDate, monday);
      expect(server.startDate, previous.startDate);
      expect((await db.tasksDao.find(5))!.dueDate, monday);
      expect(await db.outboxDao.count(), 0);
    });

    test('undoing a repeating task also restores the reminders the server '
        'moved on with the dates', () async {
      final reminderAt = monday.subtract(const Duration(hours: 2));
      const halfHourBefore = TaskReminder(
        relativePeriod: Duration(minutes: -30),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      final withReminders = sampleTask(
        id: 6,
        title: 'Daily with reminders',
        projectId: 7,
        due: monday,
        repeatAfter: const Duration(days: 1),
        reminders: [
          TaskReminder(reminder: reminderAt),
          TaskReminder(
            reminder: monday.subtract(const Duration(minutes: 30)),
            relativePeriod: halfHourBefore.relativePeriod,
            relativeTo: halfHourBefore.relativeTo,
          ),
        ],
      );
      await db.tasksDao.upsertAll([withReminders], syncRunId: 'run');
      write.serverTasks[6] = withReminders;
      final previous = (await db.tasksDao.find(6))!;
      await repository.setDone(6, done: true);
      await pumpEventQueue();
      final shifted = (await db.tasksDao.find(6))!;
      expect(
        shifted.reminders.first.reminder,
        reminderAt.add(const Duration(days: 1)),
      );

      await repository.undoDone(previous);
      expect((await db.tasksDao.find(6))!.reminders, previous.reminders);
      await pumpEventQueue();

      expect(write.updates.last, (
        6,
        TaskChanges(
          done: false,
          dueDate: DateChange.set(monday),
          reminders: previous.reminders,
        ),
      ));
      expect(write.serverTasks[6]!.reminders, previous.reminders);
      expect((await db.tasksDao.find(6))!.reminders, previous.reminders);
      expect(await db.outboxDao.count(), 0);
    });

    test('undoing a task that does not repeat sends done only', () async {
      final previous = (await db.tasksDao.find(2))!;
      await repository.setDone(2, done: true);
      await repository.undoDone(previous);
      await pumpEventQueue();

      expect(write.updates.single, (2, const TaskChanges(done: false)));
    });

    test('favourite and delete', () async {
      await repository.setFavorite(1, favorite: true);
      await repository.deleteTask(4);
      await pumpEventQueue();

      expect((await db.tasksDao.find(1))!.isFavorite, isTrue);
      expect(await db.tasksDao.find(4), isNull);
      expect(write.updates.single, (1, const TaskChanges(isFavorite: true)));
      expect(write.deletes, [4]);
      expect(write.serverTasks.containsKey(4), isFalse);
      expect(await db.tasksDao.findRow(4), isNull);
    });

    test('a write for a task that is gone here does nothing', () async {
      await repository.setDone(99, done: true);
      await repository.deleteTask(99);
      await pumpEventQueue();

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('a write never throws for the network; the op waits', () async {
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await repository.setDone(1, done: true);
      await pumpEventQueue();

      expect((await db.tasksDao.find(1))!.done, isTrue);
      expect(await db.outboxDao.count(), 1);
      expect(sender.state, OutboxSenderState.waiting);
      expect(timers.pendingWait, OutboxSender.initialBackoff);

      expect(await repository.sendPendingChanges(), isA<NetworkFailure>());

      write.beforeRequest = null;
      expect(await repository.sendPendingChanges(), isNull);

      expect(await db.outboxDao.count(), 0);
      expect(write.serverTasks[1]!.done, isTrue);
    });

    test('a rejected write is a sync problem to retry or discard', () async {
      final problems = <List<SyncProblem>>[];
      repository.watchSyncProblems().listen(problems.add);
      write.beforeRequest = (_) => throw const Forbidden(code: 7003);

      await repository.setDone(1, done: true);
      await repository.setFavorite(2, favorite: true);
      await pumpEventQueue();

      expect(problems.last.map((p) => p.taskTitle), ['Undated', 'Monday']);
      expect(problems.last.first.failure, isA<Forbidden>());
      final (first, second) = (problems.last.first, problems.last.last);

      write.beforeRequest = null;
      await repository.retrySyncProblem(first.operationId);
      await pumpEventQueue();
      expect(problems.last.map((p) => p.taskId), [2]);
      expect(write.serverTasks[1]!.done, isTrue);

      await repository.discardSyncProblem(second.operationId);
      await pumpEventQueue();
      expect(problems.last, isEmpty);
      expect((await db.tasksDao.find(2))!.isFavorite, isFalse);
      expect(write.serverTasks[2]!.isFavorite, isFalse);
    });
  });

  group('creates', () {
    const draft = NewTask(projectId: 7, title: 'Buy milk');

    test('a new task is on screen at once under a temporary id, then under '
        'the server id once the create is answered', () async {
      final open = <List<Task>>[];
      final project = <ProjectListSource>[];
      final pendingIds = <Set<int>>[];
      repository.watchOpenTasks().listen(open.add);
      repository.watchProjectList(7, viewId: 0).listen(project.add);
      repository.watchPendingTaskIds().listen(pendingIds.add);
      await pumpEventQueue();
      final gate = RequestGate()..pattern = 'create';
      write.beforeRequest = gate.call;

      final id = await repository.createTask(draft);
      final watched = <Task?>[];
      repository.watchTask(id).listen(watched.add);
      await pumpEventQueue();

      expect(id, -1);
      expect(open.last.map((t) => t.id), [2, -1, 4, 1]);
      expect(project.last.projectTasks.map((t) => t.id), [-1, 3, 2, 1]);
      expect(pendingIds.last, {-1});
      expect(watched.single!.title, 'Buy milk');
      expect(watched.single!.identifier, '');
      expect(write.requests, ['create Buy milk']);

      gate.release();
      await pumpEventQueue();

      expect(open.last.map((t) => t.id), [2, 100, 4, 1]);
      expect(project.last.projectTasks.map((t) => t.id), [100, 3, 2, 1]);
      expect(pendingIds.last, isEmpty);
      expect(watched.last!.id, 100);
      expect(watched.last!.identifier, '-100');
      expect(write.creates.single, draft);
      expect(await db.tasksDao.find(-1), isNull);
      expect(sync.refreshCalls, 1);
    });

    test('an edit before the send goes with the create', () async {
      sender.pause();
      final id = await repository.createTask(draft);
      await repository.updateTask(
        id,
        TaskChanges(title: 'Buy oat milk', dueDate: DateChange.set(monday)),
      );
      await repository.setFavorite(id, favorite: true);
      expect((await db.tasksDao.find(id))!.title, 'Buy oat milk');

      await sender.resume();

      expect(write.requests, ['create Buy oat milk']);
      expect(
        write.creates.single,
        NewTask(
          projectId: 7,
          title: 'Buy oat milk',
          dueDate: monday,
          isFavorite: true,
        ),
      );
      expect(await db.outboxDao.count(), 0);
    });

    test('a delete before the send costs nothing', () async {
      sender.pause();
      final id = await repository.createTask(draft);
      await repository.deleteTask(id);

      await sender.resume();

      expect(write.requests, isEmpty);
      expect(await db.tasksDao.findRow(id), isNull);
      expect(await db.outboxDao.count(), 0);
    });

    test('a done before the send follows the create', () async {
      sender.pause();
      final id = await repository.createTask(draft);
      await repository.setDone(id, done: true);
      expect((await db.tasksDao.find(id))!.done, isTrue);

      await sender.resume();

      expect(write.requests, ['create Buy milk', 'update 100']);
      expect(write.updates.single, (100, const TaskChanges(done: true)));
      expect((await db.tasksDao.find(100))!.done, isTrue);
      expect(await db.outboxDao.count(), 0);
    });

    test('a create never throws for the network; the row waits', () async {
      write.beforeRequest = (_) =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      final id = await repository.createTask(draft);
      await pumpEventQueue();

      expect((await db.tasksDao.find(id))!.title, 'Buy milk');
      expect(await db.outboxDao.count(), 1);
      expect(sender.state, OutboxSenderState.waiting);

      write.beforeRequest = null;
      expect(await repository.sendPendingChanges(), isNull);
      expect(await db.tasksDao.resolveId(id), 100);
    });
  });

  group('updateTask', () {
    test('sends exactly the changed fields and applies the answer', () async {
      final changes = TaskChanges(
        title: 'Renamed',
        priority: TaskPriority.urgent.value,
        percentDone: 0.5,
        hexColor: '1973ff',
        dueDate: DateChange.set(monday),
        startDate: const DateChange.clear(),
        repeatAfter: const Duration(days: 30),
        repeatMode: RepeatMode.afterAmount,
        projectId: 8,
      );

      await repository.updateTask(1, changes);
      final atOnce = (await db.tasksDao.find(1))!;
      await pumpEventQueue();

      expect(atOnce.title, 'Renamed');
      expect(atOnce.projectId, 8);
      expect(atOnce.repeatAfter, const Duration(days: 30));
      expect(atOnce.updated, isNull);
      expect(write.updates.single, (1, changes));
      final applied = (await db.tasksDao.find(1))!;
      expect(applied.title, 'Renamed');
      expect(applied.projectId, 8);
      expect(applied.priority, TaskPriority.urgent);
      expect(applied.percentDone, 0.5);
      expect(applied.hexColor, '1973ff');
      expect(applied.dueDate, monday);
      expect(applied.updated, now);
      expect(write.serverTasks[1]!.projectId, 8);
      expect(await db.outboxDao.count(), 0);
    });

    test('an empty change is nothing to queue', () async {
      await repository.updateTask(1, const TaskChanges());
      await pumpEventQueue();

      expect(write.requests, isEmpty);
      expect(await db.outboxDao.count(), 0);
    });

    test('two edits before the send merge into one request', () async {
      sender.pause();
      await repository.updateTask(2, const TaskChanges(title: 'First'));
      await repository.updateTask(
        2,
        const TaskChanges(
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
        ),
      );

      await sender.resume();

      expect(write.updates.single, (
        2,
        const TaskChanges(
          title: 'First',
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
        ),
      ));
    });
  });

  group('duplicateTask', () {
    test('the server copies the task; the copy is stored with its '
        'copiedfrom edge and the source with copiedto', () async {
      final copyId = await repository.duplicateTask(2);

      expect(copyId, 100);
      expect(write.requests, ['duplicate 2']);
      final copy = (await db.tasksDao.find(copyId))!;
      expect(copy.title, 'Monday');
      expect(copy.dueDate, monday);
      expect(copy.relatedTasks[TaskRelationKind.copiedFrom]!.single.id, 2);
      final source = (await db.tasksDao.find(2))!;
      expect(source.relatedTasks[TaskRelationKind.copiedTo]!.single.id, 100);
    });

    test('queued changes go first, so the copy has them', () async {
      await repository.updateTask(2, const TaskChanges(title: 'Renamed'));

      final copyId = await repository.duplicateTask(2);

      expect(write.requests, ['update 2', 'duplicate 2']);
      expect((await db.tasksDao.find(copyId))!.title, 'Renamed');
    });

    test('a task created here is duplicated under its server id once its '
        'create went', () async {
      sender.pause();
      final localId = await repository.createTask(
        const NewTask(projectId: 7, title: 'Fresh'),
      );
      await sender.resume();
      write.requests.clear();

      final copyId = await repository.duplicateTask(localId);

      expect(write.requests, ['duplicate 100']);
      expect(copyId, 101);
    });

    test('offline the queued change cannot go: refused with the network '
        'failure, nothing duplicated', () async {
      write.beforeRequest = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await repository.setFavorite(2, favorite: true);

      await expectLater(
        repository.duplicateTask(2),
        throwsA(isA<NetworkFailure>()),
      );
      expect(write.requests.where((r) => r.startsWith('duplicate')), isEmpty);
      expect(await db.outboxDao.count(), 1);
    });

    test(
      'a change the server refused is not synced: refused as such',
      () async {
        write.beforeRequest = (request) async =>
            throw const Forbidden(code: 7003);
        await repository.setFavorite(2, favorite: true);
        await sender.drain();

        await expectLater(
          repository.duplicateTask(2),
          throwsA(isA<TaskNotSyncedYet>()),
        );
        expect(write.requests.where((r) => r.startsWith('duplicate')), isEmpty);
      },
    );

    test('the failure of the duplicate itself propagates and stores '
        'nothing', () async {
      write.beforeRequest = (request) async {
        if (request.startsWith('duplicate')) throw const ServerFailure(500);
      };

      await expectLater(
        repository.duplicateTask(2),
        throwsA(isA<ServerFailure>()),
      );
      expect(await db.tasksDao.find(100), isNull);
    });
  });
}
