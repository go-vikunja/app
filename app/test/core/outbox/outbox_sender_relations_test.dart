import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/outbox_dao.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_timers.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/recording_sync_engine.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';
import '../../helpers/zero_random.dart';

// The sender with relations: ids are resolved at send time, an op naming a
// create that has not been answered waits for it, and the server's
// refusals are sync problems naming the task.
void main() {
  late AppDatabase db;
  late FakeWriteClient write;
  late FakeSyncClient read;
  late OutboxSender sender;
  final now = DateTime.utc(2026, 10, 13, 12);
  final one = sampleTask(id: 1, title: 'One', projectId: 7);
  final two = sampleTask(id: 2, title: 'Two', projectId: 7);

  RelationChange add(TaskRelationKind kind, int other) =>
      RelationChange(added: {TaskRelationRef(kind, other)});

  setUp(() async {
    db = testDatabase();
    write = FakeWriteClient(clock: () => now);
    read = FakeSyncClient()
      ..allProjects = [sampleProject(id: 7, title: 'Work')]
      ..allTasks = [one, two];
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
    await db.tasksDao.upsertAll([one, two], syncRunId: 'run');
    write.serverTasks.addAll({1: one, 2: two});
  });

  Future<void> queue(int id, TaskChanges changes) async {
    expect(await db.outboxDao.queueUpdate(id, changes, now: now), isTrue);
  }

  Future<int> create(String title) =>
      db.outboxDao.queueCreate(NewTask(projectId: 7, title: title), now: now);

  Future<Map<TaskRelationKind, List<int>>> edgesOf(int id) async => {
    for (final MapEntry(:key, :value) in (await db.tasksDao.find(
      id,
    ))!.relatedTasks.entries)
      key: [for (final other in value) other.id],
  };

  Map<TaskRelationKind, List<int>> serverEdgesOf(int id) => {
    for (final MapEntry(:key, :value)
        in write.serverTasks[id]!.relatedTasks.entries)
      key: [for (final other in value) other.id],
  };

  test('a relation between two tasks created offline is sent after both '
      'creates, with the server ids, and the rows carry them', () async {
    final parent = await create('Parent');
    final child = await create('Child');
    await queue(
      child,
      TaskChanges(relations: add(TaskRelationKind.parentTask, parent)),
    );

    await sender.drain();

    expect(write.requests, ['create Parent', 'create Child', 'update 101']);
    expect(write.updates.single, (
      101,
      TaskChanges(relations: add(TaskRelationKind.parentTask, 100)),
    ));
    expect(serverEdgesOf(101), {
      TaskRelationKind.parentTask: [100],
    });
    expect(serverEdgesOf(100), {
      TaskRelationKind.subtask: [101],
    });
    expect(await db.outboxDao.count(), 0);
    expect(await edgesOf(101), {
      TaskRelationKind.parentTask: [100],
    });
    expect(await edgesOf(100), {
      TaskRelationKind.subtask: [101],
    });
    expect(await db.tasksDao.find(parent), isNull);
    expect(await db.tasksDao.find(child), isNull);
  });

  test('an update naming a create queued after it waits; the create goes '
      'first', () async {
    await queue(1, const TaskChanges(title: 'Renamed'));
    final created = await create('Later');
    await queue(
      1,
      TaskChanges(relations: add(TaskRelationKind.blocking, created)),
    );

    await sender.drain();

    expect(write.requests, ['create Later', 'update 1']);
    expect(write.updates.single, (
      1,
      TaskChanges(
        title: 'Renamed',
        relations: add(TaskRelationKind.blocking, 100),
      ),
    ));
    expect(serverEdgesOf(100), {
      TaskRelationKind.blocked: [1],
    });
    expect(await db.outboxDao.count(), 0);
  });

  test('while the named create is failed the update waits, and the queue '
      'behind it goes on', () async {
    final created = await create('Rejected');
    await queue(
      1,
      TaskChanges(relations: add(TaskRelationKind.related, created)),
    );
    await queue(2, const TaskChanges(isFavorite: true));
    write.beforeRequest = (request) async {
      if (request == 'create Rejected') {
        throw const DomainError(400, code: 4001);
      }
    };

    await sender.drain();

    expect(write.requests, ['create Rejected', 'update 2']);
    final left = await db.outboxDao.all();
    expect(left.map((op) => (op.kind, op.taskId, op.state)), [
      (OutboxOperationKind.createTask.name, created, OutboxState.failed.name),
      (OutboxOperationKind.updateTask.name, 1, OutboxState.pending.name),
    ]);
    expect(sender.state, OutboxSenderState.idle);

    write.beforeRequest = null;
    await sender.retry(left.first.id);

    expect(write.requests.skip(2), ['create Rejected', 'update 1']);
    expect(await db.outboxDao.count(), 0);
  });

  test('a claimed op that cannot go yet goes back to the queue as it was, '
      'and the queue skips it', () async {
    await queue(1, const TaskChanges(title: 'Renamed'));
    final created = await create('Later');
    // Merged in between the sender's read of the queue and its claim.
    await queue(
      1,
      TaskChanges(relations: add(TaskRelationKind.related, created)),
    );
    final op = (await db.outboxDao.all()).first;
    expect(await db.outboxDao.claim(op.id, at: now), isNotNull);

    await db.outboxDao.unclaim(op.id);

    final back = (await db.outboxDao.find(op.id))!;
    expect(back.state, OutboxState.pending.name);
    expect(back.attempts, 0);
    expect((await db.outboxDao.nextInLine())!.taskId, created);
  });

  group('refusals are sync problems naming the task', () {
    final refusals = <String, VikunjaFailure>{
      'a cycle': const DomainError(409, code: 4023),
      'a relation to itself': const DomainError(400, code: 4010),
      'an unknown kind on v1': const DomainError(400, code: 4007),
      'an unknown kind on v2': const ValidationFailed(
        fieldErrors: {
          'relation_kind': ['invalid'],
        },
      ),
      'the other task gone': const RelatedTaskMissing(2),
    };
    for (final MapEntry(key: what, value: failure) in refusals.entries) {
      test(what, () async {
        await queue(
          1,
          TaskChanges(relations: add(TaskRelationKind.related, 2)),
        );
        write.beforeRequest = (_) async => throw failure;

        await sender.drain();

        final problem = (await db.outboxDao.loadProblems()).single;
        expect(problem.taskId, 1);
        expect(problem.taskTitle, 'One');
        expect(problem.kind, OutboxOperationKind.updateTask);
        expect(problem.failure.runtimeType, failure.runtimeType);
        expect(problem.failure.code, failure.code);
        expect(await db.tasksDao.find(1), isNotNull);
        expect(write.requests, ['update 1']);
      });
    }

    test('the other task gone is told apart from the task itself after a '
        'restart', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 77)));

      await sender.drain();

      final failure = (await db.outboxDao.loadProblems()).single.failure;
      expect(failure, isA<RelatedTaskMissing>());
      expect((failure as RelatedTaskMissing).otherTaskId, 77);
    });

    test('a related task gone from the server stays a problem, but leaves '
        'the op and every stored edge, and the rest of the op got '
        'through', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 77, title: 'Deleted on the web', projectId: 7),
      ]);
      await queue(
        1,
        TaskChanges(
          title: 'Renamed',
          relations: RelationChange(
            added: {
              const TaskRelationRef(TaskRelationKind.related, 77),
              const TaskRelationRef(TaskRelationKind.blocking, 2),
            },
          ),
        ),
      );
      expect(await edgesOf(77), {
        TaskRelationKind.related: [1],
      });

      await sender.drain();

      final problem = (await db.outboxDao.loadProblems()).single;
      expect(problem.failure, isA<RelatedTaskMissing>());
      final op = (await db.outboxDao.find(problem.operationId))!;
      expect(
        decodeTaskChanges(op.payload),
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.blocking, 2),
        ),
      );
      expect(write.serverTasks[1]!.title, 'Renamed');
      expect(serverEdgesOf(1), {
        TaskRelationKind.blocking: [2],
      });
      expect(await edgesOf(1), {
        TaskRelationKind.blocking: [2],
      });
      expect(await edgesOf(77), isEmpty);
    });

    test('an edit merged into that failed op goes out without the gone '
        'task, and Retry succeeds', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 77)));
      await sender.drain();
      expect(await db.outboxDao.loadProblems(), hasLength(1));

      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 2)));
      await sender.drain();

      expect(await db.outboxDao.count(), 0);
      expect(serverEdgesOf(1), {
        TaskRelationKind.related: [2],
      });
      expect(
        write.updates.single.$2.relations,
        add(TaskRelationKind.related, 2),
      );
    });

    test('the gone task leaves the queued ops of other tasks too; a failed '
        'one goes back to the queue', () async {
      await db.tasksDao.upsertAll([
        sampleTask(id: 3, title: 'Three', projectId: 7),
      ]);
      write.serverTasks[3] = sampleTask(id: 3, title: 'Three', projectId: 7);
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 77)));
      await queue(
        2,
        TaskChanges(
          title: 'Two again',
          relations: add(TaskRelationKind.precedes, 77),
        ),
      );
      await queue(3, TaskChanges(relations: add(TaskRelationKind.follows, 77)));
      final ops = await db.outboxDao.all();
      await db.outboxDao.markFailed(ops[1].id, const ServerFailure(500));

      await db.outboxDao.markFailed(ops[0].id, const RelatedTaskMissing(77));

      final left = await db.outboxDao.all();
      expect([for (final op in left) op.taskId], [1, 2]);
      expect(left[0].state, OutboxState.failed.name);
      expect(decodeTaskChanges(left[0].payload).isEmpty, isTrue);
      expect(left[1].state, OutboxState.pending.name);
      expect(
        decodeTaskChanges(left[1].payload),
        const TaskChanges(title: 'Two again'),
      );
    });

    test("Discard restores the task and the other task's edge from the "
        'server', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.blocking, 2)));
      write.beforeRequest = (_) async =>
          throw const DomainError(409, code: 4023);
      await sender.drain();
      expect(await edgesOf(2), {
        TaskRelationKind.blocked: [1],
      });
      final problem = (await db.outboxDao.loadProblems()).single;

      await sender.discard(problem.operationId);

      expect(await db.outboxDao.count(), 0);
      expect(await edgesOf(1), isEmpty);
      expect(await edgesOf(2), isEmpty);
    });
  });

  test('the relation of a failed update folded into a newer one is sent '
      'with it', () async {
    await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 2)));
    final first = (await db.outboxDao.all()).single;
    await db.outboxDao.claim(first.id, at: now);
    await queue(1, const TaskChanges(title: 'Renamed'));
    await db.outboxDao.markFailed(first.id, const Forbidden(code: 7003));

    await sender.drain();

    expect(
      write.updates.single.$2,
      TaskChanges(
        title: 'Renamed',
        relations: add(TaskRelationKind.related, 2),
      ),
    );
  });
}
