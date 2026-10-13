import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Tasks from the account's database. The whole account is local, so a
/// project list is never paged and every refresh is a full sync run. A
/// write lands in the database and the outbox in one transaction, then the
/// sender drains; a create gets a temporary negative id that the sender
/// remaps once the server has named the task. A duplicate is made by the
/// server and is online only.
final class LocalTaskRepository
    implements TaskRepository, PendingTaskIdsSource {
  new(
    this._db,
    this._sync,
    this._outbox,
    this._write, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncEngine _sync;
  final OutboxSender _outbox;
  final VikunjaWriteClient _write;
  final DateTime Function() _now;

  @override
  Stream<List<Task>> watchOpenTasks() => _db.tasksDao.watchOpenTasks();

  @override
  Stream<List<Task>> watchSearchableTasks() =>
      _db.tasksDao.watchSearchableTasks();

  @override
  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  }) => _db.tasksDao
      .watchProjectTasks(projectId, showDone: showDone)
      .map((tasks) => PagedList(items: tasks, hasMore: false));

  @override
  Future<void> refreshOpenTasks() => _sync.refresh();

  @override
  Future<void> refreshProjectTasks(int projectId, {required bool showDone}) =>
      _sync.refresh();

  @override
  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone}) =>
      Future.value();

  @override
  Stream<Task?> watchTask(int taskId) => _db.tasksDao.watchTask(taskId);

  @override
  Future<int> createTask(NewTask task) async {
    final id = await _db.outboxDao.queueCreate(task, now: _now());
    _drainQuietly();
    return id;
  }

  @override
  Future<void> updateTask(int taskId, TaskChanges changes) =>
      changes.isEmpty ? Future.value() : _queue(taskId, changes);

  @override
  Future<void> setDone(int taskId, {required bool done}) =>
      _queue(taskId, TaskChanges(done: done));

  /// Only the dates the task had are restored; the server never shifts an
  /// unset one. On an open task the server does not shift again, so the
  /// dates go with `done: false` whether the done is still queued (the two
  /// merge), in flight, or answered. The server shifts a repeating task's
  /// reminders with its dates, so they go back too.
  @override
  Future<void> undoDone(Task previous) => _queue(
    previous.id,
    TaskChanges(
      done: false,
      dueDate: _restore(previous.repeats ? previous.dueDate : null),
      startDate: _restore(previous.repeats ? previous.startDate : null),
      endDate: _restore(previous.repeats ? previous.endDate : null),
      reminders: previous.repeats && previous.reminders.isNotEmpty
          ? previous.reminders
          : null,
    ),
  );

  @override
  Future<void> setFavorite(int taskId, {required bool favorite}) =>
      _queue(taskId, TaskChanges(isFavorite: favorite));

  @override
  Future<void> deleteTask(int taskId) async {
    final queued = await _db.outboxDao.queueDelete(taskId, now: _now());
    if (queued) _drainQuietly();
  }

  /// The server copies the task as it has it, so the task's queued
  /// changes go first; a copy without them would lose them. The request is
  /// not idempotent: a copy made without the answer arriving comes with
  /// the next sync.
  @override
  Future<int> duplicateTask(int taskId) async {
    var id = await _db.tasksDao.resolveId(taskId);
    if (await _db.outboxDao.hasQueuedOps(id)) {
      final blockedBy = await _outbox.sendNow();
      id = await _db.tasksDao.resolveId(taskId);
      if (await _db.outboxDao.hasQueuedOps(id)) {
        throw blockedBy ?? TaskNotSyncedYet(taskId);
      }
    }
    final copy = await _write.tasks.duplicate(id);
    await _db.tasksDao.upsertAll([copy]);
    _log.fine('Duplicated task $id as ${copy.id}');
    return copy.id;
  }

  @override
  Stream<int> watchPendingChanges() => _db.outboxDao.watchCount();

  @override
  Stream<List<SyncProblem>> watchSyncProblems() =>
      _db.outboxDao.watchProblems();

  @override
  Stream<Set<int>> watchPendingTaskIds() => _db.outboxDao.watchPendingTaskIds();

  @override
  Future<void> retrySyncProblem(String operationId) =>
      _outbox.retry(operationId);

  @override
  Future<void> discardSyncProblem(String operationId) =>
      _outbox.discard(operationId);

  @override
  Future<VikunjaFailure?> sendPendingChanges() => _outbox.sendNow();

  @override
  void dispose() {}

  /// A task unknown here, or queued for deletion, takes no change.
  Future<void> _queue(int taskId, TaskChanges changes) async {
    final queued = await _db.outboxDao.queueUpdate(
      taskId,
      changes,
      now: _now(),
    );
    if (queued) _drainQuietly();
  }

  static DateChange? _restore(DateTime? date) =>
      date == null ? null : DateChange.set(date);

  /// The write is done; the send reports through the outbox state and the
  /// sync problems.
  void _drainQuietly() => unawaited(
    _outbox.drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Outbox drain failed: ${error.runtimeType}'),
    ),
  );
}
