import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/activity/activity_providers.dart';
import 'package:vikunja_mobile/core/activity/foreground_activity.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_image_providers.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/db/account_database_files.dart';
import 'package:vikunja_mobile/core/files/file_actions_providers.dart';
import 'package:vikunja_mobile/core/outbox/pending_task_ids_source.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/platform/sensitive_clipboard.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/project_repository.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_search_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/share/share_providers.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';

import 'account_security_fakes.dart';
import 'account_settings_fakes.dart';
import 'activity_fakes.dart';
import 'attachment_fakes.dart';
import 'bucket_fakes.dart';
import 'list_preferences_fakes.dart';
import 'project_view_fakes.dart';
import 'realtime_fakes.dart';
import 'sample_data.dart';
import 'saved_filter_fakes.dart';
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
    // Not returning the inner cancel's future: it completes in the root
    // zone, which a widget test's fake clock never runs, so `Stream.first`
    // would never complete.
    onCancel: () => unawaited(subscription?.cancel()),
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

  /// A run of [onRefresh] after the one under way, if any.
  @override
  Future<void> refreshAfterWrite() async {
    refreshAfterWriteCalls++;
    await _running?.then<void>((_) {}, onError: (Object _) {});
    await _run(initial: _initial, handler: onRefresh);
  }

  int refreshAfterWriteCalls = 0;

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

  /// Every `moveProject`, in order, recorded before anything else;
  /// [beforeMove] can hold one. [moveFailure] is thrown instead while set,
  /// and nothing changes; else the project takes the position and parent
  /// in [all], like the database once the server answered. A position
  /// below 0.1 is an `ArgumentError`, as in the real repository.
  final List<({int projectId, double position, int parentProjectId})> moves =
      [];
  Future<void> Function()? beforeMove;
  Exception? moveFailure;

  @override
  Future<void> moveProject(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) async {
    moves.add((
      projectId: projectId,
      position: position,
      parentProjectId: parentProjectId,
    ));
    await beforeMove?.call();
    if (!(position >= 0.1)) throw ArgumentError.value(position, 'position');
    if (moveFailure case final failure?) throw failure;
    all = [
      for (final project in _all)
        if (project.id == projectId)
          movedProject(
            project,
            position: position,
            parentProjectId: parentProjectId,
          )
        else
          project,
    ];
  }

  /// Project management as the real repository does it, on [all]. Every
  /// call is recorded in its own list ([creates], [updates], [deletes],
  /// [duplicates]) and in [calls] first: `createProject Title`,
  /// `updateProject 5 ProjectChanges(title)`, `deleteProject 5`,
  /// `duplicateProject 5 under 0 shares true`. [beforeCall] can hold one;
  /// [failure], or the entry of [failures] for the method name
  /// (`createProject`, …), is thrown instead while set, and nothing changes.
  /// Then the real repository's checks: a blank title or an identifier of
  /// more than 10 characters is an `ArgumentError`, archiving
  /// [defaultProjectId] a `DomainError` code 3013, unarchiving under an
  /// archived parent code 3016, a project [all] does not have a `NotFound`
  /// code 3001, a pseudo project to duplicate an `ArgumentError`.
  final List<String> calls = [];
  final List<NewProject> creates = [];
  final List<(int, ProjectChanges)> updates = [];
  final List<int> deletes = [];
  final List<({int projectId, int parentProjectId, bool copyShares})>
  duplicates = [];
  Future<void> Function(String call)? beforeCall;
  Exception? failure;
  final Map<String, Exception> failures = {};
  int defaultProjectId = 0;

  /// The id the next created or duplicated project gets.
  int nextProjectId = 500;

  /// The id the next view gets, here and in the views fake.
  int nextViewId = 800;

  /// The id the next task copied by [duplicateProject] gets.
  int nextTaskId = 5000;

  /// When set, [deleteProject] takes the subtree's tasks out of it and
  /// [duplicateProject] copies the project's tasks into it, like the sync
  /// after them would.
  FakeTaskRepository? tasks;

  /// Lands at `id × 65536` with the four default views ([defaultViews]),
  /// the title trimmed.
  @override
  Future<int> createProject(NewProject project) async {
    creates.add(project);
    await _call('createProject', project.title);
    final title = _checkedTitle(project.title);
    final id = nextProjectId++;
    final firstViewId = nextViewId;
    nextViewId += 4;
    all = [
      ..._all,
      Project(
        id: id,
        title: title,
        hexColor: project.hexColor,
        parentProjectId: project.parentProjectId,
        position: id * 65536.0,
        views: defaultViews(id, firstViewId: firstViewId),
      ),
    ];
    return id;
  }

  /// The identifier is stored trimmed and upper-case, as the server
  /// answers; archiving and unarchiving cascade to the descendants.
  @override
  Future<void> updateProject(int projectId, ProjectChanges changes) async {
    updates.add((projectId, changes));
    await _call('updateProject', '$projectId $changes');
    final project = find(projectId);
    if (project == null) throw const NotFound(code: 3001);
    final title = switch (changes.title) {
      final title? => _checkedTitle(title),
      null => null,
    };
    final identifier = changes.identifier?.trim().toUpperCase();
    if (identifier != null && identifier.runes.length > 10) {
      throw ArgumentError.value(changes.identifier, 'identifier');
    }
    final archived = changes.isArchived;
    if (archived == true && projectId == defaultProjectId) {
      throw const DomainError(412, code: 3013);
    }
    if (archived == false &&
        (find(project.parentProjectId)?.isArchived ?? false)) {
      throw const DomainError(412, code: 3016);
    }
    final cascade = archived == null || archived == project.isArchived
        ? const <int>{}
        : subtreeIds(_all, projectId);
    all = [
      for (final candidate in _all)
        if (candidate.id == projectId)
          copyProject(
            candidate,
            title: title,
            description: changes.description,
            identifier: identifier,
            hexColor: changes.hexColor,
            parentProjectId: changes.parentProjectId,
            isFavorite: changes.isFavorite,
            isArchived: archived,
          )
        else if (cascade.contains(candidate.id))
          copyProject(candidate, isArchived: archived)
        else
          candidate,
    ];
  }

  /// The description the server has, by project id, when it differs from
  /// the stored one: `updateDescription` with another base stores it and
  /// returns it, as the real repository does for a change on the web.
  final Map<int, String> webDescriptions = {};

  /// What `updateDescription` was given as base, in order; a save also
  /// lands in [updates] like any other project change.
  final List<String> descriptionBases = [];

  @override
  Future<String?> updateDescription(
    int projectId,
    String html, {
    required String base,
  }) async {
    descriptionBases.add(base);
    if (webDescriptions[projectId] case final web? when web != base) {
      all = [
        for (final candidate in _all)
          if (candidate.id == projectId)
            copyProject(candidate, description: web)
          else
            candidate,
      ];
      return web;
    }
    await updateProject(projectId, ProjectChanges(description: html));
    webDescriptions.remove(projectId);
    return null;
  }

  /// Takes the project and its subtree out of [all].
  @override
  Future<void> deleteProject(int projectId) async {
    deletes.add(projectId);
    await _call('deleteProject', '$projectId');
    final doomed = subtreeIds(_all, projectId);
    all = [
      for (final project in _all)
        if (!doomed.contains(project.id)) project,
    ];
    if (tasks case final tasks?) {
      tasks.all = [
        for (final task in tasks.all)
          if (!doomed.contains(task.projectId)) task,
      ];
    }
  }

  /// Adds "<title> - duplicate" at the source's position, without
  /// identifier and favourite, its views under new ids.
  @override
  Future<int> duplicateProject(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  }) async {
    duplicates.add((
      projectId: projectId,
      parentProjectId: parentProjectId,
      copyShares: copyShares,
    ));
    await _call(
      'duplicateProject',
      '$projectId under $parentProjectId shares $copyShares',
    );
    if (projectId < 1) throw ArgumentError.value(projectId, 'projectId');
    final source = find(projectId);
    if (source == null) throw const NotFound(code: 3001);
    final id = nextProjectId++;
    all = [
      ..._all,
      copyProject(
        source,
        id: id,
        title: '${source.title} - duplicate',
        identifier: '',
        parentProjectId: parentProjectId,
        isFavorite: false,
        views: [
          for (final view in source.views)
            ProjectView(
              id: nextViewId++,
              projectId: id,
              title: view.title,
              kind: view.kind,
              position: view.position,
              filter: view.filter,
              bucketConfigurationMode: view.bucketConfigurationMode,
            ),
        ],
      ),
    ];
    if (tasks case final tasks?) {
      tasks.all = [
        ...tasks.all,
        for (final task in tasks.all)
          if (task.projectId == projectId)
            taskWithId(
              task,
              nextTaskId++,
            ).copyWith(projectId: id, identifier: '#${task.index}'),
      ];
    }
    return id;
  }

  Future<void> _call(String method, String arguments) async {
    final call = '$method $arguments';
    calls.add(call);
    await beforeCall?.call(call);
    if (failures[method] ?? failure case final failure?) throw failure;
  }

  static String _checkedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
    return trimmed;
  }

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

  /// The tasks the overview filter matches when evaluated here: set, the
  /// Overview shows those of [all] that are open, under
  /// `FilterEvaluation.local`, instead of the [overviewSnapshot]'s.
  Set<int>? get overviewMatches => _overviewMatches;

  set overviewMatches(Set<int>? ids) {
    _overviewMatches = ids == null ? null : Set.unmodifiable(ids);
    _notify();
  }

  Set<int>? _overviewMatches;

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
    if (_overviewMatches case final matches?) {
      return OverviewTasks(
        tasks: [
          for (final task in _all)
            if (!task.done && matches.contains(task.id)) task,
        ]..sort(_byDueThenNewest),
        filter: filter,
        filterEvaluation: FilterEvaluation.local,
      );
    }
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

  /// The tasks each view's filter matches when evaluated here, by view id:
  /// the list and board sources carry those of the project as
  /// `matchingIds`, and their done tasks always come along. A view without
  /// an entry is left to its snapshot, as one the device cannot evaluate.
  Map<int, Set<int>> get viewMatches => Map.unmodifiable(_viewMatches);
  final Map<int, Set<int>> _viewMatches = {};

  void setViewMatches(int viewId, Set<int>? ids) {
    if (ids == null) {
      _viewMatches.remove(viewId);
    } else {
      _viewMatches[viewId] = Set.unmodifiable(ids);
    }
    _notify();
  }

  /// Like the database: without [includeDone], the done tasks the view's
  /// download lacks stay out, unless the view's filter matches them.
  ProjectListSource projectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) {
    final byId = {for (final task in _all) task.id: task};
    final snapshot =
        _snapshots[listKeyFor(projectId: projectId, viewId: viewId)] ??
        const ListSnapshot();
    final matches = _viewMatches[viewId];
    bool loaded(Task task) =>
        includeDone ||
        !task.done ||
        snapshot.positions.containsKey(task.id) ||
        (matches?.contains(task.id) ?? false);
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
      queuedPositions: Map.unmodifiable(_queuedPositions[viewId] ?? const {}),
      matchingIds: matches == null
          ? null
          : {
              for (final task in projectTasks)
                if (matches.contains(task.id)) task.id,
            },
    );
  }

  final Map<int, Map<int, double>> _queuedPositions = {};

  /// The list positions queued per view id, by task id: what
  /// [positionTask] and `updateTask` queued, until a test sets them
  /// otherwise (an empty map: all sent or discarded).
  Map<int, Map<int, double>> get queuedPositions => {
    for (final MapEntry(:key, :value) in _queuedPositions.entries)
      key: Map.unmodifiable(value),
  };

  void setQueuedPositions(int viewId, Map<int, double> positions) {
    _queuedPositions[viewId] = {...positions};
    _notify();
  }

  /// What `positionTask` was given, in order, as `(taskId, viewId,
  /// position)`; [writes] has each as `position 1 view 11 at 32768.0`. The
  /// position is queued for the view (later ones win).
  final List<(int, int, double)> positions = [];

  @override
  Future<void> positionTask(
    int taskId, {
    required int viewId,
    required double position,
  }) async {
    positions.add((taskId, viewId, position));
    final id = remaps[taskId] ?? taskId;
    (_queuedPositions[viewId] ??= {})[id] = position;
    await _write('position $taskId view $viewId at $position', (task) => task);
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

  final Map<int, BoardSource> _boards = {};
  final Map<int, Map<int, BucketPlacement>> _queuedPlacements = {};

  /// Stores a board download of [view]: its buckets, each listed card's
  /// bucket and position by task id, and when it was taken (null: never).
  void setBoard(
    ProjectView view, {
    List<Bucket> buckets = const [],
    Map<int, BoardSlot> snapshot = const {},
    DateTime? loadedAt,
  }) {
    _boards[view.id] = BoardSource(
      view: view,
      buckets: buckets,
      snapshot: snapshot,
      loadedAt: loadedAt,
    );
    _notify();
  }

  /// The placements queued per view id, by task id: what [placeTask]
  /// queued, until a test sets them otherwise (an empty map: all sent).
  Map<int, Map<int, BucketPlacement>> get queuedPlacements => {
    for (final MapEntry(:key, :value) in _queuedPlacements.entries)
      key: Map.unmodifiable(value),
  };

  void setQueuedPlacements(int viewId, Map<int, BucketPlacement> placements) {
    _queuedPlacements[viewId] = {...placements};
    _notify();
  }

  Set<int> _queuedDoneChanges = const {};

  /// The tasks whose done change the board takes as not sent yet.
  void setQueuedDoneChanges(Set<int> taskIds) {
    _queuedDoneChanges = {...taskIds};
    _notify();
  }

  /// Like the database: the project's open tasks and the done ones the
  /// board can show (listed, created here, queued, or newer than the
  /// download), newest first.
  BoardSource board(int projectId, int viewId) {
    final download = _boards[viewId] ?? const BoardSource();
    final queued = _queuedPlacements[viewId] ?? const {};
    final loadedAt = download.loadedAt;
    bool newer(DateTime? moment) =>
        loadedAt != null && moment != null && moment.isAfter(loadedAt);
    final matches =
        download.view?.bucketConfigurationMode == BucketConfigurationMode.filter
        ? null
        : _viewMatches[viewId];
    bool shown(Task task) =>
        !task.done ||
        (matches?.contains(task.id) ?? false) ||
        task.id < 0 ||
        download.snapshot.containsKey(task.id) ||
        queued.containsKey(task.id) ||
        pendingTaskIds.contains(task.id) ||
        newer(task.created) ||
        newer(task.updated);
    final projectTasks = [
      for (final task in _all)
        if (task.projectId == projectId && shown(task)) task,
    ]..sort(_newestFirst);
    return BoardSource(
      view: download.view,
      buckets: download.buckets,
      snapshot: download.snapshot,
      loadedAt: loadedAt,
      projectTasks: projectTasks,
      queued: Map.unmodifiable(queued),
      queuedDoneChanges: Set.unmodifiable(_queuedDoneChanges),
      matchingIds: matches == null
          ? null
          : {
              for (final task in projectTasks)
                if (matches.contains(task.id)) task.id,
            },
    );
  }

  /// Every `watchBoard` as `(projectId, viewId)`.
  final List<(int, int)> boardWatches = [];

  /// The error `watchBoard` fails with, by view id.
  final Map<int, Object> boardErrors = {};

  @override
  Stream<BoardSource> watchBoard(int projectId, int viewId) {
    boardWatches.add((projectId, viewId));
    if (boardErrors[viewId] case final error?) return Stream.error(error);
    return _replaying(
      () => _all,
      _changes.stream,
    ).map((_) => board(projectId, viewId));
  }

  /// Every `refreshBoard` as `(projectId, viewId)`. Each runs a sync
  /// through the engine, then [onRefreshBoard] (which can [setBoard]), then
  /// throws [refreshBoardFailure] when one is set.
  final List<(int, int)> boardRefreshes = [];
  Future<void> Function(int projectId, int viewId)? onRefreshBoard;
  VikunjaFailure? refreshBoardFailure;

  @override
  Future<void> refreshBoard(int projectId, int viewId) async {
    boardRefreshes.add((projectId, viewId));
    await _engine.refresh();
    await onRefreshBoard?.call(projectId, viewId);
    if (refreshBoardFailure case final failure?) throw failure;
  }

  /// Every `loadMoreOfBucket` as `(projectId, viewId, bucketId)`. Each runs
  /// [onLoadMoreOfBucket], then throws [loadMoreOfBucketFailure] when one
  /// is set; no sync.
  final List<(int, int, int)> bucketLoads = [];
  Future<void> Function(int projectId, int viewId, int bucketId)?
  onLoadMoreOfBucket;
  VikunjaFailure? loadMoreOfBucketFailure;

  @override
  Future<void> loadMoreOfBucket(int projectId, int viewId, int bucketId) async {
    bucketLoads.add((projectId, viewId, bucketId));
    await onLoadMoreOfBucket?.call(projectId, viewId, bucketId);
    if (loadMoreOfBucketFailure case final failure?) throw failure;
  }

  /// What `placeTask` was given, in order, as `(taskId, viewId, placement,
  /// done)`; [writes] has each as `place 1 view 5 bucket 3 at 32768.0` or
  /// `… at null`, plus ` done true` when done is set. The placement is
  /// queued for the view (later ones win) and done applies to the task.
  final List<(int, int, BucketPlacement, bool?)> placements = [];

  @override
  Future<void> placeTask(
    int taskId, {
    required int viewId,
    required BucketPlacement placement,
    bool? done,
  }) async {
    placements.add((taskId, viewId, placement, done));
    final id = remaps[taskId] ?? taskId;
    (_queuedPlacements[viewId] ??= {})[id] = placement;
    await _write(
      'place $taskId view $viewId bucket ${placement.bucketId} '
      'at ${placement.position}${done == null ? '' : ' done $done'}',
      (task) => task.id == id && done != null
          ? copyTask(task, done: done, doneAt: done ? _doneAt : null)
          : task,
    );
  }

  /// Open favourite tasks outside [archivedProjectIds], like the database.
  List<Task> get favoriteTasks => [
    for (final task in activeOpenTasks)
      if (task.isFavorite) task,
  ];

  @override
  Stream<List<Task>> watchFavoriteTasks() =>
      _replaying(() => _all, _changes.stream).map((_) => favoriteTasks);

  @override
  Stream<ProjectProgress> watchProjectProgress(int projectId) =>
      _replaying(() => _all, _changes.stream).map((_) {
        final own = _all.where((task) => task.projectId == projectId);
        return (done: own.where((task) => task.done).length, total: own.length);
      });

  @override
  Stream<Map<int, int>> watchOpenTaskCounts() =>
      _replaying(() => _all, _changes.stream).map((_) {
        final counts = <int, int>{};
        for (final task in _all) {
          if (!task.done) {
            counts.update(task.projectId, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        return counts;
      });

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

  /// The tasks each saved filter matches when evaluated here, by pseudo
  /// project id: its list shows those of [all] that are open, under
  /// `FilterEvaluation.local`, instead of its snapshot's.
  Map<int, Set<int>> get savedFilterMatches =>
      Map.unmodifiable(_savedFilterMatches);
  final Map<int, Set<int>> _savedFilterMatches = {};

  void setSavedFilterMatches(int pseudoProjectId, Set<int>? ids) {
    if (ids == null) {
      _savedFilterMatches.remove(pseudoProjectId);
    } else {
      _savedFilterMatches[pseudoProjectId] = Set.unmodifiable(ids);
    }
    _notify();
  }

  SavedFilterTasks savedFilterTasks(int pseudoProjectId) {
    if (_savedFilterMatches[pseudoProjectId] case final matches?) {
      return SavedFilterTasks(
        tasks: [
          for (final task in _all)
            if (!task.done && matches.contains(task.id)) task,
        ]..sort(_byDueThenNewest),
        evaluation: FilterEvaluation.local,
      );
    }
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

  @override
  Stream<List<Task>> watchLabelTasks(int labelId) =>
      _replaying(() => _all, _changes.stream).map(
        (_) => [
          for (final task in _all)
            if (!task.done &&
                (task.isFavorite ||
                    !_archivedProjectIds.contains(task.projectId)) &&
                task.labels.any((label) => label.id == labelId))
              task,
        ]..sort(_byDueThenNewest),
      );

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
  /// `updateDescription 1`, `toggle 1 at 42 true`, `setDone 1 true`,
  /// `undoDone 1`, `setFavorite 2 false`, `delete 3`, `place …` (see
  /// [placements]), `position …` (see [positions]), `retry <op>`,
  /// `discard <op>`, `keepMine <op> over <html>`, `useWebs <op>`,
  /// `queueUpload 3 photo.png` (see [uploadRequests]), `cancelUpload <op>`
  /// or `sendPending`. A write applies to the task at once, like the local
  /// database; what counts as pending is the test's to say with
  /// [pendingChanges] and [pendingTaskIds].
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
    for (final queued in _queuedPlacements.values) {
      if (queued.remove(localId) case final placement?) {
        queued[serverId] = placement;
      }
    }
    for (final queued in _queuedPositions.values) {
      if (queued.remove(localId) case final position?) {
        queued[serverId] = position;
      }
    }
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
  /// followed; kanban placements and list positions are queued like
  /// [placeTask]'s and [positionTask]'s.
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
    for (final MapEntry(key: viewId, value: placement)
        in changes.kanban?.entries ?? _noPlacements) {
      (_queuedPlacements[viewId] ??= {})[id] = placement;
    }
    for (final MapEntry(key: viewId, value: position)
        in changes.positions?.entries ?? const <MapEntry<int, double>>[]) {
      (_queuedPositions[viewId] ??= {})[id] = position;
    }
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

  /// What `updateDescription` was given, in order, as `(taskId, html,
  /// base)`; [writes] has each as `updateDescription 1`. The description
  /// applies at once; false, like the real repository, when the task is not
  /// in [all].
  final List<(int, String, String)> descriptionUpdates = [];

  @override
  Future<bool> updateDescription(
    int taskId,
    String html, {
    required String base,
  }) async {
    descriptionUpdates.add((taskId, html, base));
    final id = remaps[taskId] ?? taskId;
    if (find(id) == null) return false;
    await _write(
      'updateDescription $taskId',
      (task) => task.id == id ? task.copyWith(description: html) : task,
    );
    return true;
  }

  /// What `toggleChecklistItem` was given, in order, as `(taskId, item,
  /// checked)`. Like the real repository it refuses (false) when the task's
  /// description is not the given HTML or the item cannot be toggled in
  /// it, and while [refuseToggles] is set; else [writes] has
  /// `toggle 1 at <offset> true` and the toggled description applies.
  final List<(int, RichTaskItem, bool)> checklistToggles = [];
  bool refuseToggles = false;

  @override
  Future<bool> toggleChecklistItem(
    int taskId, {
    required String html,
    required RichTaskItem item,
    required bool checked,
  }) async {
    checklistToggles.add((taskId, item, checked));
    final task = find(taskId);
    if (refuseToggles || task == null || task.description != html) {
      return false;
    }
    final toggled = toggleTaskItem(html, item, checked: checked);
    if (toggled == null) return false;
    await _write(
      'toggle $taskId at ${item.sourceOffset} $checked',
      (other) =>
          other.id == task.id ? other.copyWith(description: toggled) : other,
    );
    return true;
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

  /// The largest file `queueUpload` takes; above it `UploadTooLarge`.
  int maxUploadBytes = 20 * 1024 * 1024;

  /// The size `queueUpload` records per source path (0 when absent): the
  /// fake never reads files.
  final Map<String, int> uploadSizes = {};

  /// What `queueUpload` was given, in order; [writes] has each as
  /// `queueUpload 3 photo.png` (plus ` move` with `moveSource`). It queues
  /// a waiting [PendingUpload] under the op id `upload-<n>`, or returns
  /// null for a task not in [all]. [queueUploadFailure] is thrown instead
  /// while set.
  final List<
    ({
      int taskId,
      String sourcePath,
      String fileName,
      String? mimeType,
      bool moveSource,
    })
  >
  uploadRequests = [];
  Exception? queueUploadFailure;
  var _nextUpload = 1;
  final Map<String, PendingUpload> _uploads = {};
  final _uploadChanges = StreamController<void>.broadcast();
  final _uploaded = StreamController<TaskAttachment>.broadcast();

  /// Every queued upload, oldest first.
  List<PendingUpload> get pendingUploads => List.unmodifiable(_uploads.values);

  @override
  Future<String?> queueUpload(
    int taskId, {
    required String sourcePath,
    required String fileName,
    String? mimeType,
    bool moveSource = false,
  }) async {
    uploadRequests.add((
      taskId: taskId,
      sourcePath: sourcePath,
      fileName: fileName,
      mimeType: mimeType,
      moveSource: moveSource,
    ));
    writes.add('queueUpload $taskId $fileName${moveSource ? ' move' : ''}');
    await beforeWrite?.call();
    if (queueUploadFailure case final failure?) throw failure;
    final size = uploadSizes[sourcePath] ?? 0;
    if (size > maxUploadBytes) {
      throw UploadTooLarge(size: size, maxBytes: maxUploadBytes);
    }
    final task = find(taskId);
    if (task == null) return null;
    final id = 'upload-${_nextUpload++}';
    _uploads[id] = PendingUpload(
      operationId: id,
      taskId: task.id,
      fileName: fileName,
      size: size,
      mimeType: mimeType,
      state: PendingUploadState.waiting,
      queuedAt: createdAt,
    );
    _notifyUploads();
    return id;
  }

  /// Changes a queued upload's state, as the sender would.
  void setUploadState(
    String operationId,
    PendingUploadState state, {
    VikunjaFailure? failure,
  }) {
    final upload = _uploads[operationId];
    if (upload == null) return;
    _uploads[operationId] = PendingUpload(
      operationId: upload.operationId,
      taskId: upload.taskId,
      fileName: upload.fileName,
      size: upload.size,
      mimeType: upload.mimeType,
      state: state,
      queuedAt: upload.queuedAt,
      lastFailure: failure,
    );
    _notifyUploads();
  }

  /// The upload went through as [attachment]: it leaves the queue and
  /// `uploadedAttachments` reports it.
  void completeUpload(String operationId, TaskAttachment attachment) {
    _uploads.remove(operationId);
    _notifyUploads();
    if (!_uploaded.isClosed) _uploaded.add(attachment);
  }

  @override
  Stream<List<PendingUpload>> watchPendingUploads(int taskId) =>
      _replaying(() => true, _uploadChanges.stream.map((_) => true)).map((_) {
        final id = remaps[taskId] ?? taskId;
        return [
          for (final upload in _uploads.values)
            if ((remaps[upload.taskId] ?? upload.taskId) == id) upload,
        ];
      });

  @override
  Stream<TaskAttachment> get uploadedAttachments => _uploaded.stream;

  /// [writes] has `cancelUpload <op>`; the upload leaves the queue.
  @override
  Future<void> cancelUpload(String operationId) async {
    writes.add('cancelUpload $operationId');
    await beforeWrite?.call();
    _uploads.remove(operationId);
    _notifyUploads();
  }

  void _notifyUploads() {
    if (!_uploadChanges.isClosed) _uploadChanges.add(null);
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

  /// The description the server has, by task id: `useWebDescription`
  /// puts it back on the problem's task.
  final Map<int, String> webDescriptions = {};

  /// Thrown by `useWebDescription`, like a server read that failed.
  VikunjaFailure? useWebDescriptionFailure;

  /// Thrown by `webDescription`, like a server read that failed.
  VikunjaFailure? webDescriptionFailure;

  /// The problem's task's entry of [webDescriptions].
  @override
  Future<String?> webDescription(String operationId) async {
    if (webDescriptionFailure case final failure?) throw failure;
    final problem = _problemList
        .where((problem) => problem.operationId == operationId)
        .firstOrNull;
    if (problem == null) return null;
    return webDescriptions[remaps[problem.taskId] ?? problem.taskId];
  }

  /// [writes] has `keepMine <op> over <webDescription>`; the problem leaves
  /// [syncProblems].
  @override
  Future<void> keepMyDescription(
    String operationId, {
    required String webDescription,
  }) async {
    writes.add('keepMine $operationId over $webDescription');
    await beforeWrite?.call();
    _resolve(operationId);
  }

  /// [writes] has `useWebs <op>`; the problem leaves [syncProblems] and
  /// its task takes its entry of [webDescriptions].
  @override
  Future<void> useWebDescription(String operationId) async {
    writes.add('useWebs $operationId');
    await beforeWrite?.call();
    if (useWebDescriptionFailure case final failure?) throw failure;
    final problem = _problemList
        .where((problem) => problem.operationId == operationId)
        .firstOrNull;
    _resolve(operationId);
    if (problem == null) return;
    final id = remaps[problem.taskId] ?? problem.taskId;
    if (webDescriptions[id] case final description?) {
      all = [
        for (final task in _all)
          if (task.id == id) task.copyWith(description: description) else task,
      ];
    }
  }

  void _resolve(String operationId) => syncProblems = [
    for (final problem in _problemList)
      if (problem.operationId != operationId) problem,
  ];

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
    unawaited(_uploadChanges.close());
    unawaited(_uploaded.close());
  }
}

final class FakeAccountDatabaseFiles implements AccountDatabaseFiles {
  final List<String> deleted = [];

  @override
  Future<String> pathFor(String accountId) async =>
      '/support/accounts/$accountId/vikunja.db';

  @override
  Future<Directory> uploadsDirectoryFor(String accountId) async =>
      Directory('/support/accounts/$accountId/uploads');

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
    projects.tasks = tasks;
    resolver = FakeTaskResolver(local: () => tasks.all);
    accountSettings.onStateChanged = (state) => settings = state.settings;
    accountSecurity = FakeAccountSecurityRepository(now: () => now);
  }

  late final FakeSyncEngine engine;
  late final FakeProjectRepository projects;
  late final FakeTaskRepository tasks;
  final listPreferences = FakeListPreferences();
  final activity = FakeActivityRepository();
  final subscriptions = FakeSubscriptionRepository();
  final details = FakeTaskDetailsRepository();

  /// Changes the boards of [tasks] and the views of [projects].
  late final buckets = FakeBucketRepository(tasks: tasks, projects: projects);

  /// Changes the views of [projects].
  late final views = FakeProjectViewRepository(projects);

  /// Changes the saved filters of [projects].
  late final savedFilters = FakeSavedFilterRepository(projects);

  /// Searches [tasks] and [projects].
  late final search = FakeTaskSearch(tasks: tasks, projects: projects);

  /// Resolves the account's [tasks] locally, the rest from its `online`.
  late final FakeTaskResolver resolver;
  final attachmentImages = FakeAttachmentImages();
  final attachments = FakeAttachmentRepository();

  /// The account settings page's data; a change it makes also becomes
  /// [settings].
  final accountSettings = FakeAccountSettingsRepository();

  /// The security settings, sessions, tokens and export of the account
  /// settings pages, at the fakes' `now`.
  late final FakeAccountSecurityRepository accountSecurity;

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

  /// No share is waiting unless a test puts one there.
  final shareSource = FakeShareIntentSource();
  final fileActions = FakeFileActions();

  /// What a one-time secret view copied, and whether it hid the screen.
  final clipboard = FakeSensitiveClipboard();
  final secureDisplay = FakeSecureDisplay();

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
  FakeBucketRepository get buckets => shared.buckets;
  FakeProjectViewRepository get views => shared.views;
  FakeSavedFilterRepository get savedFilters => shared.savedFilters;
  FakeTaskSearch get search => shared.search;
  FakeTaskResolver get resolver => shared.resolver;
  FakeAttachmentImages get attachmentImages => shared.attachmentImages;
  FakeAttachmentRepository get attachments => shared.attachments;
  FakeAccountSecurityRepository get accountSecurity => shared.accountSecurity;

  AccountDataFakes forAccount(String accountId) =>
      accounts[accountId] ?? shared;

  List<Override> get overrides => [
    accountDatabaseFilesProvider.overrideWithValue(files),
    // A cache folder that never exists: a sign-out has nothing to delete,
    // and no screen test waits on real file system calls.
    attachmentDownloadsProvider.overrideWithValue(
      AttachmentDownloads(() async => Directory('/no-cache')),
    ),
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
    accountBucketRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).buckets,
    ),
    accountProjectViewRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).views,
    ),
    accountSavedFilterRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).savedFilters,
    ),
    accountTaskSearchProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).search,
    ),
    accountTaskResolverProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).resolver,
    ),
    accountAttachmentImagesProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).attachmentImages,
    ),
    accountAttachmentRepositoryProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).attachments,
    ),
    shareIntentSourceProvider.overrideWithValue(shareSource),
    fileActionsProvider.overrideWithValue(fileActions),
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
    accountSettingsRepositoryForProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).accountSettings,
    ),
    accountSecurityRepositoryForProvider.overrideWith(
      (ref, accountId) => forAccount(accountId).accountSecurity,
    ),
    sensitiveClipboardProvider.overrideWithValue(clipboard),
    secureDisplayProvider.overrideWithValue(secureDisplay),
    // The real one opens the account's database; every list reads it.
    userSettingsProvider.overrideWith((ref) {
      final accountId = ref.watch(activeAccountIdProvider);
      if (accountId == null) return Stream.value(const UserSettings());
      return forAccount(accountId).watchSettings();
    }),
  ];
}

const _noPlacements = <MapEntry<int, BucketPlacement>>[];
