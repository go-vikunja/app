import 'dart:math';

import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
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
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';
import 'package:vikunja_mobile/core/outbox/upload_json.dart';

part 'outbox_dao.g.dart';

enum OutboxState { pending, sending, failed }

/// What [OutboxDao.unqueueDelete] found.
enum DeleteUnqueue {
  /// The delete was still here and is gone; the task shows again. It was
  /// never sent, or the server refused it.
  cancelled,

  /// Like [cancelled], but an earlier attempt may have reached the server
  /// without this device seeing the answer (a timeout, a 5xx, a kill in
  /// flight), so the server may have the task in its trash.
  cancelledAfterAttempt,

  /// The delete is on its way to the server; nothing changed.
  sending,

  /// No delete of the task is queued.
  notQueued,
}

/// The queue of task writes and the local side of each write: a queued
/// change is applied to the task row in the same transaction, so the row
/// shows it at once, and `pending_changes` keeps the merged unsent fields
/// for the sync's upserts.
///
/// A delete is an op like the others: it hides the row and waits behind
/// the task's queued ops, which stay, so their changes reach the server
/// first, and it can be taken back ([unqueueDelete]) until it is sent.
///
/// A task created here lives under a temporary negative id until its
/// create is answered. While the create has not left the device an edit
/// folds into it; a delete queues behind it, and once the sender gets to
/// the create both go without a request ([cancelDeletedCreate]). Once the
/// create may be on the server (in flight, or without an answer) later ops
/// queue behind it under the temporary id, which [completeCreate] rewrites
/// to the server id. A relation may name such a task as the other task
/// too: the remap rewrites those references, and an op that still names a
/// temporary id waits.
///
/// An upload is an op of its own per file, never merged or folded: it
/// follows its task's id like any other op, but it never holds up the
/// queue ([nextInLine] leaves uploads out; the sender takes them from
/// [queuedUploads] when nothing else is ready) and waits while a delete of
/// its task is queued: it goes with the delete, or after the delete was
/// taken back. Its stored copy is the caller's to delete.
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
          commentCount: 0,
          isUnread: false,
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

  /// Queues the upload of the stored copy [upload] to the task, following
  /// a temporary id whose create was answered meanwhile; returns the op's
  /// id. Null when the task is unknown here or queued for deletion.
  Future<String?> queueUpload(
    int localOrServerId,
    QueuedUpload upload, {
    required DateTime now,
  }) => transaction(() async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    final row = await _row(taskId);
    if (row == null || row.pendingDelete) return null;
    return await _insert(
      kind: OutboxOperationKind.uploadAttachment,
      taskId: taskId,
      payload: encodeQueuedUpload(upload),
      now: now,
    );
  });

  /// Whether an upload to the task can be queued: its row is here and not
  /// queued for deletion.
  Future<bool> takesUploads(int localOrServerId) async {
    final row = await _row(
      await attachedDatabase.tasksDao.resolveId(localOrServerId),
    );
    return row != null && !row.pendingDelete;
  }

  /// Applies [requested] to the row and its labels, assignees, reminders
  /// and relations and queues it, merged into the task's unsent update op
  /// when there is one, or into its create while that has not left the
  /// device: reminders fold into the create, while labels, assignees,
  /// relations, kanban placements, list positions and done, which need the
  /// task's id on the server, stay queued behind it; a project move drops
  /// the placements and positions queued before it. A temporary id whose
  /// create was answered meanwhile is followed to the server id, the task's
  /// own and those its relations name. False when the task is unknown here
  /// or queued for deletion, or its description is not [ifDescription]
  /// when that is given.
  Future<bool> queueUpdate(
    int localOrServerId,
    TaskChanges requested, {
    required DateTime now,
    String? ifDescription,
  }) => transaction(() async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    final changes = await _withResolvedRelations(requested);
    final row = await _row(taskId);
    if (row == null || row.pendingDelete) return false;
    if (ifDescription != null && row.description != ifDescription) {
      return false;
    }
    var queued = changes;
    var pending = _pendingOf(row);
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
        if (changes.projectId != null) {
          await _dropUnsentPlacements(taskId);
          pending = withoutPlacements(pending);
        }
      }
    }
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

  /// Hides the row and queues the delete behind the task's other ops,
  /// which stay with the row's `pending_changes`; the delete is sent once
  /// they are. A temporary id whose create was answered meanwhile is
  /// followed to the server id. A create that has not left the device goes
  /// with the delete once the sender gets to it; one the server refused, or
  /// a row without its create, is discarded at once with every op.
  /// [TaskDeletion.none] when the task is unknown here or already queued
  /// for deletion.
  Future<TaskDeletion> queueDelete(
    int localOrServerId, {
    required DateTime now,
  }) => transaction(() async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    final row = await _row(taskId);
    if (row == null || row.pendingDelete) return TaskDeletion.none;
    if (taskId < 0) {
      final create = await _createOf(taskId);
      if (create == null || create.state == OutboxState.failed.name) {
        await cancelCreate(taskId);
        return TaskDeletion.discarded;
      }
    }
    await _insert(
      kind: OutboxOperationKind.deleteTask,
      taskId: taskId,
      payload: '{}',
      now: now,
    );
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      const TasksCompanion(pendingDelete: Value(true)),
    );
    return TaskDeletion.queued;
  });

  /// Takes the task's queued delete back while it is pending or failed:
  /// the op goes and the row shows again, with its `pending_changes`. One
  /// on its way is left alone. Follows a temporary id whose create was
  /// answered meanwhile.
  ///
  /// A pending delete that was tried before is
  /// [DeleteUnqueue.cancelledAfterAttempt]: it is back in the queue after a
  /// transient failure or a kill in flight ([resetSending]), so the server
  /// may have acted on it. A failed one is [DeleteUnqueue.cancelled]: the
  /// server answered its last attempt with a refusal.
  Future<DeleteUnqueue> unqueueDelete(int localOrServerId) => transaction(
    () async {
      final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
      final op = await _deleteOf(taskId);
      if (op == null) return DeleteUnqueue.notQueued;
      if (op.state == OutboxState.sending.name) return DeleteUnqueue.sending;
      await (delete(outbox)..where((o) => o.id.equals(op.id))).go();
      await clearPendingDelete(taskId);
      return op.state == OutboxState.pending.name && op.lastAttemptAt != null
          ? DeleteUnqueue.cancelledAfterAttempt
          : DeleteUnqueue.cancelled;
    },
  );

  /// The task's queued delete, whatever its state; null without one.
  /// Follows a temporary id whose create was answered meanwhile.
  Future<OutboxRow?> queuedDeleteOf(int localOrServerId) async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    return await _deleteOf(taskId);
  }

  /// Drops the create of [createOperationId] with its row and every op of
  /// the task, when it was never sent and a delete of the task is queued:
  /// the server is never asked. False, with nothing changed, otherwise,
  /// also when the delete was taken back first.
  Future<bool> cancelDeletedCreate(String createOperationId) =>
      transaction(() async {
        final create = await find(createOperationId);
        if (create == null ||
            create.kind != OutboxOperationKind.createTask.name ||
            create.sentAt != null ||
            !await hasQueuedDelete(create.taskId)) {
          return false;
        }
        await cancelCreate(create.taskId);
        return true;
      });

  /// The head of the queue: the oldest op that has not failed, whatever
  /// its `next_attempt_at`; the sender waits for that itself. Uploads are
  /// not part of it (see [queuedUploads]). It may be `sending`, in another
  /// isolate or left by a run that died, and then nothing may overtake
  /// it. An update or delete under a temporary id waits for its create,
  /// which is ahead of it or failed; so does an update whose relations name
  /// a task whose create has not been answered, wherever that create is,
  /// and every later op of its task, so a delete never goes before the
  /// task's edits.
  Future<OutboxRow?> nextInLine() async {
    var after = 0;
    final waiting = <int>{};
    while (true) {
      final op =
          await (select(outbox)
                ..where(
                  (o) =>
                      o.sequence.isBiggerThanValue(after) &
                      o.state.equals(OutboxState.failed.name).not() &
                      o.kind
                          .equals(OutboxOperationKind.uploadAttachment.name)
                          .not() &
                      (o.taskId.isBiggerThanValue(0) |
                          o.kind.equals(OutboxOperationKind.createTask.name)),
                )
                ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
                ..limit(1))
              .getSingleOrNull();
      if (op == null || op.state != OutboxState.pending.name) return op;
      if (!waiting.contains(op.taskId) && !await waitsForRelatedCreate(op)) {
        return op;
      }
      waiting.add(op.taskId);
      after = op.sequence;
    }
  }

  /// The uploads that may go once their backoff is over, oldest first:
  /// not failed, the task has a server id and no queued delete. Some may be
  /// `sending`, in a run that died or another isolate.
  Future<List<OutboxRow>> queuedUploads() {
    final deleting = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.pendingDelete.equals(true));
    return (select(outbox)
          ..where(
            (o) =>
                o.kind.equals(OutboxOperationKind.uploadAttachment.name) &
                o.state.equals(OutboxState.failed.name).not() &
                o.taskId.isBiggerThanValue(0) &
                o.taskId.isNotInQuery(deleting),
          )
          ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
        .get();
  }

  /// Every stored copy a queued upload names, whatever its state.
  Future<Set<String>> uploadFiles() async {
    final ops =
        await (select(outbox)..where(
              (o) => o.kind.equals(OutboxOperationKind.uploadAttachment.name),
            ))
            .get();
    return {for (final op in ops) decodeQueuedUpload(op.payload).file};
  }

  /// Removes the upload op, whatever its state; returns its stored copy's
  /// name for the caller to delete, null when the op is gone or not an
  /// upload.
  Future<String?> removeUpload(String id) => transaction(() async {
    final op = await find(id);
    if (op == null || op.kind != OutboxOperationKind.uploadAttachment.name) {
      return null;
    }
    await (delete(outbox)..where((o) => o.id.equals(id))).go();
    return decodeQueuedUpload(op.payload).file;
  });

  /// The task's queued uploads, oldest first, following the task across
  /// the id change of its create.
  Stream<List<PendingUpload>> watchPendingUploads(
    int localOrServerId,
  ) => watchTables({outbox, taskIdRemaps}, () async {
    final taskId = await attachedDatabase.tasksDao.resolveId(localOrServerId);
    final ops =
        await (select(outbox)
              ..where(
                (o) =>
                    o.taskId.equals(taskId) &
                    o.kind.equals(OutboxOperationKind.uploadAttachment.name),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.sequence)]))
            .get();
    return [for (final op in ops) _pendingUploadOf(op)];
  });

  static PendingUpload _pendingUploadOf(OutboxRow op) {
    final upload = decodeQueuedUpload(op.payload);
    return PendingUpload(
      operationId: op.id,
      taskId: op.taskId,
      fileName: upload.fileName,
      size: upload.size,
      mimeType: upload.mimeType,
      state: switch (OutboxState.values.asNameMap()[op.state]) {
        OutboxState.sending => PendingUploadState.sending,
        OutboxState.failed => PendingUploadState.failed,
        OutboxState.pending || null => PendingUploadState.waiting,
      },
      queuedAt: op.createdAt,
      lastFailure: switch (op.lastError) {
        final json? => decodeFailure(json),
        null => null,
      },
    );
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

  /// A create or upload whose request may have reached the server: the
  /// first such attempt's time stays, so the lookup window covers every
  /// attempt.
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
  /// delete queued behind it cancels it: the server never had the task,
  /// so both go. A related task the server no longer has is forgotten (see
  /// [forgetRelatedTasks]), in this op too, which stays failed to say why
  /// the edge is gone: the write client tried every other request of the
  /// op first, so it holds nothing back, and an edit merged into it later
  /// goes out without that edge.
  Future<void> markFailed(String id, VikunjaFailure failure) =>
      transaction(() async {
        final op = await find(id);
        if (op == null) return;
        if (op.kind == OutboxOperationKind.uploadAttachment.name) {
          // A refusal means the server stored nothing; after a timeout a
          // retry must look for the file first.
          final mayBeStored =
              failure is NetworkFailure || failure is ServerFailure;
          await _write(
            id,
            OutboxCompanion(
              state: Value(OutboxState.failed.name),
              nextAttemptAt: const Value(null),
              lastError: Value(encodeFailure(failure)),
              sentAt: mayBeStored ? const Value.absent() : const Value(null),
            ),
          );
          return;
        }
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
          if (await hasQueuedDelete(op.taskId)) {
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

  /// A failed update goes back to the queue with [base] as its description
  /// base, so its description overwrites the server's while that is still
  /// [base] and fails again when it changed once more.
  Future<void> retryOverwritingDescription(String id, {required String base}) =>
      transaction(() async {
        final op = await find(id);
        if (op == null || !_isFailedUpdate(op)) return;
        await _write(
          id,
          _retaken(
            encodeTaskChanges(
              withDescriptionBase(decodeTaskChanges(op.payload), base),
            ),
          ),
        );
        await _refreshPendingChanges(op.taskId);
      });

  /// A failed update without its description, back in the queue with what
  /// else it changes, or gone when that was all; false when the op is gone,
  /// not an update or no longer failed. The row keeps the description until
  /// the server's is stored.
  Future<bool> dropDescription(String id) => transaction(() async {
    final op = await find(id);
    if (op == null || !_isFailedUpdate(op)) return false;
    final rest = withoutDescription(decodeTaskChanges(op.payload));
    if (rest.isEmpty) {
      await (delete(outbox)..where((o) => o.id.equals(id))).go();
    } else {
      await _write(id, _retaken(encodeTaskChanges(rest)));
    }
    await _refreshPendingChanges(op.taskId);
    return true;
  });

  static bool _isFailedUpdate(OutboxRow op) =>
      op.kind == OutboxOperationKind.updateTask.name &&
      op.state == OutboxState.failed.name;

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

  /// The task's failed ops the server refused because the task or its
  /// project was gone or in its trash go back to the queue, as with
  /// [retry], for when the task is back on the server. Returns how many.
  Future<int> retryRefusedAsGone(int taskId) => transaction(() async {
    final failed =
        await (select(outbox)..where(
              (o) =>
                  o.taskId.equals(taskId) &
                  o.state.equals(OutboxState.failed.name),
            ))
            .get();
    var retried = 0;
    for (final op in failed) {
      final error = op.lastError;
      if (error == null) continue;
      if (decodeFailure(error)
          case NotFound(taskGone: true) || NotFound(projectGone: true)) {
        await retry(op.id);
        retried++;
      }
    }
    return retried;
  });

  /// Ops left in `sending` for at least [olderThan] go back to pending: a
  /// killed run, a disposed sender or a failed local apply left them, as
  /// no live sender takes that long over one op. A younger one may still
  /// be on its way in another isolate and stays, and so do the uploads in
  /// [keep], which the caller is still streaming. A create or upload among
  /// them may have reached the server, so it is marked uncertain as of its
  /// attempt (an earlier `sent_at` stays), and the next attempt looks for
  /// the task or attachment before sending it again.
  Future<int> resetSending({
    required DateTime now,
    Duration olderThan = Duration.zero,
    Set<String> keep = const {},
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
            )) &
        outbox.id.isNotIn(keep);
    await (update(outbox)..where(
          (o) =>
              sending &
              o.kind.isIn([
                OutboxOperationKind.createTask.name,
                OutboxOperationKind.uploadAttachment.name,
              ]),
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
    final deleting = await hasQueuedDelete(created.id);
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
      changes: kind == OutboxOperationKind.updateTask
          ? decodeTaskChanges(op.payload)
          : null,
      fileName: kind == OutboxOperationKind.uploadAttachment
          ? decodeQueuedUpload(op.payload).fileName
          : null,
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
  /// edits. In flight, or sent without an answer, the server may have it,
  /// so later ops queue behind it.
  static bool _neverReachedServer(OutboxRow create) =>
      create.state == OutboxState.failed.name ||
      (create.state == OutboxState.pending.name && create.sentAt == null);

  /// Whether a delete of the task is queued, whatever its state.
  Future<bool> hasQueuedDelete(int taskId) async =>
      await _deleteOf(taskId) != null;

  Future<OutboxRow?> _deleteOf(int taskId) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.taskId.equals(taskId) &
                  o.kind.equals(OutboxOperationKind.deleteTask.name),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
            ..limit(1))
          .getSingleOrNull();

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

  /// The create now goes to another project, so the placements and
  /// positions queued behind it would name views of the previous one.
  Future<void> _dropUnsentPlacements(int taskId) async {
    final existing = await _unsentUpdate(taskId);
    if (existing == null) return;
    final kept = withoutPlacements(decodeTaskChanges(existing.payload));
    if (kept.isEmpty) {
      await (delete(outbox)..where((o) => o.id.equals(existing.id))).go();
    } else {
      await _write(
        existing.id,
        OutboxCompanion(payload: Value(encodeTaskChanges(kept))),
      );
    }
  }

  /// Uploads are not among them: they never fold, and an upload after a
  /// failed update must not make the update look superseded.
  Future<OutboxRow?> _newerUnsent(OutboxRow op) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.taskId.equals(op.taskId) &
                  o.sequence.isBiggerThanValue(op.sequence) &
                  o.kind.isIn([
                    OutboxOperationKind.updateTask.name,
                    OutboxOperationKind.deleteTask.name,
                  ]) &
                  o.state.equals(OutboxState.sending.name).not(),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
            ..limit(1))
          .getSingleOrNull();

  Future<String> _insert({
    required OutboxOperationKind kind,
    required int taskId,
    required String payload,
    required DateTime now,
  }) async {
    final highest = outbox.sequence.max();
    final query = selectOnly(outbox)..addColumns([highest]);
    final last = await query.map((row) => row.read(highest)).getSingle();
    final id = _newId();
    await into(outbox).insert(
      OutboxRow(
        id: id,
        sequence: (last ?? 0) + 1,
        kind: kind.name,
        taskId: taskId,
        payload: payload,
        createdAt: now.toUtc(),
        attempts: 0,
        state: OutboxState.pending.name,
      ),
    );
    return id;
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
