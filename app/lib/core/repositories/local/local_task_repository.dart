import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/local/shared_latest.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/list_downloads.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Tasks from the account's database. The whole account is local, so a
/// list is never paged and every refresh is a sync run. A write lands in
/// the database and the outbox in one transaction, then the sender drains;
/// a create gets a temporary negative id that the sender remaps once the
/// server has named the task. A duplicate is made by the server and is
/// online only, and so is a view's download, which needs `read` (`perPage`
/// is the server's page size).
final class LocalTaskRepository
    implements TaskRepository, PendingTaskIdsSource {
  new(
    this._db,
    this._sync,
    this._outbox,
    this._write, {
    this._read,
    this._perPage = 50,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SyncEngine _sync;
  final OutboxSender _outbox;
  final VikunjaWriteClient _write;
  final VikunjaReadClient? _read;
  final int _perPage;
  final DateTime Function() _now;

  // Upcoming and the Overview without a saved filter watch the same tasks.
  late final SharedLatest<List<Task>> _activeOpenTasks = SharedLatest(
    _db.tasksDao.watchActiveOpenTasks,
  );

  @override
  Stream<List<Task>> watchOpenTasks() => _db.tasksDao.watchOpenTasks();

  @override
  Stream<List<Task>> watchSearchableTasks() =>
      _db.tasksDao.watchSearchableTasks();

  @override
  Stream<List<Task>> watchActiveOpenTasks() => _activeOpenTasks.stream;

  @override
  Stream<OverviewTasks> watchOverviewTasks() => _switchLatest(
    _db.syncStateDao
        .watchValues({SyncStateKeys.userSettings, SyncStateKeys.savedFilters})
        .map(overviewFilterIn)
        .distinct(),
    (filter) => filter == null
        ? watchActiveOpenTasks().map((tasks) => OverviewTasks(tasks: tasks))
        : _db.tasksDao
              .watchOpenTasksInList(overviewSnapshotKey(filter.projectId))
              .map(
                (list) => OverviewTasks(
                  tasks: list.tasks,
                  filter: filter,
                  filterLoadedAt: list.loadedAt,
                ),
              ),
  );

  @override
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) => _db.tasksDao.watchProjectList(
    projectId,
    viewId: viewId,
    includeDone: includeDone,
  );

  @override
  Future<void> refreshProjectList(int projectId, {required int viewId}) async {
    await _sync.refresh();
    if (viewId == 0) return;
    await downloadViewSnapshot(
      db: _db,
      client: _readClient('A view download'),
      perPage: _perPage,
      projectId: projectId,
      viewId: viewId,
      now: _now,
    );
  }

  @override
  Stream<BoardSource> watchBoard(int projectId, int viewId) =>
      _db.tasksDao.watchBoard(projectId, viewId);

  @override
  Future<void> refreshBoard(int projectId, int viewId) async {
    await _sync.refresh();
    await downloadBoard(
      db: _db,
      client: _readClient('A board download'),
      perPage: _perPage,
      projectId: projectId,
      viewId: viewId,
      now: _now,
    );
  }

  @override
  Future<void> loadMoreOfBucket(int projectId, int viewId, int bucketId) =>
      downloadNextBucketPage(
        db: _db,
        client: _readClient('A bucket download'),
        perPage: _perPage,
        projectId: projectId,
        viewId: viewId,
        bucketId: bucketId,
      );

  @override
  Future<void> placeTask(
    int taskId, {
    required int viewId,
    required BucketPlacement placement,
    bool? done,
  }) => _queue(taskId, TaskChanges(kanban: {viewId: placement}, done: done));

  @override
  Future<void> positionTask(
    int taskId, {
    required int viewId,
    required double position,
  }) => _queue(taskId, TaskChanges(positions: {viewId: position}));

  @override
  Stream<List<Task>> watchFavoriteTasks() => _db.tasksDao.watchFavoriteTasks();

  @override
  Stream<SavedFilterTasks> watchSavedFilterTasks(int pseudoProjectId) => _db
      .tasksDao
      .watchOpenTasksInList(savedFilterSnapshotKey(pseudoProjectId))
      .map(
        (list) => SavedFilterTasks(tasks: list.tasks, loadedAt: list.loadedAt),
      );

  @override
  Future<void> refreshSavedFilter(int pseudoProjectId) async {
    await _sync.refresh();
    await downloadSavedFilter(
      db: _db,
      client: _readClient('A saved filter download'),
      perPage: _perPage,
      pseudoProjectId: pseudoProjectId,
      now: _now,
    );
  }

  @override
  Future<void> refreshOpenTasks() => _sync.refresh();

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

  VikunjaReadClient _readClient(String purpose) =>
      _read ?? (throw StateError('$purpose needs the read client'));

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

/// The stream [inner] makes for the newest event of [source]; the previous
/// one is cancelled.
Stream<T> _switchLatest<S, T>(
  Stream<S> source,
  Stream<T> Function(S value) inner,
) => Stream.multi((subscriber) {
  StreamSubscription<T>? current;
  var sourceDone = false;
  var innerDone = true;
  final outer = source.listen(
    (value) {
      unawaited(current?.cancel());
      innerDone = false;
      current = inner(value).listen(
        subscriber.add,
        onError: subscriber.addError,
        onDone: () {
          innerDone = true;
          if (sourceDone) unawaited(subscriber.close());
        },
      );
    },
    onError: subscriber.addError,
    onDone: () {
      sourceDone = true;
      if (innerDone) unawaited(subscriber.close());
    },
  );
  subscriber.onCancel = () async {
    await current?.cancel();
    await outer.cancel();
  };
});
