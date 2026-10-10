import 'dart:math';

import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/outbox.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

part 'outbox_dao.g.dart';

enum OutboxState { pending, sending, failed }

/// The queue of task writes and the local side of each write: a queued
/// change is applied to the task row in the same transaction, so the row
/// shows it at once, and `pending_changes` keeps the merged unsent fields
/// for the sync's upserts.
@DriftAccessor(tables: [Outbox, Tasks])
final class OutboxDao extends DatabaseAccessor<AppDatabase>
    with _$OutboxDaoMixin {
  new(super.attachedDatabase);

  final _random = Random.secure();

  /// Applies [changes] to the row and queues them, merged into the task's
  /// unsent update op when there is one. False when the task is unknown
  /// here or queued for deletion.
  Future<bool> queueUpdate(
    int taskId,
    TaskChanges changes, {
    required DateTime now,
  }) => transaction(() async {
    final row = await _row(taskId);
    if (row == null || row.pendingDelete) return false;
    final existing = await _unsentUpdate(taskId);
    if (existing != null) {
      final merged = decodeTaskChanges(existing.payload).merge(changes);
      await (update(outbox)..where((o) => o.id.equals(existing.id))).write(
        OutboxCompanion(
          payload: Value(encodeTaskChanges(merged)),
          state: Value(OutboxState.pending.name),
          attempts: const Value(0),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
        ),
      );
    } else {
      await _insert(
        kind: OutboxOperationKind.updateTask,
        taskId: taskId,
        payload: encodeTaskChanges(changes),
        now: now,
      );
    }
    final pending = _pendingOf(row).merge(changes);
    await update(tasks).replace(
      applyTaskChanges(
        row,
        changes,
        now: now,
      ).copyWith(pendingChanges: Value(encodeTaskChanges(pending))),
    );
    return true;
  });

  /// Hides the row and queues the delete; an unsent update op of the task
  /// is dropped, because the delete makes it moot. False when the task is
  /// unknown here or already queued for deletion.
  Future<bool> queueDelete(int taskId, {required DateTime now}) =>
      transaction(() async {
        final row = await _row(taskId);
        if (row == null || row.pendingDelete) return false;
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

  /// The op to send next: the oldest pending one, whatever its
  /// `next_attempt_at`; the sender waits for that itself.
  Future<OutboxRow?> nextPending() =>
      (select(outbox)
            ..where((o) => o.state.equals(OutboxState.pending.name))
            ..orderBy([(o) => OrderingTerm.asc(o.sequence)])
            ..limit(1))
          .getSingleOrNull();

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

  /// A failed op whose task has a newer queued op is folded into that op
  /// instead: an update takes the fields the newer update does not set, a
  /// delete makes it moot. So a task never has two ops the sender could
  /// send in either order, and a Retry can never overwrite a newer edit.
  Future<void> markFailed(String id, VikunjaFailure failure) =>
      transaction(() async {
        final op = await find(id);
        if (op == null) return;
        final newer = await _newerUnsent(op);
        if (newer == null) {
          await _write(
            id,
            OutboxCompanion(
              state: Value(OutboxState.failed.name),
              nextAttemptAt: const Value(null),
              lastError: Value(encodeFailure(failure)),
            ),
          );
          return;
        }
        if (newer.kind == OutboxOperationKind.updateTask.name) {
          final folded = decodeTaskChanges(op.payload)
              .merge(decodeTaskChanges(newer.payload));
          await _write(
            newer.id,
            OutboxCompanion(payload: Value(encodeTaskChanges(folded))),
          );
        }
        await remove(op.id);
      });

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

  /// Ops a killed app left in `sending`.
  Future<int> resetSending() =>
      (update(outbox)..where((o) => o.state.equals(OutboxState.sending.name)))
          .write(OutboxCompanion(state: Value(OutboxState.pending.name)));

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
    final remaining = await pendingChangesFor(op.taskId);
    await (update(tasks)..where((t) => t.id.equals(op.taskId))).write(
      TasksCompanion(
        pendingChanges: Value(
          remaining == null ? null : encodeTaskChanges(remaining),
        ),
      ),
    );
  });

  /// Every op of a task that is gone, whatever its state.
  Future<void> removeAllOf(int taskId) =>
      (delete(outbox)..where((o) => o.taskId.equals(taskId))).go();

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

  Future<TaskRow?> _row(int taskId) =>
      (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();

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
