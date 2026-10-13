import 'dart:math';

import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/sync_state.dart';
import 'package:vikunja_mobile/core/db/tables/task_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/new_task_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

part 'outbox_dao.g.dart';

enum OutboxState { pending, sending, failed }

/// The queue of task writes and the local side of each write: a queued
/// change is applied to the task row in the same transaction, so the row
/// shows it at once, and `pending_changes` keeps the merged unsent fields
/// for the sync's upserts.
///
/// A task created here lives under a temporary negative id until its
/// create is answered. While the create has not left the device an edit
/// folds into it and a delete cancels it; once it may be on the server
/// (in flight, or without an answer) later ops queue behind it under the
/// temporary id, which [completeCreate] rewrites to the server id. A
/// relation may name such a task as the other task too: the remap rewrites
/// those references, and an op that still names a temporary id waits.
@DriftAccessor(tables: [Outbox, Tasks, TaskIdRemaps, SyncState])
final class OutboxDao extends DatabaseAccessor<AppDatabase>
    with _$OutboxDaoMixin {
  new(super.attachedDatabase);

  /// `sync_state` key: how many temporary ids were handed out; the next
  /// one is minus one more. Never reused, so a remap stays unambiguous.
  static const localTaskIdsKey = 'local_task_ids';

  final _random = Random.secure();

  /// Inserts the task under the next temporary id, with its reminders, and
  /// queues its create; returns that id. The row has no `updated`: that is
  /// a server time, and the sync's watermark must not take a device time.
  Future<int> queueCreate(NewTask task, {required DateTime now}) =>
      transaction(() async {
        final id = await _nextLocalId();
        final row = TaskRow(
          id: id,
          projectId: task.projectId,
          title: task.title,
          description: task.description,
          done: false,
          dueDate: task.dueDate?.toUtc(),
          startDate: task.startDate?.toUtc(),
          endDate: task.endDate?.toUtc(),
          priority: task.priority.value,
          percentDone: task.percentDone,
          hexColor: task.hexColor,
          identifier: '',
          taskIndex: 0,
          isFavorite: task.isFavorite,
          position: 0,
          repeatAfter: task.repeatAfter.inSeconds,
          repeatMode: task.repeatMode.value,
          bucketId: 0,
          created: now.toUtc(),
          pendingDelete: false,
        );
        await into(tasks).insert(row);
        if (task.reminders.isNotEmpty) {
          await attachedDatabase.tasksDao.applyChildChanges(
            row,
            TaskChanges(reminders: task.reminders),
          );
        }
        await _insert(
          kind: OutboxOperationKind.createTask,
          taskId: id,
          payload: encodeNewTask(task),
          now: now,
        );
        return id;
      });

  /// Applies [requested] to the row and its labels, assignees, reminders
  /// and relations and queues it, merged into the task's unsent update op
  /// when there is one, or into its create while that has not left the
  /// device: reminders fold into the create, while labels, assignees,
  /// relations and done, which need the task's id on the server, stay
  /// queued behind it. A temporary id whose create was answered meanwhile
  /// is followed to the server id, the task's own and those its relations
  /// name. False when the task is unknown here or queued for deletion.
  Future<bool> queueUpdate(
    int localOrServerId,
    TaskChanges requested, {
    required DateTime now,
  }) => transaction(() async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    final changes = await _withResolvedRelations(requested);
    final row = await _row(taskId);
    if (row == null || row.pendingDelete) return false;
    var queued = changes;
    if (taskId < 0) {
      final create = await _createOf(taskId);
      if (create != null && _neverReachedServer(create)) {
        await _write(
          create.id,
          _retaken(
            encodeNewTask(
              applyChangesToNewTask(decodeNewTask(create.payload), changes),
            ),
          ),
        );
        queued = changesAfterCreate(changes);
      }
    }
    var pending = _pendingOf(row);
    if (!queued.isEmpty) {
      final existing = await _unsentUpdate(taskId);
      if (existing != null) {
        final merged = decodeTaskChanges(existing.payload).merge(queued);
        await _write(existing.id, _retaken(encodeTaskChanges(merged)));
      } else {
        await _insert(
          kind: OutboxOperationKind.updateTask,
          taskId: taskId,
          payload: encodeTaskChanges(queued),
          now: now,
        );
      }
      pending = pending.merge(queued);
    }
    final applied = applyTaskChanges(row, changes, now: now).copyWith(
      pendingChanges: Value(
        pending.isEmpty ? null : encodeTaskChanges(pending),
      ),
    );
    await update(tasks).replace(applied);
    await attachedDatabase.tasksDao.applyChildChanges(applied, changes);
    return true;
  });

  /// Hides the row and queues the delete; an unsent update op of the task
  /// is dropped, because the delete makes it moot, and a create that has
  /// not left the device is cancelled with the row. A temporary id whose
  /// create was answered meanwhile is followed to the server id. False
  /// when the task is unknown here or already queued for deletion.
  Future<bool> queueDelete(int localOrServerId, {required DateTime now}) =>
      transaction(() async {
        final taskId = await attachedDatabase.tasksDao.resolveId(
          localOrServerId,
        );
        final row = await _row(taskId);
        if (row == null || row.pendingDelete) return false;
        if (taskId < 0) {
          final create = await _createOf(taskId);
          if (create == null || _neverReachedServer(create)) {
            await cancelCreate(taskId);
            return true;
          }
        }
        await (delete(outbox)..where(
              (o) =>
                  o.taskId.equals(taskId) &
                  o.kind.equals(OutboxOperationKind.updateTask.name) &
                  o.state.equals(OutboxState.sending.name).not(),
            ))
            .go();
        await _insert(
          kind: OutboxOperationKind.deleteTask,
          taskId: taskId,
          payload: '{}',
          now: now,
        );
        await (update(tasks)..where((t) => t.id.equals(taskId))).write(
          const TasksCompanion(
            pendingDelete: Value(true),
            pendingChanges: Value(null),
          ),
        );
        return true;
      });

  /// The head of the queue: the oldest op that has not failed, whatever
  /// its `next_attempt_at`; the sender waits for that itself. It may be
  /// `sending`, in another isolate or left by a run that died, and then
  /// nothing may overtake it. An update or delete under a temporary id
  /// waits for its create, which is ahead of it or failed; so does an
  /// update whose relations name a task whose create has not been
  /// answered, wherever that create is.
  Future<OutboxRow?> nextInLine() async {
    var after = 0;
    while (true) {
      final op =
          await (select(outbox)
                ..where(
                  (o) =>
                      o.sequence.isBiggerThanValue(after) &
                      o.state.equals(OutboxState.failed.name).not() &
                      (o.taskId.isBiggerThanValue(0) |
                          o.kind.equals(OutboxOperationKind.createTask.name)),
                )
                ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
                ..limit(1))
              .getSingleOrNull();
      if (op == null ||
          op.state != OutboxState.pending.name ||
          !await waitsForRelatedCreate(op)) {
        return op;
      }
      after = op.sequence;
    }
  }

  /// Whether [op] names in its relations a task created here whose create
  /// has not been answered.
  Future<bool> waitsForRelatedCreate(OutboxRow op) async {
    if (op.kind != OutboxOperationKind.updateTask.name ||
        !op.payload.contains('"relations"')) {
      return false;
    }
    for (final id in relatedTaskIds(decodeTaskChanges(op.payload))) {
      if (id < 0 && await attachedDatabase.tasksDao.resolveId(id) < 0) {
        return true;
      }
    }
    return false;
  }

  Future<OutboxRow?> find(String id) =>
      (select(outbox)..where((o) => o.id.equals(id))).getSingleOrNull();

  /// Every op in send order.
  Future<List<OutboxRow>> all() =>
      (select(outbox)..orderBy([(o) => OrderingTerm.asc(o.sequence)])).get();

  Future<void> markSending(String id, {required DateTime at}) => _write(
    id,
    OutboxCompanion(
      state: Value(OutboxState.sending.name),
      lastAttemptAt: Value(at.toUtc()),
    ),
  );

  /// Marks the op `sending` and returns it as it is now, so an edit merged
  /// in after the sender read the queue is sent too. Null when the op is
  /// no longer pending: a delete replaced it, or the sender already has it.
  Future<OutboxRow?> claim(String id, {required DateTime at}) => transaction(
    () async {
      final claimed =
          await (update(outbox)..where(
                (o) =>
                    o.id.equals(id) & o.state.equals(OutboxState.pending.name),
              ))
              .write(
                OutboxCompanion(
                  state: Value(OutboxState.sending.name),
                  lastAttemptAt: Value(at.toUtc()),
                ),
              );
      return claimed == 0 ? null : await find(id);
    },
  );

  /// A claimed op that cannot go yet goes back to the queue as it was.
  Future<void> unclaim(String id) =>
      (update(outbox)..where(
            (o) => o.id.equals(id) & o.state.equals(OutboxState.sending.name),
          ))
          .write(OutboxCompanion(state: Value(OutboxState.pending.name)));

  /// [attempts] is the count including the one that just failed.
  Future<void> scheduleRetry(
    String id, {
    required int attempts,
    required VikunjaFailure failure,
    required DateTime nextAttemptAt,
  }) => _write(
    id,
    OutboxCompanion(
      state: Value(OutboxState.pending.name),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt.toUtc()),
      lastError: Value(encodeFailure(failure)),
    ),
  );

  /// Back to pending without counting an attempt: the session must be
  /// signed in again before the op can go.
  Future<void> holdForSession(String id, VikunjaFailure failure) => _write(
    id,
    OutboxCompanion(
      state: Value(OutboxState.pending.name),
      nextAttemptAt: const Value(null),
      lastError: Value(encodeFailure(failure)),
    ),
  );

  /// A create whose request may have reached the server: the first such
  /// attempt's time stays, so the lookup window covers every attempt.
  Future<void> markUncertain(String id, {required DateTime sentAt}) =>
      transaction(() async {
        final op = await find(id);
        if (op == null || op.sentAt != null) return;
        await _write(id, OutboxCompanion(sentAt: Value(sentAt.toUtc())));
      });

  /// A failed op whose task has a newer queued op is folded into that op
  /// instead: an update takes the fields the newer update does not set, a
  /// delete makes it moot. So a task never has two ops the sender could
  /// send in either order, and a Retry can never overwrite a newer edit.
  /// A rejected create takes the edit queued behind it while it was in
  /// flight, so that edit cannot revert a later one folded into the
  /// create; only done, labels and assignees stay queued behind it. A
  /// delete behind it cancels it: the server never had the task, so both
  /// go. A related task the server no longer has is forgotten (see
  /// [forgetRelatedTasks]), in this op too, which stays failed to say why
  /// the edge is gone: the write client tried every other request of the
  /// op first, so it holds nothing back, and an edit merged into it later
  /// goes out without that edge.
  Future<void> markFailed(String id, VikunjaFailure failure) =>
      transaction(() async {
        final op = await find(id);
        if (op == null) return;
        var payload = op.payload;
        if (failure case RelatedTaskMissing(:final otherTaskId)
            when op.kind == OutboxOperationKind.updateTask.name) {
          await _forgetRelatedTasks({otherTaskId}, except: op.id);
          payload = encodeTaskChanges(
            withoutRelatedTasks(decodeTaskChanges(payload), {otherTaskId}),
          );
        }
        final newer = await _newerUnsent(op);
        if (op.kind == OutboxOperationKind.createTask.name) {
          if (newer?.kind == OutboxOperationKind.deleteTask.name) {
            await cancelCreate(op.taskId);
            return;
          }
          if (newer != null) {
            final edit = decodeTaskChanges(newer.payload);
            payload = encodeNewTask(
              applyChangesToNewTask(decodeNewTask(payload), edit),
            );
            final rest = changesAfterCreate(edit);
            if (rest.isEmpty) {
              await remove(newer.id);
            } else {
              await _write(
                newer.id,
                OutboxCompanion(payload: Value(encodeTaskChanges(rest))),
              );
              await _refreshPendingChanges(op.taskId);
            }
          }
          await _write(
            id,
            OutboxCompanion(
              payload: Value(payload),
              state: Value(OutboxState.failed.name),
              nextAttemptAt: const Value(null),
              lastError: Value(encodeFailure(failure)),
              sentAt: const Value(null),
            ),
          );
          return;
        }
        if (newer == null) {
          await _write(
            id,
            OutboxCompanion(
              payload: Value(payload),
              state: Value(OutboxState.failed.name),
              nextAttemptAt: const Value(null),
              lastError: Value(encodeFailure(failure)),
            ),
          );
          await _refreshPendingChanges(op.taskId);
          return;
        }
        if (newer.kind == OutboxOperationKind.updateTask.name) {
          final folded = decodeTaskChanges(payload)
              .merge(decodeTaskChanges(newer.payload));
          await _write(
            newer.id,
            OutboxCompanion(payload: Value(encodeTaskChanges(folded))),
          );
        }
        await remove(op.id);
      });

  /// Labels gone from the server for this user (deleted, or no longer
  /// visible) can never be attached or detached, so their ids leave every
  /// unsent update: an add of one would otherwise fail the op for good and
  /// hold back every edit merged into it. An op left empty goes; a failed
  /// one that changed goes back to the queue, since what failed may have
  /// been that label.
  Future<void> forgetLabels(Set<int> labelIds) => transaction(() async {
    if (labelIds.isEmpty) return;
    final ops =
        await (select(outbox)..where(
              (o) =>
                  o.kind.equals(OutboxOperationKind.updateTask.name) &
                  o.state.equals(OutboxState.sending.name).not(),
            ))
            .get();
    for (final op in ops) {
      final changes = decodeTaskChanges(op.payload);
      final labels = changes.labels;
      if (labels == null ||
          (!labels.added.any(labelIds.contains) &&
              !labels.removed.any(labelIds.contains))) {
        continue;
      }
      final kept = withoutLabels(changes, labelIds);
      if (kept.isEmpty) {
        await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      } else if (op.state == OutboxState.failed.name) {
        await _write(op.id, _retaken(encodeTaskChanges(kept)));
      } else {
        await _write(
          op.id,
          OutboxCompanion(payload: Value(encodeTaskChanges(kept))),
        );
      }
      await _refreshPendingChanges(op.taskId);
    }
  });

  /// Tasks the server no longer has for this user (deleted, or no longer
  /// visible) can never be related to, so edges naming them leave every
  /// unsent update and every stored row, as [forgetLabels] does for
  /// labels. An op left empty goes; a failed one that changed goes back to
  /// the queue, since what failed may have been that edge.
  Future<void> forgetRelatedTasks(Set<int> taskIds) =>
      transaction(() => _forgetRelatedTasks(taskIds));

  Future<void> _forgetRelatedTasks(Set<int> taskIds, {String? except}) async {
    if (taskIds.isEmpty) return;
    final query = select(outbox)
      ..where(
        (o) =>
            o.kind.equals(OutboxOperationKind.updateTask.name) &
            o.payload.like('%"relations"%') &
            o.state.equals(OutboxState.sending.name).not(),
      );
    if (except != null) query.where((o) => o.id.equals(except).not());
    for (final op in await query.get()) {
      final changes = decodeTaskChanges(op.payload);
      if (!relatedTaskIds(changes).any(taskIds.contains)) continue;
      final kept = withoutRelatedTasks(changes, taskIds);
      if (kept.isEmpty) {
        await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      } else if (op.state == OutboxState.failed.name) {
        await _write(op.id, _retaken(encodeTaskChanges(kept)));
      } else {
        await _write(
          op.id,
          OutboxCompanion(payload: Value(encodeTaskChanges(kept))),
        );
      }
      await _refreshPendingChanges(op.taskId);
    }
    await attachedDatabase.tasksDao.forgetRelatedTasks(taskIds);
  }

  /// A failed op goes back to the queue with a clean slate.
  Future<void> retry(String id) => _write(
    id,
    OutboxCompanion(
      state: Value(OutboxState.pending.name),
      attempts: const Value(0),
      nextAttemptAt: const Value(null),
      lastError: const Value(null),
    ),
  );

  /// Ops left in `sending` for at least [olderThan] go back to pending: a
  /// killed run, a disposed sender or a failed local apply left them, as
  /// no live sender takes that long over one op. A younger one may still
  /// be on its way in another isolate and stays. A create among them may
  /// have reached the server, so it is marked uncertain as of its attempt
  /// (an earlier `sent_at` stays), and the next attempt looks for the task
  /// before sending it again.
  Future<int> resetSending({
    required DateTime now,
    Duration olderThan = Duration.zero,
  }) => transaction(() async {
    const millis = EpochMillis();
    // A clock set back since the attempt must not hold the op for good.
    final sending =
        outbox.state.equals(OutboxState.sending.name) &
        (outbox.lastAttemptAt.isNull() |
            outbox.lastAttemptAt.isSmallerOrEqualValue(
              millis.toSql(now.subtract(olderThan)),
            ) |
            outbox.lastAttemptAt.isBiggerOrEqualValue(
              millis.toSql(now.add(olderThan)),
            ));
    await (update(outbox)..where(
          (o) => sending & o.kind.equals(OutboxOperationKind.createTask.name),
        ))
        .write(
          OutboxCompanion.custom(
            sentAt: coalesce([
              outbox.sentAt,
              outbox.lastAttemptAt,
              Constant(const EpochMillis().toSql(now)),
            ]),
          ),
        );
    return await (update(outbox)..where((o) => sending)).write(
      OutboxCompanion(state: Value(OutboxState.pending.name)),
    );
  });

  /// Drops every backoff, for "Send now".
  Future<int> clearBackoff() =>
      (update(outbox)..where((o) => o.nextAttemptAt.isNotNull())).write(
        const OutboxCompanion(nextAttemptAt: Value(null)),
      );

  /// Removes the op and recomputes the task's `pending_changes` from the
  /// ops that remain.
  Future<void> remove(String id) => transaction(() async {
    final op = await find(id);
    if (op == null) return;
    await (delete(outbox)..where((o) => o.id.equals(id))).go();
    await _refreshPendingChanges(op.taskId);
  });

  Future<void> _refreshPendingChanges(int taskId) async {
    final remaining = await pendingChangesFor(taskId);
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        pendingChanges: Value(
          remaining == null ? null : encodeTaskChanges(remaining),
        ),
      ),
    );
  }

  /// Every op of a task that is gone, whatever its state.
  Future<void> removeAllOf(int taskId) =>
      (delete(outbox)..where((o) => o.taskId.equals(taskId))).go();

  /// A task created here that the server will never be asked for: the
  /// row and every op go, nothing is sent, and relations of other tasks
  /// that name it are dropped from their queued changes, which would
  /// otherwise wait for it forever.
  Future<void> cancelCreate(int localId) => transaction(() async {
    await removeAllOf(localId);
    await (delete(tasks)..where((t) => t.id.equals(localId))).go();
    await _rewriteRelationRefs(localId, null);
    await attachedDatabase.tasksDao.forgetRelatedTasks({localId});
  });

  /// The server has the task as [created]: the row moves to the server id
  /// with the response applied, the ops queued behind the create follow
  /// (their fields, labels, assignees, reminders and relations stay on top
  /// of the response), the remap is recorded and the create op goes. A row
  /// the sync pulled meanwhile under the server id is replaced. Relations
  /// of other tasks that name the temporary id, queued or stored, name the
  /// server id from now on.
  Future<void> completeCreate(
    String operationId,
    Task created, {
    required DateTime at,
  }) => transaction(() async {
    final op = await find(operationId);
    if (op == null) return;
    final localId = op.taskId;
    final local = await _row(localId);
    await (delete(outbox)..where((o) => o.id.equals(operationId))).go();
    await (update(outbox)..where((o) => o.taskId.equals(localId))).write(
      OutboxCompanion(taskId: Value(created.id)),
    );
    await _rewriteRelationRefs(localId, created.id);
    await attachedDatabase.tasksDao.remapRelatedTask(localId, created.id);
    await (delete(tasks)..where((t) => t.id.equals(localId))).go();
    await attachedDatabase.tasksDao.upsertAll([created]);
    final pending = await pendingChangesFor(created.id);
    final deleting = await _hasQueuedDelete(created.id);
    if (pending != null || deleting) {
      var row = (await _row(created.id))!;
      if (pending != null) {
        row = applyTaskChanges(row, pending, now: local?.doneAt ?? at);
      }
      row = row.copyWith(
        pendingChanges: Value(
          pending == null ? null : encodeTaskChanges(pending),
        ),
        pendingDelete: deleting,
      );
      await update(tasks).replace(row);
      if (pending != null) {
        await attachedDatabase.tasksDao.applyChildChanges(row, pending);
      }
    }
    await into(taskIdRemaps).insert(
      TaskIdRemapRow(localId: localId, serverId: created.id, at: at.toUtc()),
      mode: InsertMode.insertOrReplace,
    );
  });

  Future<bool> hasQueuedOps(int taskId) async {
    final op =
        await (select(outbox)
              ..where((o) => o.taskId.equals(taskId))
              ..limit(1))
            .getSingleOrNull();
    return op != null;
  }

  Future<void> clearPendingDelete(int taskId) =>
      (update(tasks)..where((t) => t.id.equals(taskId))).write(
        const TasksCompanion(pendingDelete: Value(false)),
      );

  /// The merge of the task's update ops in send order; null without one.
  Future<TaskChanges?> pendingChangesFor(int taskId) async {
    final ops =
        await (select(outbox)
              ..where(
                (o) =>
                    o.taskId.equals(taskId) &
                    o.kind.equals(OutboxOperationKind.updateTask.name),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
            .get();
    if (ops.isEmpty) return null;
    return ops
        .map((op) => decodeTaskChanges(op.payload))
        .reduce((earlier, later) => earlier.merge(later));
  }

  /// Every queued op, whatever its state: all of them are changes the
  /// server has not accepted yet.
  Stream<int> watchCount() => watchTables({outbox}, count);

  Future<int> count() {
    final count = outbox.id.count();
    final query = selectOnly(outbox)..addColumns([count]);
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// The tasks with a queued op, whatever its state.
  Stream<Set<int>> watchPendingTaskIds() =>
      watchTables({outbox}, loadPendingTaskIds);

  Future<Set<int>> loadPendingTaskIds() async {
    final query = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.taskId]);
    return {for (final row in await query.get()) row.read(outbox.taskId)!};
  }

  Stream<List<SyncProblem>> watchProblems() =>
      watchTables({outbox, tasks}, loadProblems);

  Future<List<SyncProblem>> loadProblems() async {
    final query =
        select(outbox)
            .join([leftOuterJoin(tasks, tasks.id.equalsExp(outbox.taskId))])
          ..where(outbox.state.equals(OutboxState.failed.name))
          ..orderBy([OrderingTerm.asc(outbox.sequence)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        ?_problemOf(row.readTable(outbox), row.readTableOrNull(tasks)),
    ];
  }

  SyncProblem? _problemOf(OutboxRow op, TaskRow? task) {
    final kind = OutboxOperationKind.values.asNameMap()[op.kind];
    final error = op.lastError;
    if (kind == null || error == null) return null;
    return SyncProblem(
      operationId: op.id,
      kind: kind,
      taskId: op.taskId,
      taskTitle: task?.title ?? '',
      failure: decodeFailure(error),
      failedAt: op.lastAttemptAt ?? op.createdAt,
    );
  }

  /// [changes] with every other-task id of its relations followed to the
  /// server id when its create was answered meanwhile.
  ///
  /// A temporary id with neither a row nor a remap is a create that was
  /// cancelled; an edge to it is dropped, as it would wait forever.
  Future<TaskChanges> _withResolvedRelations(TaskChanges changes) async {
    final relations = changes.relations;
    if (relations == null) return changes;
    final resolved = <int, int>{};
    for (final id in relatedTaskIds(changes)) {
      final serverId = await attachedDatabase.tasksDao.resolveId(id);
      if (serverId > 0 || await _row(serverId) != null) {
        resolved[id] = serverId;
      }
    }
    bool known(TaskRelationRef ref) => resolved.containsKey(ref.otherTaskId);
    return withRelations(
      changes,
      RelationChange(
        added: relations.added.where(known).toSet(),
        removed: relations.removed.where(known).toSet(),
      ).mapTaskIds((id) => resolved[id]!),
    );
  }

  /// Every queued relation that names the task [from] names [to] instead,
  /// or is dropped when [to] is null; an update left empty goes. The
  /// tasks' `pending_changes` follow.
  Future<void> _rewriteRelationRefs(int from, int? to) async {
    final ops =
        await (select(outbox)..where(
              (o) =>
                  o.kind.equals(OutboxOperationKind.updateTask.name) &
                  o.payload.like('%"relations"%'),
            ))
            .get();
    final touched = <int>{};
    for (final op in ops) {
      final changes = decodeTaskChanges(op.payload);
      final relations = changes.relations;
      if (relations == null || !relatedTaskIds(changes).contains(from)) {
        continue;
      }
      final rewritten = to == null
          ? withoutRelatedTasks(changes, {from})
          : withRelations(
              changes,
              relations.mapTaskIds((id) => id == from ? to : id),
            );
      if (rewritten.isEmpty) {
        await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      } else {
        await _write(
          op.id,
          OutboxCompanion(payload: Value(encodeTaskChanges(rewritten))),
        );
      }
      touched.add(op.taskId);
    }
    for (final taskId in touched) {
      await _refreshPendingChanges(taskId);
    }
  }

  Future<TaskRow?> _row(int taskId) =>
      (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();

  Future<OutboxRow?> _createOf(int localId) =>
      (select(outbox)..where(
            (o) =>
                o.taskId.equals(localId) &
                o.kind.equals(OutboxOperationKind.createTask.name),
          ))
          .getSingleOrNull();

  /// A create the server was never asked for, or rejected: it still takes
  /// edits and a delete cancels it. In flight, or sent without an answer,
  /// the server may have it, so later ops queue behind it.
  static bool _neverReachedServer(OutboxRow create) =>
      create.state == OutboxState.failed.name ||
      (create.state == OutboxState.pending.name && create.sentAt == null);

  Future<bool> _hasQueuedDelete(int taskId) async {
    final op =
        await (select(outbox)
              ..where(
                (o) =>
                    o.taskId.equals(taskId) &
                    o.kind.equals(OutboxOperationKind.deleteTask.name),
              )
              ..limit(1))
            .getSingleOrNull();
    return op != null;
  }

  /// Back in the queue with the merged [payload] and a clean slate, like
  /// the first time.
  static OutboxCompanion _retaken(String payload) => OutboxCompanion(
    payload: Value(payload),
    state: Value(OutboxState.pending.name),
    attempts: const Value(0),
    nextAttemptAt: const Value(null),
    lastError: const Value(null),
  );

  Future<int> _nextLocalId() async {
    final row = await (select(
      syncState,
    )..where((s) => s.key.equals(localTaskIdsKey))).getSingleOrNull();
    final next = (int.tryParse(row?.value ?? '') ?? 0) + 1;
    await into(syncState).insert(
      SyncStateRow(key: localTaskIdsKey, value: '$next'),
      mode: InsertMode.insertOrReplace,
    );
    return -next;
  }

  /// The newest one: an older one, left behind failed while a later edit
  /// was in flight, must not take an edit the newer op would then revert.
  Future<OutboxRow?> _unsentUpdate(int taskId) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.taskId.equals(taskId) &
                  o.kind.equals(OutboxOperationKind.updateTask.name) &
                  o.state.equals(OutboxState.sending.name).not(),
            )
            ..orderBy([(o) => OrderingTerm.desc(o.sequence)])
            ..limit(1))
          .getSingleOrNull();

  Future<OutboxRow?> _newerUnsent(OutboxRow op) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.taskId.equals(op.taskId) &
                  o.sequence.isBiggerThanValue(op.sequence) &
                  o.state.equals(OutboxState.sending.name).not(),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> _insert({
    required OutboxOperationKind kind,
    required int taskId,
    required String payload,
    required DateTime now,
  }) async {
    final highest = outbox.sequence.max();
    final query = selectOnly(outbox)..addColumns([highest]);
    final last = await query.map((row) => row.read(highest)).getSingle();
    await into(outbox).insert(
      OutboxRow(
        id: _newId(),
        sequence: (last ?? 0) + 1,
        kind: kind.name,
        taskId: taskId,
        payload: payload,
        createdAt: now.toUtc(),
        attempts: 0,
        state: OutboxState.pending.name,
      ),
    );
  }

  Future<void> _write(String id, Insertable<OutboxRow> values) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(values);

  static TaskChanges _pendingOf(TaskRow row) => switch (row.pendingChanges) {
    final json? => decodeTaskChanges(json),
    null => const TaskChanges(),
  };

  /// A random UUID (version 4).
  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
