import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/activity/foreground_activity.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';

import 'activity_fakes.dart';
import 'list_preferences_fakes.dart';
import 'realtime_fakes.dart';
import 'subscription_fakes.dart';
import 'task_details_fakes.dart';
import 'task_edits.dart';

/// Replays [current] to every subscriber when it has one, then forwards
/// [updates].
Stream<T> _replaying<T>(T? Function() current, Stream<T> updates) {
  late StreamController<T> controller;
  StreamSubscription<T>? subscription;
  controller = StreamController<T>(
    onListen: () {
      if (current() case final value?) controller.add(value);
      subscription = updates.listen(controller.add, onDone: controller.close);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

/// A sync engine whose runs are what the handlers do: nothing by default,
/// a thrown `VikunjaFailure` fails the run, anything else thrown is an
/// `UnexpectedResponse` like in the real engine. A run holds the status at
/// `SyncRunning` until the handler completes; [emit] reports progress. With
/// `restored` false the status stream stays silent until the first [emit],
/// like an engine that has not read its stored state yet.
final class FakeSyncEngine implements SyncEngine {
  new({
    SyncStatus initialStatus = const SyncNeverRun(),
    this._restored = true,
    DateTime Function()? clock,
  }) : _status = initialStatus,
       _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _changes = StreamController<SyncStatus>.broadcast();
  SyncStatus _status;
  bool _restored;
  Future<void>? _running;

  Future<void> Function()? onRefresh;
  Future<void> Function()? onFullResync;
  Future<void> Function()? onEnsureInitialSync;
  int refreshCalls = 0;
  int fullResyncCalls = 0;
  int ensureInitialSyncCalls = 0;
  bool disposed = false;

  @override
  SyncStatus get currentStatus => _status;

  @override
  Stream<SyncStatus> get status =>
      _replaying(() => _restored ? _status : null, _changes.stream);

  void emit(SyncStatus status) {
    _status = status;
    _restored = true;
    if (!_changes.isClosed) _changes.add(status);
  }

  @override
  Future<void> ensureInitialSync() {
    ensureInitialSyncCalls++;
    if (_status
        case SyncIdle() ||
            SyncRunning(initial: false) ||
            SyncFailed(lastSyncedAt: DateTime())) {
      return Future.value();
    }
    return _run(initial: true, handler: onEnsureInitialSync);
  }

  @override
  Future<void> refresh() {
    refreshCalls++;
    return _run(initial: _initial, handler: onRefresh);
  }

  @override
  Future<void> fullResync() {
    fullResyncCalls++;
    return _run(initial: _initial, handler: onFullResync);
  }

  bool get _initial => switch (_status) {
    SyncNeverRun() || SyncFailed(lastSyncedAt: null) => true,
    SyncRunning(:final initial) => initial,
    _ => false,
  };

  Future<void> _run({
    required bool initial,
    required Future<void> Function()? handler,
  }) => _running ??= _runOnce(
    initial: initial,
    handler: handler,
  ).whenComplete(() => _running = null);

  Future<void> _runOnce({
    required bool initial,
    required Future<void> Function()? handler,
  }) async {
    final lastSyncedAt = switch (_status) {
      SyncIdle(:final lastSyncedAt) => lastSyncedAt,
      SyncFailed(:final lastSyncedAt) => lastSyncedAt,
      _ => null,
    };
    emit(SyncRunning(phase: SyncPhase.account, done: 0, initial: initial));
    try {
      await handler?.call();
    } on VikunjaFailure catch (failure) {
      emit(SyncFailed(failure: failure, lastSyncedAt: lastSyncedAt));
      rethrow;
    } on Object catch (error) {
      emit(
        SyncFailed(
          failure: UnexpectedResponse(null, message: '${error.runtimeType}'),
          lastSyncedAt: lastSyncedAt,
        ),
      );
      rethrow;
    }
    emit(SyncIdle(lastSyncedAt: _clock()));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _changes.close();
  }
}

/// Projects as a local database would hold them; [all] replaces the list for
/// every watcher, like a sync writing the database.
final class FakeProjectRepository implements ProjectRepository {
  new(this._engine);

  final FakeSyncEngine _engine;
  final _changes = StreamController<List<Project>>.broadcast();
  List<Project> _all = const [];
  bool disposed = false;

  List<Project> get all => _all;

  set all(List<Project> projects) {
    _all = List.unmodifiable(projects);
    if (!_changes.isClosed) _changes.add(_all);
  }

  @override
  Stream<List<Project>> watchAll() => _replaying(() => _all, _changes.stream);

  @override
  Future<void> refresh() => _engine.refresh();

  @override
  Project? find(int id) {
    for (final project in _all) {
      if (project.id == id) return project;
    }
    return null;
  }

  /// The saved filters of the last project sync; [watchSavedFilters] sorts
  /// them by title like the real repository.
  List<SavedFilterRef> get savedFilters => _savedFilters;

  set savedFilters(List<SavedFilterRef> filters) {
    _savedFilters = List.unmodifiable(filters);
    if (!_savedFilterChanges.isClosed) _savedFilterChanges.add(_savedFilters);
  }

  List<SavedFilterRef> _savedFilters = const [];
  final _savedFilterChanges =
      StreamController<List<SavedFilterRef>>.broadcast();

  @override
  Stream<List<SavedFilterRef>> watchSavedFilters() => _replaying(
    () => _savedFilters,
    _savedFilterChanges.stream,
  ).map(sortedByTitle);

  @override
  void dispose() {
    disposed = true;
    unawaited(_changes.close());
    unawaited(_savedFilterChanges.close());
  }
}

/// Tasks as a local database would hold them, with the DAO orders: open
/// tasks by due date (nulls last) then newest first, project tasks newest
/// first.
final class FakeTaskRepository implements TaskRepository, PendingTaskIdsSource {
  new(this._engine);

  final FakeSyncEngine _engine;
  final _changes = StreamController<List<Task>>.broadcast();
  List<Task> _all = const [];
  bool disposed = false;

  List<Task> get all => _all;

  set all(List<Task> tasks) {
    _all = List.unmodifiable(tasks);
    if (!_changes.isClosed) _changes.add(_all);
  }

  List<Task> get openTasks {
    final open = [
      for (final task in _all)
        if (!task.done) task,
    ];
    return open..sort((a, b) {
      final byDue = switch ((a.dueDate, b.dueDate)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final a?, final b?) => a.compareTo(b),
      };
      return byDue != 0 ? byDue : b.id.compareTo(a.id);
    });
  }

  @override
  Stream<List<Task>> watchOpenTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => openTasks);

  @override
  Stream<List<Task>> watchSearchableTasks() =>
      _replaying(() => _all, _changes.stream).map(
        (_) => [for (final task in _all) task.copyWith(relatedTasks: const {})],
      );

  /// The archived projects whose tasks `watchActiveOpenTasks` leaves out;
  /// the test lists their subprojects too.
  Set<int> get archivedProjectIds => _archivedProjectIds;

  set archivedProjectIds(Set<int> ids) {
    _archivedProjectIds = Set.unmodifiable(ids);
    _notify();
  }

  Set<int> _archivedProjectIds = const {};

  /// The saved filter the Overview shows; null shows the active open tasks.
  SavedFilterRef? get overviewFilter => _overviewFilter;

  set overviewFilter(SavedFilterRef? filter) {
    _overviewFilter = filter;
    _notify();
  }

  SavedFilterRef? _overviewFilter;

  /// The overview filter's last download: its tasks that are in [all] and
  /// open show, like the local database's.
  ListSnapshot get overviewSnapshot => _overviewSnapshot;

  set overviewSnapshot(ListSnapshot snapshot) {
    _overviewSnapshot = snapshot;
    _notify();
  }

  ListSnapshot _overviewSnapshot = const ListSnapshot();

  /// Each list's last download, by `listKeyFor` key; see [setSnapshot].
  Map<String, ListSnapshot> get snapshots => Map.unmodifiable(_snapshots);
  final Map<String, ListSnapshot> _snapshots = {};

  void setSnapshot(String listKey, ListSnapshot snapshot) {
    _snapshots[listKey] = snapshot;
    _notify();
  }

  /// Every `refreshProjectList` as `(projectId, viewId)`. Each runs a sync
  /// through the engine, then [onRefreshProjectList], then throws
  /// [refreshProjectListFailure] when one is set.
  final List<(int, int)> projectListRefreshes = [];
  Future<void> Function(int projectId, int viewId)? onRefreshProjectList;
  VikunjaFailure? refreshProjectListFailure;

  void _notify() {
    if (!_changes.isClosed) _changes.add(_all);
  }

  /// Like the database: a task created here first, then newest first.
  static int _newestFirst(Task a, Task b) {
    if ((a.id < 0) != (b.id < 0)) return a.id < 0 ? -1 : 1;
    return b.id.abs().compareTo(a.id.abs());
  }

  static int _byDueThenNewest(Task a, Task b) {
    final byDue = switch ((a.dueDate, b.dueDate)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final a?, final b?) => a.compareTo(b),
    };
    return byDue != 0 ? byDue : _newestFirst(a, b);
  }

  List<Task> get activeOpenTasks => [
    for (final task in _all)
      if (!task.done && !_archivedProjectIds.contains(task.projectId)) task,
  ]..sort(_byDueThenNewest);

  OverviewTasks get overviewTasks {
    final filter = _overviewFilter;
    if (filter == null) return OverviewTasks(tasks: activeOpenTasks);
    final listed = _overviewSnapshot.positions;
    return OverviewTasks(
      tasks: [
        for (final task in _all)
          if (!task.done && listed.containsKey(task.id)) task,
      ]..sort(_byDueThenNewest),
      filter: filter,
      filterLoadedAt: _overviewSnapshot.loadedAt,
    );
  }

  /// Like the database: without [includeDone], the done tasks the view's
  /// download lacks stay out.
  ProjectListSource projectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) {
    final byId = {for (final task in _all) task.id: task};
    final snapshot =
        _snapshots[listKeyFor(projectId: projectId, viewId: viewId)] ??
        const ListSnapshot();
    bool loaded(Task task) =>
        includeDone || !task.done || snapshot.positions.containsKey(task.id);
    final inProject = [
      for (final task in _all)
        if (task.projectId == projectId) task,
    ];
    final projectTasks = inProject.where(loaded).toList()..sort(_newestFirst);
    final reachable = {for (final task in projectTasks) task.id: task};
    var frontier = projectTasks;
    while (frontier.isNotEmpty) {
      final next = <Task>[];
      for (final task in frontier) {
        for (final subtask in task.subtasks) {
          final child = byId[subtask.id];
          if (child == null || reachable.containsKey(child.id)) continue;
          reachable[child.id] = child;
          next.add(child);
        }
      }
      frontier = next;
    }
    return ProjectListSource(
      projectTasks: projectTasks,
      tasksById: reachable,
      snapshot: snapshot,
      omitsDoneTasks: inProject.any((task) => !loaded(task)),
    );
  }

  @override
  Stream<List<Task>> watchActiveOpenTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => activeOpenTasks);

  @override
  Stream<OverviewTasks> watchOverviewTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => overviewTasks);

  /// Every `watchProjectList` as `(projectId, viewId, includeDone)`.
  final List<(int, int, bool)> projectListWatches = [];

  /// The error `watchProjectList` fails with, by view id.
  final Map<int, Object> projectListErrors = {};

  @override
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) {
    projectListWatches.add((projectId, viewId, includeDone));
    if (projectListErrors[viewId] case final error?) {
      return Stream.error(error);
    }
    return _replaying(() => _all, _changes.stream).map(
      (_) => projectList(projectId, viewId: viewId, includeDone: includeDone),
    );
  }

  @override
  Future<void> refreshProjectList(int projectId, {required int viewId}) async {
    projectListRefreshes.add((projectId, viewId));
    await _engine.refresh();
    await onRefreshProjectList?.call(projectId, viewId);
    if (refreshProjectListFailure case final failure?) throw failure;
  }

  /// Open favourite tasks outside [archivedProjectIds], like the database.
  List<Task> get favoriteTasks => [
    for (final task in activeOpenTasks)
      if (task.isFavorite) task,
  ];

  @override
  Stream<List<Task>> watchFavoriteTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => favoriteTasks);

  /// Each saved filter's last download, by pseudo project id; its tasks
  /// that are in [all] and open show, like the local database's.
  Map<int, ListSnapshot> get savedFilterSnapshots =>
      Map.unmodifiable(_savedFilterSnapshots);
  final Map<int, ListSnapshot> _savedFilterSnapshots = {};

  void setSavedFilterSnapshot(int pseudoProjectId, ListSnapshot snapshot) {
    _savedFilterSnapshots[pseudoProjectId] = snapshot;
    _notify();
  }

  /// Like a sync purging the download of a filter no longer listed.
  void removeSavedFilterSnapshot(int pseudoProjectId) {
    _savedFilterSnapshots.remove(pseudoProjectId);
    _notify();
  }

  SavedFilterTasks savedFilterTasks(int pseudoProjectId) {
    final snapshot =
        _savedFilterSnapshots[pseudoProjectId] ?? const ListSnapshot();
    return SavedFilterTasks(
      tasks: [
        for (final task in _all)
          if (!task.done && snapshot.positions.containsKey(task.id)) task,
      ]..sort(_byDueThenNewest),
      loadedAt: snapshot.loadedAt,
    );
  }

  /// Every `watchSavedFilterTasks`, by pseudo project id.
  final List<int> savedFilterWatches = [];

  /// The error `watchSavedFilterTasks` fails with, by pseudo project id.
  final Map<int, Object> savedFilterErrors = {};

  @override
  Stream<SavedFilterTasks> watchSavedFilterTasks(int pseudoProjectId) {
    savedFilterWatches.add(pseudoProjectId);
    if (savedFilterErrors[pseudoProjectId] case final error?) {
      return Stream.error(error);
    }
    return _replaying(
      () => _all,
      _changes.stream,
    ).map((_) => savedFilterTasks(pseudoProjectId));
  }

  /// Every `refreshSavedFilter`, by pseudo project id. Each runs a sync
  /// through the engine, then [onRefreshSavedFilter] (which can set the
  /// snapshot), then throws [refreshSavedFilterFailure] when one is set.
  final List<int> savedFilterRefreshes = [];
  Future<void> Function(int pseudoProjectId)? onRefreshSavedFilter;
  VikunjaFailure? refreshSavedFilterFailure;

  @override
  Future<void> refreshSavedFilter(int pseudoProjectId) async {
    savedFilterRefreshes.add(pseudoProjectId);
    await _engine.refresh();
    await onRefreshSavedFilter?.call(pseudoProjectId);
    if (refreshSavedFilterFailure case final failure?) throw failure;
  }

  @override
  Future<void> refreshOpenTasks() => _engine.refresh();

  /// Every write, in order, as `create -1 Title`, `update 1`,
  /// `setDone 1 true`, `undoDone 1`, `setFavorite 2 false`, `delete 3`,
  /// `retry <op>`, `discard <op>` or `sendPending`. A write applies to the
  /// task at once, like the local database; what counts as pending is the
  /// test's to say with [pendingChanges] and [pendingTaskIds].
  final List<String> writes = [];
  Future<void> Function()? beforeWrite;

  /// What `createTask` and `updateTask` were given, in order.
  final List<NewTask> creates = [];
  final List<(int, TaskChanges)> updates = [];

  /// The labels and users `updateTask` can attach by id, besides those
  /// already on a task, like the local tables; an unknown id is skipped.
  final Map<int, Label> knownLabels = {};
  final Map<int, User> knownUsers = {};

  /// Temporary id → server id, as [remapTask] records them; `watchTask`
  /// and [find] follow them like the database does.
  final Map<int, int> remaps = {};
  int _nextLocalId = -1;

  /// What `sendPendingChanges` reports as still blocking the queue.
  VikunjaFailure? sendBlockedBy;

  /// Thrown by `discardSyncProblem`, like a server read that failed.
  VikunjaFailure? discardFailure;

  /// While it has not completed, the pending changes, the sync problems and
  /// the pending ids stay silent, like database queries that have not
  /// returned yet.
  Future<void>? outboxLoaded;

  final _pendingChanges = StreamController<int>.broadcast();
  final _problems = StreamController<List<SyncProblem>>.broadcast();
  final _pendingIds = StreamController<Set<int>>.broadcast();
  int _pendingCount = 0;
  List<SyncProblem> _problemList = const [];
  Set<int> _pendingTaskIds = const {};

  int get pendingChanges => _pendingCount;

  set pendingChanges(int count) {
    _pendingCount = count;
    if (!_pendingChanges.isClosed) _pendingChanges.add(count);
  }

  List<SyncProblem> get syncProblems => _problemList;

  set syncProblems(List<SyncProblem> problems) {
    _problemList = List.unmodifiable(problems);
    if (!_problems.isClosed) _problems.add(_problemList);
  }

  Set<int> get pendingTaskIds => _pendingTaskIds;

  set pendingTaskIds(Set<int> ids) {
    _pendingTaskIds = Set.unmodifiable(ids);
    if (!_pendingIds.isClosed) _pendingIds.add(_pendingTaskIds);
  }

  Task? find(int id) {
    final resolved = remaps[id] ?? id;
    for (final task in _all) {
      if (task.id == resolved) return task;
    }
    return null;
  }

  Future<void> _write(String entry, Task? Function(Task task) change) async {
    writes.add(entry);
    await beforeWrite?.call();
    all = [for (final task in _all) ?change(task)];
  }

  @override
  Stream<Task?> watchTask(int taskId) =>
      _replaying(() => _all, _changes.stream).map((_) => find(taskId));

  /// The task goes into the list under the next temporary id (−1, −2, …)
  /// with [createdAt] as its `created`, like the local row.
  @override
  Future<int> createTask(NewTask task) async {
    final id = _nextLocalId--;
    writes.add('create $id ${task.title}');
    creates.add(task);
    await beforeWrite?.call();
    all = [
      ..._all,
      taskFromNewTask(
        task,
        id: id,
        now: createdAt,
      ).copyWith(identifier: '', index: 0, updated: null),
    ];
    return id;
  }

  /// The server named the task: it moves to [serverId] in the list, the
  /// relations of other tasks follow it, and watchers of [localId] follow.
  void remapTask(int localId, int serverId) {
    remaps[localId] = serverId;
    Task renamed(Task task) =>
        task.id == localId ? taskWithId(task, serverId) : task;
    all = [
      for (final task in _all)
        renamed(task).copyWith(
          relatedTasks: {
            for (final MapEntry(:key, :value) in task.relatedTasks.entries)
              key: [for (final other in value) renamed(other)],
          },
        ),
    ];
  }

  /// Relations apply to both tasks when the other one is in [all], as the
  /// server keeps the inverse edge; a temporary id that was remapped is
  /// followed.
  @override
  Future<void> updateTask(int taskId, TaskChanges changes) async {
    updates.add((taskId, changes));
    final labels = {
      for (final task in _all)
        for (final label in task.labels) label.id: label,
      ...knownLabels,
    };
    final users = {
      for (final task in _all)
        for (final user in task.assignees) user.id: user,
      ...knownUsers,
    };
    final id = remaps[taskId] ?? taskId;
    await _write(
      'update $taskId',
      (task) => task.id == id
          ? applyChangesToTask(
              task,
              changes,
              now: _doneAt,
              labels: labels,
              users: users,
            )
          : task,
    );
    if (changes.relations case final relations?) {
      all = applyRelationChange(
        _all,
        id,
        relations.mapTaskIds((other) => remaps[other] ?? other),
      );
    }
  }

  @override
  Future<void> setDone(int taskId, {required bool done}) => _write(
    'setDone $taskId $done',
    (task) => task.id == taskId
        ? copyTask(task, done: done, doneAt: done ? _doneAt : null)
        : task,
  );

  /// The previous dates come back, like the real repository restores them,
  /// and a repeating task's reminders with them.
  @override
  Future<void> undoDone(Task previous) => _write(
    'undoDone ${previous.id}',
    (task) => task.id == previous.id
        ? task.copyWith(
            done: false,
            doneAt: null,
            dueDate: previous.dueDate ?? task.dueDate,
            startDate: previous.startDate ?? task.startDate,
            endDate: previous.endDate ?? task.endDate,
            reminders: previous.repeats && previous.reminders.isNotEmpty
                ? previous.reminders
                : null,
          )
        : task,
  );

  @override
  Future<void> setFavorite(int taskId, {required bool favorite}) => _write(
    'setFavorite $taskId $favorite',
    (task) => task.id == taskId ? copyTask(task, isFavorite: favorite) : task,
  );

  @override
  Future<void> deleteTask(int taskId) =>
      _write('delete $taskId', (task) => task.id == taskId ? null : task);

  /// Ids the next duplicates get; a failure set here is thrown instead
  /// (a `VikunjaFailure`, or `TaskNotSyncedYet`).
  int nextDuplicateId = 9000;
  Exception? duplicateFailure;
  final List<int> duplicated = [];

  /// A task in [all] is copied under the new id, with `copiedfrom` on the
  /// copy and `copiedto` on the source, like the server's duplicate.
  @override
  Future<int> duplicateTask(int taskId) async {
    duplicated.add(taskId);
    if (duplicateFailure case final failure?) throw failure;
    final copyId = nextDuplicateId++;
    if (find(taskId) case final source?) {
      all = applyRelationChange(
        [..._all, taskWithId(source, copyId).copyWith(relatedTasks: const {})],
        copyId,
        RelationChange(
          added: {TaskRelationRef(TaskRelationKind.copiedFrom, source.id)},
        ),
      );
    }
    return copyId;
  }

  @override
  Stream<int> watchPendingChanges() =>
      _outbox(() => _pendingCount, _pendingChanges.stream);

  @override
  Stream<List<SyncProblem>> watchSyncProblems() =>
      _outbox(() => _problemList, _problems.stream);

  @override
  Stream<Set<int>> watchPendingTaskIds() =>
      _outbox(() => _pendingTaskIds, _pendingIds.stream);

  Stream<T> _outbox<T>(T Function() current, Stream<T> updates) {
    final loaded = outboxLoaded;
    final stream = _replaying(current, updates);
    if (loaded == null) return stream;
    return Stream.fromFuture(loaded).asyncExpand((_) => stream);
  }

  @override
  Future<void> retrySyncProblem(String operationId) async {
    writes.add('retry $operationId');
    syncProblems = [
      for (final problem in _problemList)
        if (problem.operationId != operationId) problem,
    ];
  }

  @override
  Future<VikunjaFailure?> sendPendingChanges() async {
    writes.add('sendPending');
    await beforeWrite?.call();
    return sendBlockedBy;
  }

  @override
  Future<void> discardSyncProblem(String operationId) async {
    writes.add('discard $operationId');
    await beforeWrite?.call();
    if (discardFailure case final failure?) throw failure;
    syncProblems = [
      for (final problem in _problemList)
        if (problem.operationId != operationId) problem,
    ];
    pendingChanges = _pendingCount > 0 ? _pendingCount - 1 : 0;
  }

  static final _doneAt = DateTime.utc(2026, 10, 10, 12);

  /// The `created` of every task made through [createTask].
  DateTime createdAt = _doneAt;

  @override
  void dispose() {
    disposed = true;
    unawaited(_changes.close());
    unawaited(_pendingChanges.close());
    unawaited(_problems.close());
    unawaited(_pendingIds.close());
  }
}

final class FakeAccountDatabaseFiles implements AccountDatabaseFiles {
  final List<String> deleted = [];

  @override
  Future<String> pathFor(String accountId) async =>
      '/support/accounts/$accountId/vikunja.db';

  @override
  Future<void> deleteFor(String accountId) async => deleted.add(accountId);
}

/// Queued ops per account as [queuedOps] counts them (none by default);
/// counts and drains are recorded.
final class FakeAccountOutboxes implements AccountOutboxes {
  new([int Function(String accountId)? queuedOps])
    : _queuedOps = queuedOps ?? ((_) => 0);

  final int Function(String accountId) _queuedOps;
  final List<String> counted = [];
  final List<String> drained = [];

  /// Lets a test hold a count open or fail it.
  Future<void> Function(String accountId)? beforeCount;

  /// Lets a test fail a drain.
  Future<void> Function(String accountId)? onDrain;

  @override
  Future<int> queuedOps(String accountId) async {
    counted.add(accountId);
    await beforeCount?.call(accountId);
    return _queuedOps(accountId);
  }

  @override
  Future<void> drain(String accountId) async {
    drained.add(accountId);
    await onDrain?.call(accountId);
  }
}

/// One account's local data: an engine and the repositories over it. With
/// `restored` false the engine stays silent until it emits, like one that
/// has not read its stored state yet.
final class AccountDataFakes {
  new({required DateTime now, SyncStatus? status, bool restored = true}) {
    engine = FakeSyncEngine(
      initialStatus: status ?? SyncIdle(lastSyncedAt: now),
      restored: restored,
      clock: () => now,
    );
    projects = FakeProjectRepository(engine);
    tasks = FakeTaskRepository(engine);
    resolver = FakeTaskResolver(local: () => tasks.all);
  }

  late final FakeSyncEngine engine;
  late final FakeProjectRepository projects;
  late final FakeTaskRepository tasks;
  final listPreferences = FakeListPreferences();
  final activity = FakeActivityRepository();
  final subscriptions = FakeSubscriptionRepository();
  final details = FakeTaskDetailsRepository();

  /// Resolves the account's [tasks] locally, the rest from its `online`.
  late final FakeTaskResolver resolver;
  final attachmentImages = FakeAttachmentImages();

  /// What `userSettingsProvider` reports while the account is active.
  UserSettings get settings => _settings;

  set settings(UserSettings settings) {
    _settings = settings;
    _settingsChanges.add(settings);
  }

  UserSettings _settings = const UserSettings();
  final _settingsChanges = StreamController<UserSettings>.broadcast();

  Stream<UserSettings> watchSettings() =>
      _replaying(() => _settings, _settingsChanges.stream);
}

/// The data layer under the screens, without a database: every account
/// shares [engine], [projects] and [tasks] unless [accounts] has its own
/// entry. The account starts as synced just now, so the quiet sync at start
/// stays out of the way unless a test asks for it.
final class SyncFakes {
  new({DateTime? now, SyncStatus? status})
    : shared = AccountDataFakes(now: now ?? DateTime.now(), status: status);

  final AccountDataFakes shared;
  final accounts = <String, AccountDataFakes>{};
  final files = FakeAccountDatabaseFiles();

  /// Refuses every upgrade, so no screen test opens a socket or waits on
  /// one; a test of the realtime path lets it accept.
  final realtime = FakeRealtimeConnector(accepts: false);

  /// How often the foreground activity sync ran for the active account.
  int foregroundActivityRuns = 0;

  /// The outboxes of inactive accounts: an account's queued ops are the
  /// pending changes of its task repository.
  late final outboxes = FakeAccountOutboxes(
    (accountId) => forAccount(accountId).tasks.pendingChanges,
  );

  FakeSyncEngine get engine => shared.engine;
  FakeProjectRepository get projects => shared.projects;
  FakeTaskRepository get tasks => shared.tasks;
  FakeActivityRepository get activity => shared.activity;
  FakeListPreferences get listPreferences => shared.listPreferences;
  FakeSubscriptionRepository get subscriptions => shared.subscriptions;
  FakeTaskDetailsRepository get details => shared.details;
  FakeTaskResolver get resolver => shared.resolver;
  FakeAttachmentImages get attachmentImages => shared.attachmentImages;

  AccountDataFakes forAccount(String accountId) =>
      accounts[accountId] ?? shared;

  List<Override> get overrides => [
    accountDatabaseFilesProvider.overrideWithValue(files),
    accountOutboxesProvider.overrideWithValue(outboxes),
    syncEngineProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).engine,
    ),
    accountProjectRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).projects,
    ),
    accountTaskRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).tasks,
    ),
    accountListPreferencesProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).listPreferences,
    ),
    accountActivityRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).activity,
    ),
    accountSubscriptionRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).subscriptions,
    ),
    accountTaskDetailsRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).details,
    ),
    accountTaskResolverProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).resolver,
    ),
    accountAttachmentImagesProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).attachmentImages,
    ),
    // The real one syncs the activity on the foreground ticks, which opens
    // the inactive accounts' databases.
    foregroundActivityProvider.overrideWithValue(
      ForegroundActivity(
        syncActive: () async => foregroundActivityRuns++,
        syncInactive: () async {},
      ),
    ),
    realtimeConnectorProvider.overrideWithValue(realtime),
    // The real one opens the account's database.
    accountPendingChangesProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).tasks.watchPendingChanges(),
    ),
    // The real one opens the account's database; every list reads it.
    userSettingsProvider.overrideWith((ref) {
      final accountId = ref.watch(activeAccountIdProvider);
      if (accountId == null) return Stream.value(const UserSettings());
      return forAccount(accountId).watchSettings();
    }),
  ];
}
