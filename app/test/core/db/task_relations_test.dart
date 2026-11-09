import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/task_edits.dart';
import '../../helpers/test_database.dart';

// Relations through the outbox: the task's edge and the other task's
// inverse edge change with the queue write, temporary ids on either side
// follow the remap, an op naming an unanswered create waits, and a pull
// keeps what is still queued.
void main() {
  late AppDatabase db;
  final now = DateTime.utc(2026, 10, 13, 12);
  final later = DateTime.utc(2026, 10, 13, 12, 5);
  final one = sampleTask(id: 1, title: 'One', projectId: 7);
  final two = sampleTask(id: 2, title: 'Two', projectId: 7);
  final three = sampleTask(id: 3, title: 'Three', projectId: 7);

  RelationChange add(TaskRelationKind kind, int other) =>
      RelationChange(added: {TaskRelationRef(kind, other)});

  RelationChange remove(TaskRelationKind kind, int other) =>
      RelationChange(removed: {TaskRelationRef(kind, other)});

  Task withEdges(Task task, Map<TaskRelationKind, List<Task>> edges) =>
      task.copyWith(relatedTasks: edges);

  setUp(() async {
    db = testDatabase();
    await db.tasksDao.upsertAll([one, two, three], syncRunId: 'run');
  });

  Future<bool> queue(int id, TaskChanges changes) =>
      db.outboxDao.queueUpdate(id, changes, now: now);

  Future<int> create(String title) =>
      db.outboxDao.queueCreate(NewTask(projectId: 7, title: title), now: now);

  Future<List<OutboxRow>> ops() => db.outboxDao.all();

  Future<Task> task(int id) async => (await db.tasksDao.find(id))!;

  Future<Map<TaskRelationKind, List<int>>> edgesOf(int id) async => {
    for (final MapEntry(:key, :value) in (await task(id)).relatedTasks.entries)
      key: [for (final other in value) other.id],
  };

  Future<Set<(int, int, String)>> storedEdges() async => {
    for (final row in await db.select(db.taskRelations).get())
      (row.taskId, row.otherTaskId, row.kind),
  };

  Future<TaskChanges?> pendingOf(int id) async {
    final json = (await db.tasksDao.findRow(id))!.pendingChanges;
    return json == null ? null : decodeTaskChanges(json);
  }

  Future<void> completeCreate(int localId, int serverId) async {
    final op = (await ops()).firstWhere(
      (op) =>
          op.taskId == localId &&
          op.kind == OutboxOperationKind.createTask.name,
    );
    await db.outboxDao.completeCreate(
      op.id,
      taskFromNewTask(decodeNewTask(op.payload), id: serverId, now: later),
      at: later,
    );
  }

  group('queueing', () {
    test('a relation goes onto the task and, inverted, onto the other task, '
        'and is queued as a delta', () async {
      final changes = TaskChanges(
        relations: add(TaskRelationKind.parentTask, 1),
      );

      expect(await queue(2, changes), isTrue);

      expect(await edgesOf(2), {
        TaskRelationKind.parentTask: [1],
      });
      expect(await edgesOf(1), {
        TaskRelationKind.subtask: [2],
      });
      final op = (await ops()).single;
      expect(op.taskId, 2);
      expect(decodeTaskChanges(op.payload), changes);
      expect(await pendingOf(2), changes);
      expect(await pendingOf(1), isNull);
    });

    test('every kind has its inverse on the other task', () async {
      const inverse = {
        TaskRelationKind.subtask: TaskRelationKind.parentTask,
        TaskRelationKind.parentTask: TaskRelationKind.subtask,
        TaskRelationKind.related: TaskRelationKind.related,
        TaskRelationKind.duplicateOf: TaskRelationKind.duplicates,
        TaskRelationKind.duplicates: TaskRelationKind.duplicateOf,
        TaskRelationKind.blocking: TaskRelationKind.blocked,
        TaskRelationKind.blocked: TaskRelationKind.blocking,
        TaskRelationKind.precedes: TaskRelationKind.follows,
        TaskRelationKind.follows: TaskRelationKind.precedes,
        TaskRelationKind.copiedFrom: TaskRelationKind.copiedTo,
        TaskRelationKind.copiedTo: TaskRelationKind.copiedFrom,
      };
      expect(inverse.keys, unorderedEquals(TaskRelationKind.values));

      for (final MapEntry(key: kind, value: inverted) in inverse.entries) {
        await queue(1, TaskChanges(relations: add(kind, 2)));
        expect((await edgesOf(2))[inverted], [1], reason: '$kind');
        await queue(1, TaskChanges(relations: remove(kind, 2)));
        expect(await edgesOf(2), isEmpty, reason: '$kind');
      }
    });

    test('a removed relation leaves both tasks', () async {
      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.blocking: [two],
        }),
        withEdges(two, {
          TaskRelationKind.blocked: [one],
        }),
      ]);

      await queue(
        1,
        TaskChanges(relations: remove(TaskRelationKind.blocking, 2)),
      );

      expect(await edgesOf(1), isEmpty);
      expect(await edgesOf(2), isEmpty);
      expect(await storedEdges(), isEmpty);
    });

    test('an edge to a task this device does not have is kept for the task '
        'alone and shows once that task arrives', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 99)));

      expect(await storedEdges(), {(1, 99, 'related')});
      expect(await edgesOf(1), isEmpty);

      await db.tasksDao.upsertAll([
        sampleTask(id: 99, title: 'Far', projectId: 8),
      ]);

      expect(await edgesOf(1), {
        TaskRelationKind.related: [99],
      });
    });

    test('an add and a remove of the same edge before the send leave the '
        'remove', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 2)));
      await queue(
        1,
        TaskChanges(relations: remove(TaskRelationKind.related, 2)),
      );

      expect(await storedEdges(), isEmpty);
      expect(
        decodeTaskChanges((await ops()).single.payload).relations,
        remove(TaskRelationKind.related, 2),
      );
    });

    test('a related task queued for deletion is not shown', () async {
      await queue(1, TaskChanges(relations: add(TaskRelationKind.related, 2)));

      await db.outboxDao.queueDelete(2, now: now);

      expect(await edgesOf(1), isEmpty);
    });

    test('a failed label add forgotten with its label leaves the relations '
        'of the same update queued', () async {
      await db.labelsDao.upsertAll([sampleLabel(id: 10, title: 'gone')]);
      await queue(
        1,
        TaskChanges(
          labels: const IdSetChange(added: {10}),
          relations: add(TaskRelationKind.related, 2),
        ),
      );

      await db.outboxDao.forgetLabels({10});

      expect(
        decodeTaskChanges((await ops()).single.payload),
        TaskChanges(relations: add(TaskRelationKind.related, 2)),
      );
    });
  });

  group('temporary ids', () {
    test('a relation on an unsent create stays queued behind it, and may '
        'name another unsent create', () async {
      final parent = await create('Parent');
      final child = await create('Child');

      await queue(
        child,
        TaskChanges(relations: add(TaskRelationKind.parentTask, parent)),
      );

      final all = await ops();
      expect(all.map((op) => (op.kind, op.taskId)), [
        (OutboxOperationKind.createTask.name, parent),
        (OutboxOperationKind.createTask.name, child),
        (OutboxOperationKind.updateTask.name, child),
      ]);
      expect(decodeNewTask(all[1].payload).title, 'Child');
      expect(
        decodeTaskChanges(all[2].payload).relations,
        add(TaskRelationKind.parentTask, parent),
      );
      expect(await edgesOf(child), {
        TaskRelationKind.parentTask: [parent],
      });
      expect(await edgesOf(parent), {
        TaskRelationKind.subtask: [child],
      });
    });

    test('the remap of the other task rewrites the queued relation, the '
        'pending changes and the stored edges; the remap of the task itself '
        'moves the op', () async {
      final parent = await create('Parent');
      final child = await create('Child');
      await queue(
        child,
        TaskChanges(relations: add(TaskRelationKind.parentTask, parent)),
      );

      await completeCreate(parent, 101);

      final update = (await ops()).last;
      expect(update.taskId, child);
      expect(
        decodeTaskChanges(update.payload).relations,
        add(TaskRelationKind.parentTask, 101),
      );
      expect(
        (await pendingOf(child))!.relations,
        add(TaskRelationKind.parentTask, 101),
      );
      expect(await edgesOf(child), {
        TaskRelationKind.parentTask: [101],
      });
      expect(await edgesOf(101), {
        TaskRelationKind.subtask: [child],
      });

      await completeCreate(child, 102);

      final moved = (await ops()).single;
      expect(moved.taskId, 102);
      expect(
        decodeTaskChanges(moved.payload).relations,
        add(TaskRelationKind.parentTask, 101),
      );
      expect(await edgesOf(102), {
        TaskRelationKind.parentTask: [101],
      });
      expect(await edgesOf(101), {
        TaskRelationKind.subtask: [102],
      });
      expect(await storedEdges(), {
        (102, 101, 'parenttask'),
        (101, 102, 'subtask'),
      });
    });

    test('a relation naming a temporary id whose create was answered names '
        'the server id', () async {
      final created = await create('New');
      await completeCreate(created, 101);

      await queue(
        2,
        TaskChanges(relations: add(TaskRelationKind.related, created)),
      );

      expect(
        decodeTaskChanges((await ops()).single.payload).relations,
        add(TaskRelationKind.related, 101),
      );
      expect(await edgesOf(101), {
        TaskRelationKind.related: [2],
      });
    });

    test('an update naming a create behind it waits; the create goes first '
        'and the update follows with the server id', () async {
      await queue(1, const TaskChanges(title: 'Renamed'));
      final created = await create('New');
      await queue(
        1,
        TaskChanges(relations: add(TaskRelationKind.precedes, created)),
      );

      final update = (await ops()).first;
      expect(update.taskId, 1);
      expect(await db.outboxDao.waitsForRelatedCreate(update), isTrue);
      final first = (await db.outboxDao.nextInLine())!;
      expect(first.kind, OutboxOperationKind.createTask.name);
      expect(first.taskId, created);

      await completeCreate(created, 101);

      final next = (await db.outboxDao.nextInLine())!;
      expect(next.id, update.id);
      expect(
        decodeTaskChanges(next.payload),
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.precedes, 101),
        ),
      );
      expect(await db.outboxDao.waitsForRelatedCreate(next), isFalse);
    });

    test('an update naming a failed create waits until it is retried or '
        'discarded', () async {
      final created = await create('New');
      await queue(
        1,
        TaskChanges(relations: add(TaskRelationKind.related, created)),
      );
      final createOp = (await ops()).first;
      await db.outboxDao.markFailed(
        createOp.id,
        const DomainError(400, code: 4001),
      );

      expect(await db.outboxDao.nextInLine(), isNull);

      await db.outboxDao.cancelCreate(created);

      expect(await ops(), isEmpty);
      expect(await pendingOf(1), isNull);
      expect(await storedEdges(), isEmpty);
    });

    test('cancelling a create drops it from the relations of other tasks; '
        'an update left with other fields keeps them', () async {
      final created = await create('New');
      await queue(
        1,
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.related, created),
        ),
      );
      await queue(
        2,
        TaskChanges(relations: add(TaskRelationKind.blocked, created)),
      );

      await db.outboxDao.cancelCreate(created);

      final left = (await ops()).single;
      expect(left.taskId, 1);
      expect(
        decodeTaskChanges(left.payload),
        const TaskChanges(title: 'Renamed'),
      );
      expect(await pendingOf(1), const TaskChanges(title: 'Renamed'));
      expect(await pendingOf(2), isNull);
      expect(await storedEdges(), isEmpty);
    });

    test('an edge to a create that was cancelled is not queued', () async {
      final created = await create('Gone');
      await db.outboxDao.cancelCreate(created);

      await queue(
        1,
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.related, created),
        ),
      );

      expect(
        decodeTaskChanges((await ops()).single.payload),
        const TaskChanges(title: 'Renamed'),
      );
      expect(await storedEdges(), isEmpty);
    });

    test('a rejected create takes the edit behind it but leaves its relation '
        'queued behind it', () async {
      final created = await create('New');
      final createOp = (await ops()).single;
      await db.outboxDao.claim(createOp.id, at: now);
      await queue(
        created,
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.related, 2),
        ),
      );

      await db.outboxDao.markFailed(
        createOp.id,
        const DomainError(400, code: 4001),
      );

      final all = await ops();
      expect(decodeNewTask(all.first.payload).title, 'Renamed');
      expect(
        decodeTaskChanges(all.last.payload),
        TaskChanges(relations: add(TaskRelationKind.related, 2)),
      );
    });
  });

  group('sync', () {
    test('a pull keeps a queued relation on the task and its inverse edge on '
        'the other task', () async {
      await queue(
        2,
        TaskChanges(relations: add(TaskRelationKind.parentTask, 1)),
      );

      await db.tasksDao.upsertAll([one, two, three]);

      expect(await edgesOf(2), {
        TaskRelationKind.parentTask: [1],
      });
      expect(await edgesOf(1), {
        TaskRelationKind.subtask: [2],
      });
    });

    test('a pull keeps a queued removal on both tasks, and the edges the '
        'server has besides', () async {
      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.related: [two, three],
        }),
        withEdges(two, {
          TaskRelationKind.related: [one],
        }),
        withEdges(three, {
          TaskRelationKind.related: [one],
        }),
      ]);
      await queue(
        1,
        TaskChanges(relations: remove(TaskRelationKind.related, 2)),
      );

      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.related: [two, three],
        }),
        withEdges(two, {
          TaskRelationKind.related: [one],
        }),
      ]);

      expect(await edgesOf(1), {
        TaskRelationKind.related: [3],
      });
      expect(await edgesOf(2), isEmpty);
      expect(await edgesOf(3), {
        TaskRelationKind.related: [1],
      });
    });

    test('once the change is sent, the pulled edges are the truth', () async {
      await queue(
        2,
        TaskChanges(relations: add(TaskRelationKind.parentTask, 1)),
      );
      await db.outboxDao.remove((await ops()).single.id);

      await db.tasksDao.upsertAll([one, two]);

      expect(await edgesOf(1), isEmpty);
      expect(await edgesOf(2), isEmpty);
    });

    test(
      'a pull of a task whose parent was set elsewhere gives the local '
      'parent the subtask edge, as the server bumps only the child',
      () async {
        await db.tasksDao.upsertAll([
          withEdges(three, {
            TaskRelationKind.parentTask: [one],
          }),
        ]);

        expect(await edgesOf(1), {
          TaskRelationKind.subtask: [3],
        });
        expect(await edgesOf(2), isEmpty);
      },
    );

    test('a pull of a parent without the relation removes the parent edge '
        'its local subtask holds', () async {
      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.subtask: [three],
        }),
        withEdges(three, {
          TaskRelationKind.parentTask: [one],
        }),
      ]);

      await db.tasksDao.upsertAll([one]);

      expect(await edgesOf(3), isEmpty);
      expect(await storedEdges(), isEmpty);
    });

    test('a pull keeps the queued add and remove another local task has '
        'naming the pulled task', () async {
      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.related: [three],
        }),
        withEdges(three, {
          TaskRelationKind.related: [one],
        }),
      ]);
      await queue(2, TaskChanges(relations: add(TaskRelationKind.blocking, 1)));
      await queue(
        3,
        TaskChanges(relations: remove(TaskRelationKind.related, 1)),
      );

      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.related: [three],
        }),
      ]);

      expect(await edgesOf(1), {
        TaskRelationKind.blocked: [2],
      });
      expect(await edgesOf(2), {
        TaskRelationKind.blocking: [1],
      });
      expect(await edgesOf(3), isEmpty);
    });

    test('an edge to a task this device does not have stays as it is, on '
        'the pulled task and on the others', () async {
      await db.tasksDao.upsertAll([
        withEdges(two, {
          TaskRelationKind.related: [
            sampleTask(id: 99, title: 'Elsewhere', projectId: 8),
          ],
        }),
      ]);

      await db.tasksDao.upsertAll([
        withEdges(one, {
          TaskRelationKind.precedes: [
            sampleTask(id: 98, title: 'Far away', projectId: 8),
          ],
        }),
      ]);

      expect(await storedEdges(), {(1, 98, 'precedes'), (2, 99, 'related')});
    });

    test('a task the sync purges leaves the queued relation changes that '
        'name it and the stored edges', () async {
      await queue(
        1,
        TaskChanges(
          title: 'Renamed',
          relations: RelationChange(
            added: {
              const TaskRelationRef(TaskRelationKind.related, 2),
              const TaskRelationRef(TaskRelationKind.related, 3),
            },
          ),
        ),
      );
      await queue(
        3,
        TaskChanges(relations: remove(TaskRelationKind.blocked, 2)),
      );

      expect(await db.tasksDao.purgeInProjectExcept(7, {1}), 1);

      final left = await ops();
      expect([for (final op in left) op.taskId], [1]);
      expect(
        decodeTaskChanges(left.single.payload),
        TaskChanges(
          title: 'Renamed',
          relations: add(TaskRelationKind.related, 3),
        ),
      );
      expect(await pendingOf(1), decodeTaskChanges(left.single.payload));
      expect(await pendingOf(3), isNull);
      expect(await storedEdges(), {(1, 3, 'related'), (3, 1, 'related')});
    });

    test('a pull of a task created here and answered keeps the inverse edge '
        'of a queued relation that names it', () async {
      final created = await create('New');
      await queue(
        2,
        TaskChanges(relations: add(TaskRelationKind.related, created)),
      );
      await completeCreate(created, 101);

      await db.tasksDao.upsertAll([
        sampleTask(id: 101, title: 'New', projectId: 7),
      ]);

      expect(await edgesOf(101), {
        TaskRelationKind.related: [2],
      });
    });
  });
}
