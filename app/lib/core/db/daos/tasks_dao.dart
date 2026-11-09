import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/kanban_dao.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/project_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/task_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/lists.dart';
import 'package:vikunja_mobile/core/db/tables/projects.dart';
import 'package:vikunja_mobile/core/db/tables/task_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';
import 'package:vikunja_mobile/core/outbox/task_relation_inverse.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/archived_projects.dart';

part 'tasks_dao.g.dart';

typedef _TaskRows = ({TaskRow task, UserRow? createdBy});

/// A task row with what the filter language reads from its relations: the
/// creator's username (empty when unknown), label ids, assignee usernames
/// and the reminder instants.
typedef FilterRow = ({
  TaskRow task,
  String createdBy,
  Set<int> labelIds,
  Set<String> assignees,
  List<DateTime> reminders,
});

@DriftAccessor(
  tables: [
    Tasks,
    TaskLabels,
    TaskAssignees,
    TaskReminders,
    TaskRelations,
    Labels,
    Users,
    TaskIdRemaps,
    Projects,
    ProjectViews,
    ListSnapshots,
    ListSnapshotTasks,
  ],
)
final class TasksDao extends DatabaseAccessor<AppDatabase>
    with _$TasksDaoMixin {
  new(super.attachedDatabase);

  // Keeps every `IN (...)` list well below SQLite's variable limit.
  static const _chunkSize = 500;

  late final Set<ResultSetImplementation<dynamic, dynamic>> _readTables = {
    tasks,
    taskLabels,
    taskAssignees,
    taskReminders,
    taskRelations,
    labels,
    users,
  };

  /// A task queued for deletion is gone as far as every reader is
  /// concerned; the counts still include it, see [count].
  Expression<bool> get _visible => tasks.pendingDelete.equals(false);

  /// A task the server has named; a negative id is a task created here
  /// whose create is still queued.
  Expression<bool> get _onServer => tasks.id.isBiggerThanValue(0);

  /// A row with a queued op is never purged: it exists on the server or is
  /// being deleted anyway, and the pull after the op is sent sorts it out.
  Expression<bool> get _purgeable =>
      tasks.pendingChanges.isNull() &
      tasks.pendingDelete.equals(false) &
      _onServer;

  /// Newest first: a task created here comes before every server task,
  /// and temporary ids are handed out downwards.
  List<OrderingTerm> get _newestFirst => [
    OrderingTerm.desc(tasks.id.isSmallerThanValue(0)),
    OrderingTerm.desc(tasks.id.abs()),
  ];

  /// Open tasks across all projects: nearest due date first, tasks without
  /// one last, newest first within a date.
  Stream<List<Task>> watchOpenTasks() =>
      watchTables(_readTables, loadOpenTasks);

  Future<List<Task>> loadOpenTasks() =>
      _load(where: tasks.done.equals(false) & _visible, orderBy: _byDueDate);

  List<OrderingTerm> get _byDueDate => [
    OrderingTerm.asc(tasks.dueDate, nulls: NullsOrder.last),
    ..._newestFirst,
  ];

  /// [watchOpenTasks] without the tasks of archived projects and their
  /// subprojects, which `GET /tasks` leaves out too.
  Stream<List<Task>> watchActiveOpenTasks() =>
      watchTables({..._readTables, projects}, loadActiveOpenTasks);

  Future<List<Task>> loadActiveOpenTasks() async {
    final archived = await _archivedProjectIds();
    return await _load(
      where: archived.isEmpty
          ? tasks.done.equals(false) & _visible
          : tasks.done.equals(false) &
                _visible &
                tasks.projectId.isNotIn(archived),
      orderBy: _byDueDate,
    );
  }

  /// The open favourite tasks among [watchActiveOpenTasks], in its order.
  Stream<List<Task>> watchFavoriteTasks() =>
      watchTables({..._readTables, projects}, loadFavoriteTasks);

  Future<List<Task>> loadFavoriteTasks() async {
    final archived = await _archivedProjectIds();
    final favorite =
        tasks.done.equals(false) & tasks.isFavorite.equals(true) & _visible;
    return await _load(
      where: archived.isEmpty
          ? favorite
          : favorite & tasks.projectId.isNotIn(archived),
      orderBy: _byDueDate,
    );
  }

  Future<List<int>> _archivedProjectIds() async {
    final query = selectOnly(
      projects,
    )..addColumns([projects.id, projects.parentProjectId, projects.isArchived]);
    return archivedProjectIds([
      for (final row in await query.get())
        Project(
          id: row.read(projects.id)!,
          title: '',
          parentProjectId: row.read(projects.parentProjectId)!,
          isArchived: row.read(projects.isArchived)!,
        ),
    ]);
  }

  /// The open tasks among a list's last download ([listKey]), as
  /// [watchOpenTasks] orders them; one done or deleted here leaves at once.
  Stream<({List<Task> tasks, DateTime? loadedAt})> watchOpenTasksInList(
    String listKey,
  ) => watchTables({
    ..._readTables,
    listSnapshots,
    listSnapshotTasks,
  }, () => loadOpenTasksInList(listKey));

  Future<({List<Task> tasks, DateTime? loadedAt})> loadOpenTasksInList(
    String listKey,
  ) async {
    final header = await (select(
      listSnapshots,
    )..where((s) => s.listKey.equals(listKey))).getSingleOrNull();
    if (header == null) return (tasks: const <Task>[], loadedAt: null);
    final open = await _load(
      where:
          tasks.id.isInQuery(_snapshotTaskIds(listKey)) &
          tasks.done.equals(false) &
          _visible,
      orderBy: _byDueDate,
    );
    return (tasks: open, loadedAt: header.loadedAt);
  }

  /// What a project's list view is built from: the project's tasks (done
  /// ones only with [includeDone] or when the view's last download has
  /// them), every task reachable from them as a subtask in any project, the
  /// view's last download and the positions queued for the view; [viewId]
  /// 0 stands for a project without a list view.
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  }) => watchTables(
    projectListTables,
    () => loadProjectList(projectId, viewId: viewId, includeDone: includeDone),
  );

  /// What [loadProjectList] reads, plus the views and projects a filter
  /// evaluation needs.
  Set<ResultSetImplementation<dynamic, dynamic>> get projectListTables => {
    ..._readTables,
    listSnapshots,
    listSnapshotTasks,
    projectViews,
  };

  /// What the candidates of a saved filter are read from.
  Set<ResultSetImplementation<dynamic, dynamic>> get savedFilterTables => {
    ..._readTables,
    projects,
  };

  /// [matchingIds]: the tasks the view's filter matches as evaluated here;
  /// they are loaded also when done, and passed on.
  Future<ProjectListSource> loadProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
    Set<int>? matchingIds,
  }) async {
    final listKey = listKeyFor(projectId: projectId, viewId: viewId);
    final inProject = tasks.projectId.equals(projectId) & _visible;
    var projectTasks = await _load(
      where: includeDone
          ? inProject
          : inProject &
                (tasks.done.equals(false) |
                    tasks.id.isInQuery(_snapshotTaskIds(listKey))),
      orderBy: _newestFirst,
    );
    if (!includeDone && matchingIds != null) {
      final loaded = {for (final task in projectTasks) task.id};
      projectTasks = [
        ...projectTasks,
        ...await _loadIds(matchingIds.difference(loaded)),
      ]..sort(_compareNewestFirst);
    }
    final byId = {for (final task in projectTasks) task.id: task};
    // The hydrated relations only name local tasks that are not queued for
    // deletion, so every id asked for here exists.
    var frontier = projectTasks;
    while (frontier.isNotEmpty) {
      final missing = {
        for (final task in frontier)
          for (final subtask in task.subtasks)
            if (!byId.containsKey(subtask.id)) subtask.id,
      };
      frontier = await _loadIds(missing);
      for (final task in frontier) {
        byId[task.id] = task;
      }
    }
    return ProjectListSource(
      projectTasks: projectTasks,
      tasksById: byId,
      snapshot: await attachedDatabase.listSnapshotsDao.load(listKey),
      omitsDoneTasks:
          !includeDone &&
          await _hasDoneTasksOutside(
            projectId,
            listKey,
            matchingIds: matchingIds,
          ),
      queuedPositions: viewId == 0
          ? const {}
          : await _queuedPositions(projectId, viewId),
      matchingIds: matchingIds,
    );
  }

  static int _compareNewestFirst(Task a, Task b) {
    if ((a.id < 0) != (b.id < 0)) return a.id < 0 ? -1 : 1;
    return b.id.abs().compareTo(a.id.abs());
  }

  /// The project's tasks as the filter language reads them: what a view of
  /// it covers, archived project included; with [openOnly] the open ones.
  Future<List<FilterRow>> loadFilterRowsInProject(
    int projectId, {
    bool openOnly = false,
  }) => _loadFilterRows(
    tasks.projectId.equals(projectId) &
        _visible &
        (openOnly ? tasks.done.equals(false) : const Constant(true)),
  );

  /// The tasks a saved filter covers: those outside archived projects and
  /// their subprojects, and the favourite ones anywhere, as the server's
  /// `GET /tasks`; with [openOnly] the open ones.
  Future<List<FilterRow>> loadFilterRowsOfSavedFilters({
    bool openOnly = false,
  }) async {
    final archived = await _archivedProjectIds();
    final candidates = openOnly
        ? _visible & tasks.done.equals(false)
        : _visible;
    return await _loadFilterRows(
      archived.isEmpty
          ? candidates
          : candidates &
                (tasks.projectId.isNotIn(archived) |
                    tasks.isFavorite.equals(true)),
    );
  }

  /// Three batched queries per chunk of rows, and only the columns the
  /// filter language reads from the relations.
  Future<List<FilterRow>> _loadFilterRows(Expression<bool> where) async {
    final query = select(tasks).join([
      leftOuterJoin(users, users.id.equalsExp(tasks.createdById)),
    ])..where(where);
    final rows = [
      for (final row in await query.get())
        (
          task: row.readTable(tasks),
          createdBy: row.readTableOrNull(users)?.username ?? '',
        ),
    ];
    final labelIds = <int, Set<int>>{};
    final assignees = <int, Set<String>>{};
    final reminders = <int, List<DateTime>>{};
    final ids = [for (final row in rows) row.task.id];
    for (var start = 0; start < ids.length; start += _chunkSize) {
      final chunk = ids.sublist(
        start,
        (start + _chunkSize).clamp(0, ids.length),
      );
      final labelQuery = selectOnly(taskLabels)
        ..addColumns([taskLabels.taskId, taskLabels.labelId])
        ..where(taskLabels.taskId.isIn(chunk));
      for (final row in await labelQuery.get()) {
        labelIds
            .putIfAbsent(row.read(taskLabels.taskId)!, () => {})
            .add(row.read(taskLabels.labelId)!);
      }
      final assigneeQuery =
          selectOnly(
              taskAssignees,
            ).join([innerJoin(users, users.id.equalsExp(taskAssignees.userId))])
            ..addColumns([taskAssignees.taskId, users.username])
            ..where(taskAssignees.taskId.isIn(chunk));
      for (final row in await assigneeQuery.get()) {
        assignees
            .putIfAbsent(row.read(taskAssignees.taskId)!, () => {})
            .add(row.read(users.username)!);
      }
      final reminderQuery = selectOnly(taskReminders)
        ..addColumns([taskReminders.taskId, taskReminders.reminder])
        ..where(
          taskReminders.taskId.isIn(chunk) & taskReminders.reminder.isNotNull(),
        );
      for (final row in await reminderQuery.get()) {
        reminders
            .putIfAbsent(row.read(taskReminders.taskId)!, () => [])
            .add(
              row.readWithConverter<DateTime?, int>(taskReminders.reminder)!,
            );
      }
    }
    return [
      for (final (:task, :createdBy) in rows)
        (
          task: task,
          createdBy: createdBy,
          labelIds: labelIds[task.id] ?? const {},
          assignees: assignees[task.id] ?? const {},
          reminders: reminders[task.id] ?? const [],
        ),
    ];
  }

  /// The tasks with [ids] that are open, as [watchOpenTasks] orders them.
  Future<List<Task>> loadOpenTasksAmong(Set<int> ids) async =>
      (await _loadIds(ids, openOnly: true))..sort(_compareByDueDate);

  static int _compareByDueDate(Task a, Task b) {
    final byDue = switch ((a.dueDate, b.dueDate)) {
      (null, null) => 0,
      (null, _) => 1,
      (_, null) => -1,
      (final a?, final b?) => a.compareTo(b),
    };
    if (byDue != 0) return byDue;
    if ((a.id < 0) != (b.id < 0)) return a.id < 0 ? -1 : 1;
    return b.id.abs().compareTo(a.id.abs());
  }

  /// The unsent positions of the project's tasks on the view, by task id.
  Future<Map<int, double>> _queuedPositions(int projectId, int viewId) async {
    final query = selectOnly(tasks)
      ..addColumns([tasks.id, tasks.pendingChanges])
      ..where(
        tasks.projectId.equals(projectId) &
            _visible &
            tasks.pendingChanges.like('%"positions"%'),
      );
    return {
      for (final row in await query.get())
        row.read(tasks.id)!: ?decodeTaskChanges(row.read(tasks.pendingChanges)!)
            .positions?[viewId],
    };
  }

  /// What a kanban view's board is built from, see [BoardSource].
  Stream<BoardSource> watchBoard(int projectId, int viewId) =>
      watchTables(boardTables, () => loadBoard(projectId, viewId));

  Set<ResultSetImplementation<dynamic, dynamic>> get boardTables => {
    ..._readTables,
    listSnapshots,
    listSnapshotTasks,
    projectViews,
    attachedDatabase.kanbanBuckets,
  };

  /// A long-lived project holds far more done tasks than open ones, so
  /// only the done ones the board can show are loaded; [matchingIds], the
  /// tasks the view's filter matches as evaluated here, is passed on.
  Future<BoardSource> loadBoard(
    int projectId,
    int viewId, {
    Set<int>? matchingIds,
  }) async {
    final board = await attachedDatabase.kanbanDao.load(viewId);
    final listKey = KanbanDao.boardKey(viewId);
    var shown =
        tasks.done.equals(false) |
        tasks.id.isInQuery(_snapshotTaskIds(listKey)) |
        tasks.id.isSmallerThanValue(0) |
        tasks.pendingChanges.isNotNull();
    if (board.loadedAt case final loadedAt?) {
      final millis = const EpochMillis().toSql(loadedAt);
      shown =
          shown |
          tasks.created.isBiggerThanValue(millis) |
          tasks.updated.isBiggerThanValue(millis);
    }
    var projectTasks = await _load(
      where: tasks.projectId.equals(projectId) & _visible & shown,
      orderBy: _newestFirst,
    );
    // After a download only the tasks above can show; before one every
    // task counts as newer, the done matches too.
    if (matchingIds != null && board.loadedAt == null) {
      final loaded = {for (final task in projectTasks) task.id};
      projectTasks = [
        ...projectTasks,
        ...await _loadIds(matchingIds.difference(loaded)),
      ]..sort(_compareNewestFirst);
    }
    final view = await (select(
      projectViews,
    )..where((v) => v.id.equals(viewId))).getSingleOrNull();
    final pending = await _pendingBoardChanges(projectId);
    return BoardSource(
      view: view == null ? null : projectViewFromRow(view),
      buckets: board.buckets,
      snapshot: board.slots,
      loadedAt: board.loadedAt,
      projectTasks: projectTasks,
      queued: {
        for (final (id, changes) in pending) id: ?changes.kanban?[viewId],
      },
      movedHere: {
        for (final (id, changes) in pending)
          if (changes.projectId == projectId) id,
      },
      queuedDoneChanges: {
        for (final (id, changes) in pending)
          if (changes.done != null) id,
      },
      matchingIds: matchingIds,
    );
  }

  /// The unsent changes of the project's tasks that place them on a board,
  /// mark them done or open, or move them into the project.
  Future<List<(int, TaskChanges)>> _pendingBoardChanges(int projectId) async {
    final query = selectOnly(tasks)
      ..addColumns([tasks.id, tasks.pendingChanges])
      ..where(
        tasks.projectId.equals(projectId) &
            _visible &
            (tasks.pendingChanges.like('%"kanban"%') |
                tasks.pendingChanges.like('%"done"%') |
                tasks.pendingChanges.like('%"project_id"%')),
      );
    return [
      for (final row in await query.get())
        (
          row.read(tasks.id)!,
          decodeTaskChanges(row.read(tasks.pendingChanges)!),
        ),
    ];
  }

  Future<bool> _hasDoneTasksOutside(
    int projectId,
    String listKey, {
    Set<int>? matchingIds,
  }) async {
    final query = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(
        tasks.projectId.equals(projectId) &
            _visible &
            tasks.done.equals(true) &
            tasks.id.isNotInQuery(_snapshotTaskIds(listKey)),
      );
    if (matchingIds == null) {
      query.limit(1);
      return (await query.get()).isNotEmpty;
    }
    return (await query.get()).any(
      (row) => !matchingIds.contains(row.read(tasks.id)),
    );
  }

  BaseSelectStatement<TypedResult> _snapshotTaskIds(String listKey) =>
      selectOnly(listSnapshotTasks)
        ..addColumns([listSnapshotTasks.taskId])
        ..where(listSnapshotTasks.listKey.equals(listKey));

  Future<List<Task>> _loadIds(Set<int> ids, {bool openOnly = false}) async {
    final all = ids.toList();
    return [
      for (var start = 0; start < all.length; start += _chunkSize)
        ...await _load(
          where:
              tasks.id.isIn(
                all.sublist(start, (start + _chunkSize).clamp(0, all.length)),
              ) &
              _visible &
              (openOnly ? tasks.done.equals(false) : const Constant(true)),
          orderBy: const [],
        ),
    ];
  }

  /// Every task, newest first, without the labels, assignees, reminders
  /// and relations the other reads load; so it re-runs only when the tasks
  /// table changes.
  Stream<List<Task>> watchSearchableTasks() =>
      watchTables({tasks}, loadSearchableTasks);

  Future<List<Task>> loadSearchableTasks() async {
    final query = select(tasks)
      ..where((t) => _visible)
      ..orderBy([for (final term in _newestFirst) (_) => term]);
    return [for (final row in await query.get()) taskFromRow(row)];
  }

  /// One task, following a temporary id to the server id once the create
  /// is answered; null once the row is gone or queued for deletion.
  Stream<Task?> watchTask(int id) => watchTables({
    ..._readTables,
    taskIdRemaps,
  }, () async => await find(await resolveId(id)));

  /// The server id a temporary [id] was remapped to, else [id] itself.
  Future<int> resolveId(int id) async {
    if (id > 0) return id;
    final remap = await (select(
      taskIdRemaps,
    )..where((r) => r.localId.equals(id))).getSingleOrNull();
    return remap?.serverId ?? id;
  }

  /// Every server id a create of this device was remapped to.
  Future<Set<int>> remappedServerIds() async {
    final query = selectOnly(taskIdRemaps)..addColumns([taskIdRemaps.serverId]);
    return {
      for (final row in await query.get()) row.read(taskIdRemaps.serverId)!,
    };
  }

  Future<Task?> find(int id) async {
    final found = await _load(
      where: tasks.id.equals(id) & _visible,
      orderBy: const [],
    );
    return found.singleOrNull;
  }

  Future<Map<int, Task>> findAll(Iterable<int> ids) async {
    final found = await _load(
      where: tasks.id.isIn(ids) & _visible,
      orderBy: const [],
    );
    return {for (final task in found) task.id: task};
  }

  /// The local project whose identifier equals [identifier] ignoring case,
  /// and its task with [index] unless that is not local; null without such
  /// a project. Compared here, because SQLite's `lower()` folds ASCII only
  /// (`ÄB`, `STRAßE`); the server stores identifiers upper-cased and unique.
  Future<({int projectId, Task? task})?> findByIdentifier(
    String identifier,
    int index,
  ) async {
    final wanted = identifier.toLowerCase();
    final candidates = selectOnly(projects)
      ..addColumns([projects.id, projects.identifier])
      ..where(
        projects.id.isBiggerThanValue(0) & projects.identifier.equals('').not(),
      );
    final projectId = [
      for (final row in await candidates.get())
        if (row.read(projects.identifier)!.toLowerCase() == wanted)
          row.read(projects.id)!,
    ].firstOrNull;
    if (projectId == null) return null;
    final found = await _load(
      where:
          tasks.projectId.equals(projectId) &
          tasks.taskIndex.equals(index) &
          _visible,
      orderBy: const [],
    );
    return (projectId: projectId, task: found.firstOrNull);
  }

  /// The stored row, a task queued for deletion included.
  Future<TaskRow?> findRow(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Writes only what differs, so that the lists do not reload for nothing.
  Future<void> storeCommentState(
    int id, {
    int? commentCount,
    bool? isUnread,
  }) async {
    final differs = [
      if (commentCount != null) tasks.commentCount.equals(commentCount).not(),
      if (isUnread != null) tasks.isUnread.equals(isUnread).not(),
    ];
    if (differs.isEmpty) return;
    await (update(
      tasks,
    )..where((t) => t.id.equals(id) & Expression.or(differs))).write(
      TasksCompanion(
        commentCount: Value.absentIfNull(commentCount),
        isUnread: Value.absentIfNull(isUnread),
      ),
    );
  }

  /// [delta] added to the stored comment count, never below 0.
  Future<void> addToCommentCount(int id, int delta) async {
    if (delta == 0) return;
    await customUpdate(
      'UPDATE tasks SET comment_count = MAX(0, comment_count + ?) '
      'WHERE id = ?',
      variables: [Variable.withInt(delta), Variable.withInt(id)],
      updates: {tasks},
    );
  }

  /// The counts mirror the server, so they include the rows queued for
  /// deletion: the server holds those until the delete is sent, and the
  /// sync's probe must not see a mismatch on every run until then. Tasks
  /// created here and not yet sent are left out for the same reason.
  Future<int> count() {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([count])
      ..where(_onServer);
    return query.map((row) => row.read(count)!).getSingle();
  }

  Future<int> countInProject(int projectId) {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([count])
      ..where(tasks.projectId.equals(projectId) & _onServer);
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// The tasks outside [projectIds]: with the archived projects given, the
  /// tasks `GET /tasks` would return.
  Future<int> countNotInProjects(Iterable<int> projectIds) {
    final excluded = projectIds.toList();
    if (excluded.isEmpty) return count();
    final total = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([total])
      ..where(tasks.projectId.isNotIn(excluded) & _onServer);
    return query.map((row) => row.read(total)!).getSingle();
  }

  /// A project's own tasks as the lists show them (created here included,
  /// queued deletions not), and how many of them are done.
  Stream<ProjectProgress> watchProjectProgress(int projectId) {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([tasks.done, count])
      ..where(tasks.projectId.equals(projectId) & _visible)
      ..groupBy([tasks.done]);
    return query.watch().map((rows) {
      var done = 0;
      var total = 0;
      for (final row in rows) {
        final tasksOfKind = row.read(count)!;
        total += tasksOfKind;
        if (row.read(tasks.done)!) done += tasksOfKind;
      }
      return (done: done, total: total);
    }).distinct();
  }

  /// By project id, the open tasks the lists show; projects without any
  /// are left out.
  Stream<Map<int, int>> watchOpenTaskCounts() {
    final count = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([tasks.projectId, count])
      ..where(tasks.done.equals(false) & _visible)
      ..groupBy([tasks.projectId]);
    // Drift runs the query again on every write to the tasks table.
    return query
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read(tasks.projectId)!: row.read(count)!,
          },
        )
        .distinct(mapEquals);
  }

  Future<List<int>> idsInProject(int projectId) =>
      _ids(tasks.projectId.equals(projectId) & _visible);

  Future<List<int>> _ids(Expression<bool> where) {
    final query = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(where);
    return query.map((row) => row.read(tasks.id)!).get();
  }

  /// The newest server `updated` of any task, at most [notAfter]; null
  /// without one.
  Future<DateTime?> maxUpdated({DateTime? notAfter}) async {
    final newest = tasks.updated.max();
    final query = selectOnly(tasks)..addColumns([newest]);
    if (notAfter != null) {
      query.where(
        tasks.updated.isSmallerOrEqualValue(
          const EpochMillis().toSql(notAfter),
        ),
      );
    }
    final millis = await query.map((row) => row.read(newest)).getSingle();
    return millis == null ? null : const EpochMillis().fromSql(millis);
  }

  Future<int> purgeInProjects(Iterable<int> projectIds) => transaction(
    () async =>
        await _purge(await _ids(tasks.projectId.isIn(projectIds) & _purgeable)),
  );

  /// The tasks of projects deleted on the server, unlike [purgeInProjects]
  /// also those with queued ops, which go with them, a create cancelled
  /// here (`OutboxDao.cancelCreate`): they would fail while the project is
  /// gone or in the server's trash, and a restore from the trash does not
  /// bring them back. Kept is a server task
  /// whose queued changes move it into one of the projects: the server
  /// still has it where it was, and its op fails as a sync problem whose
  /// discard brings it back.
  Future<int> purgeInDeletedProjects(Set<int> projectIds) =>
      transaction(() async {
        final query = selectOnly(tasks)
          ..addColumns([tasks.id, tasks.pendingChanges])
          ..where(tasks.projectId.isIn(projectIds));
        final created = <int>[];
        final gone = <int>[];
        for (final row in await query.get()) {
          final id = row.read(tasks.id)!;
          final pending = row.read(tasks.pendingChanges);
          if (id < 0) {
            created.add(id);
          } else if (pending == null ||
              decodeTaskChanges(pending).projectId == null) {
            gone.add(id);
          }
        }
        final outbox = attachedDatabase.outboxDao;
        for (final id in created) {
          await outbox.cancelCreate(id);
        }
        for (final id in gone) {
          await outbox.removeAllOf(id);
        }
        return created.length + await _purge(gone);
      });

  /// The identifiers the server shows for the project's tasks once the
  /// project's identifier is [identifier]: `IDENT-<index>`, or `#<index>`
  /// without one. Tasks created here keep theirs until the server names
  /// them.
  Future<void> renameIdentifiers(int projectId, String identifier) =>
      (update(tasks)..where(
            (t) => t.projectId.equals(projectId) & t.id.isBiggerThanValue(0),
          ))
          .write(
            TasksCompanion.custom(
              identifier:
                  Constant(identifier.isEmpty ? '#' : '$identifier-') +
                  tasks.taskIndex.cast<String>(),
            ),
          );

  /// Removes the tasks of [projectId] whose id is not in [keep]. The ids to
  /// delete are picked locally, so the statements stay small whatever the
  /// size of [keep].
  Future<int> purgeInProjectExcept(int projectId, Set<int> keep) =>
      transaction(() async {
        final candidates = await _ids(
          tasks.projectId.equals(projectId) & _purgeable,
        );
        return await _purge([
          for (final id in candidates)
            if (!keep.contains(id)) id,
        ]);
      });

  /// Deletes the rows [gone], whose labels, assignees, reminders and
  /// relations go with them, and drops the queued edges other tasks have
  /// to them (`OutboxDao.forgetRelatedTasks`): the server no longer has
  /// them for this user.
  Future<int> _purge(List<int> gone) async {
    var purged = 0;
    for (var start = 0; start < gone.length; start += _chunkSize) {
      final chunk = gone.sublist(
        start,
        (start + _chunkSize).clamp(0, gone.length),
      );
      purged += await (delete(tasks)..where((t) => t.id.isIn(chunk))).go();
    }
    await attachedDatabase.outboxDao.forgetRelatedTasks(gone.toSet());
    return purged;
  }

  /// Upserts the tasks with the users and labels they carry, replacing their
  /// labels, assignees, reminders and relations; marks them seen in
  /// [syncRunId], or leaves the run a row has when null. The comment count
  /// and unread flag are taken only [withCommentState], from a read that
  /// expanded both; otherwise the stored ones stay. A row with queued
  /// changes keeps those fields over the incoming values, its queued label,
  /// assignee and relation changes apply to the incoming sets and its
  /// queued reminders replace the incoming list; a row queued for deletion
  /// stays hidden. The relation changes other tasks still have queued keep
  /// their inverse edges on the incoming tasks, as the server will once
  /// they are sent, and the edges other local tasks hold to the incoming
  /// ones follow theirs, see [_matchInverseRows]. One transaction, so that
  /// a change queued meanwhile is not overwritten with the queue as it was
  /// read.
  Future<void> upsertAll(
    List<Task> all, {
    String? syncRunId,
    bool withCommentState = false,
  }) => transaction(() async {
    final ids = [for (final task in all) task.id];
    final queued = await _queuedRows(ids);
    final queuedRelations = await _queuedRelationChanges();
    final inverse = _inverseEdgesOn(ids.toSet(), queuedRelations);
    final pending = {
      for (final row in queued.values)
        if (row.pendingChanges case final json?)
          row.id: decodeTaskChanges(json),
    };
    final knownLabels = {
      for (final task in all) ...task.labels.map((label) => label.id),
      ...await _existingLabelIds({
        for (final changes in pending.values) ...?changes.labels?.added,
      }),
    };
    final knownUsers = {
      for (final task in all) ...task.assignees.map((user) => user.id),
      ...await _existingUserIds({
        for (final changes in pending.values) ...?changes.assignees?.added,
      }),
    };
    final taskRows = <TasksCompanion>[];
    final relationRows = <TaskRelationRow>[];
    final labelRows = <TaskLabelRow>[];
    final assigneeRows = <TaskAssigneeRow>[];
    final reminders = <TaskReminderRow>[];
    for (final task in all) {
      var stored = taskRow(task, syncRunId: syncRunId);
      if (queued[task.id] case final local?) {
        stored = _keepQueued(stored, local);
      }
      var companion = stored.toCompanion(false);
      if (syncRunId == null) {
        companion = companion.copyWith(syncRunId: const Value.absent());
      }
      if (!withCommentState) {
        companion = companion.copyWith(
          commentCount: const Value.absent(),
          isUnread: const Value.absent(),
        );
      }
      taskRows.add(companion);
      final changes = pending[task.id];
      relationRows.addAll(
        _relationRows(task, inverse[task.id], changes?.relations),
      );
      if (changes == null) {
        labelRows.addAll(taskLabelRows(task));
        assigneeRows.addAll(taskAssigneeRows(task));
        reminders.addAll(taskReminderRows(task));
        continue;
      }
      labelRows.addAll([
        for (final id in _applied(
          changes.labels,
          task.labels.map((label) => label.id),
        ))
          if (knownLabels.contains(id))
            TaskLabelRow(taskId: task.id, labelId: id),
      ]);
      assigneeRows.addAll([
        for (final id in _applied(
          changes.assignees,
          task.assignees.map((user) => user.id),
        ))
          if (knownUsers.contains(id))
            TaskAssigneeRow(taskId: task.id, userId: id),
      ]);
      reminders.addAll(
        reminderRows(
          task.id,
          _remindersFor(
            stored,
            changes,
            current: changes.reminders ?? task.reminders,
          ),
        ),
      );
    }

    await batch((b) {
      b
        ..insertAllOnConflictUpdate(users, [
          for (final task in all) ...[
            if (task.createdBy case final user?) userRow(user),
            ...task.assignees.map(userRow),
          ],
        ])
        ..insertAllOnConflictUpdate(labels, [
          for (final task in all)
            for (final label in task.labels) labelRow(label).toCompanion(false),
        ])
        ..insertAllOnConflictUpdate(tasks, taskRows)
        ..deleteWhere(taskLabels, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskAssignees, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskReminders, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskRelations, (t) => t.taskId.isIn(ids))
        ..insertAllOnConflictUpdate(taskLabels, labelRows)
        ..insertAllOnConflictUpdate(taskAssignees, assigneeRows)
        ..insertAllOnConflictUpdate(taskReminders, [
          for (final reminder in reminders) reminder.toCompanion(false),
        ])
        ..insertAllOnConflictUpdate(taskRelations, relationRows);
    });
    await _matchInverseRows(ids.toSet(), relationRows, queuedRelations);
  });

  /// The child rows of the task stored as [row], which already carries the
  /// rest of [changes]: the label, assignee and relation changes applied,
  /// the reminder list replaced, and the instants of relative reminders
  /// computed from the row's dates whenever the list or a date changes.
  /// A label or user this device has no row for is skipped here (the
  /// foreign keys need the row); the change still goes to the server. A
  /// relation also changes the inverse edge on the other task when this
  /// device has it, as the server does.
  Future<void> applyChildChanges(TaskRow row, TaskChanges changes) async {
    final taskId = row.id;
    if (changes.relations case final delta?) {
      await _applyRelationChange(taskId, delta);
    }
    if (changes.labels case final delta?) {
      if (delta.removed.isNotEmpty) {
        await (delete(taskLabels)..where(
              (t) => t.taskId.equals(taskId) & t.labelId.isIn(delta.removed),
            ))
            .go();
      }
      final added = await _existingLabelIds(delta.added);
      if (added.isNotEmpty) {
        await batch(
          (b) => b.insertAll(taskLabels, [
            for (final id in added) TaskLabelRow(taskId: taskId, labelId: id),
          ], mode: InsertMode.insertOrIgnore),
        );
      }
    }
    if (changes.assignees case final delta?) {
      if (delta.removed.isNotEmpty) {
        await (delete(taskAssignees)..where(
              (t) => t.taskId.equals(taskId) & t.userId.isIn(delta.removed),
            ))
            .go();
      }
      final added = await _existingUserIds(delta.added);
      if (added.isNotEmpty) {
        await batch(
          (b) => b.insertAll(taskAssignees, [
            for (final id in added) TaskAssigneeRow(taskId: taskId, userId: id),
          ], mode: InsertMode.insertOrIgnore),
        );
      }
    }
    if (changes.reminders == null && !changesDates(changes)) return;
    final current =
        changes.reminders ??
        [
          for (final reminder
              in await (select(taskReminders)
                    ..where((r) => r.taskId.equals(taskId))
                    ..orderBy([(r) => OrderingTerm.asc(r.ordinal)]))
                  .get())
            reminderFromRow(reminder),
        ];
    await (delete(taskReminders)..where((r) => r.taskId.equals(taskId))).go();
    await batch(
      (b) => b.insertAll(
        taskReminders,
        reminderRows(
          taskId,
          withLocalInstants(
            current,
            dueDate: row.dueDate,
            startDate: row.startDate,
            endDate: row.endDate,
          ),
        ),
      ),
    );
  }

  /// The server named the task created here as [localId]: the edges of
  /// other tasks that point at it follow.
  Future<void> remapRelatedTask(int localId, int serverId) async {
    await customUpdate(
      'UPDATE OR IGNORE task_relations SET other_task_id = ? '
      'WHERE other_task_id = ?',
      variables: [Variable.withInt(serverId), Variable.withInt(localId)],
      updates: {taskRelations},
    );
    await (delete(
      taskRelations,
    )..where((r) => r.otherTaskId.equals(localId))).go();
  }

  /// Tasks the server does not have: no edge may point at them, and their
  /// own edges, inverses of those, go too.
  Future<void> forgetRelatedTasks(Set<int> taskIds) async {
    final ids = taskIds.toList();
    for (var start = 0; start < ids.length; start += _chunkSize) {
      final chunk = ids.sublist(
        start,
        (start + _chunkSize).clamp(0, ids.length),
      );
      await (delete(
        taskRelations,
      )..where((r) => r.otherTaskId.isIn(chunk) | r.taskId.isIn(chunk))).go();
    }
  }

  Future<void> _applyRelationChange(int taskId, RelationChange delta) async {
    for (final ref in delta.removed) {
      await (delete(taskRelations)..where(
            (r) =>
                (r.taskId.equals(taskId) &
                    r.otherTaskId.equals(ref.otherTaskId) &
                    r.kind.equals(ref.kind.wireName)) |
                (r.taskId.equals(ref.otherTaskId) &
                    r.otherTaskId.equals(taskId) &
                    r.kind.equals(inverseRelationKind(ref.kind).wireName)),
          ))
          .go();
    }
    if (delta.added.isEmpty) return;
    final others = await _existingTaskIds({
      for (final ref in delta.added) ref.otherTaskId,
    });
    await batch(
      (b) => b.insertAll(taskRelations, [
        for (final ref in delta.added) ...[
          TaskRelationRow(
            taskId: taskId,
            otherTaskId: ref.otherTaskId,
            kind: ref.kind.wireName,
          ),
          if (others.contains(ref.otherTaskId))
            TaskRelationRow(
              taskId: ref.otherTaskId,
              otherTaskId: taskId,
              kind: inverseRelationKind(ref.kind).wireName,
            ),
        ],
      ], mode: InsertMode.insertOrIgnore),
    );
  }

  /// [task]'s edges as the server sent them, with the inverse edges of
  /// other tasks' queued relation changes and then its own queued relation
  /// change applied.
  static List<TaskRelationRow> _relationRows(
    Task task,
    RelationChange? inverse,
    RelationChange? own,
  ) {
    if (inverse == null && own == null) return taskRelationRows(task);
    var refs = <TaskRelationRef>{
      for (final MapEntry(key: kind, value: others)
          in task.relatedTasks.entries)
        for (final other in others) TaskRelationRef(kind, other.id),
    };
    if (inverse != null) refs = inverse.applyTo(refs);
    if (own != null) refs = own.applyTo(refs);
    return [
      for (final ref in refs)
        TaskRelationRow(
          taskId: task.id,
          otherTaskId: ref.otherTaskId,
          kind: ref.kind.wireName,
        ),
    ];
  }

  /// The edges other local tasks hold to the [pulled] tasks made the
  /// inverse of [pulledRows], with those tasks' own queued changes to them
  /// on top. The server bumps `updated` only on the task a relation was
  /// added to or removed from, so the other task is not pulled along.
  /// Tasks pulled in the same batch have their rows from their own pull.
  Future<void> _matchInverseRows(
    Set<int> pulled,
    List<TaskRelationRow> pulledRows,
    Map<int, RelationChange> queuedRelations,
  ) async {
    if (pulled.isEmpty) return;
    final pointing = selectOnly(taskRelations, distinct: true)
      ..addColumns([taskRelations.taskId])
      ..where(taskRelations.otherTaskId.isIn(pulled));
    final others = {
      ...await _existingTaskIds({
        for (final row in pulledRows) row.otherTaskId,
      }),
      for (final row in await pointing.get()) row.read(taskRelations.taskId)!,
    }.difference(pulled);
    if (others.isEmpty) return;
    final edges = <int, Set<TaskRelationRef>>{for (final id in others) id: {}};
    for (final row in pulledRows) {
      final kind = TaskRelationKind.fromWire(row.kind);
      if (kind == null || !others.contains(row.otherTaskId)) continue;
      edges[row.otherTaskId]!.add(
        TaskRelationRef(inverseRelationKind(kind), row.taskId),
      );
    }
    final wanted = [
      for (final MapEntry(key: id, value: refs) in edges.entries)
        for (final ref in queuedRelations[id]?.applyTo(refs) ?? refs)
          if (pulled.contains(ref.otherTaskId))
            TaskRelationRow(
              taskId: id,
              otherTaskId: ref.otherTaskId,
              kind: ref.kind.wireName,
            ),
    ];
    final stored = await (select(
      taskRelations,
    )..where((r) => r.taskId.isIn(others) & r.otherTaskId.isIn(pulled))).get();
    final stale = stored.toSet().difference(wanted.toSet());
    // An edge that stays keeps its row, and with it its place among the
    // other task's relations.
    await batch((b) {
      for (final row in stale) {
        b.deleteWhere(
          taskRelations,
          (r) =>
              r.taskId.equals(row.taskId) &
              r.otherTaskId.equals(row.otherTaskId) &
              r.kind.equals(row.kind),
        );
      }
      b.insertAll(taskRelations, wanted, mode: InsertMode.insertOrIgnore);
    });
  }

  /// The queued relation change of every task that has one.
  Future<Map<int, RelationChange>> _queuedRelationChanges() async {
    // The outbox is small and usually holds no relation change; the tasks
    // table may be large and has no index on pending_changes.
    final outbox = attachedDatabase.outbox;
    final queued =
        await (selectOnly(outbox)
              ..addColumns([outbox.id])
              ..where(outbox.payload.like('%"relations"%'))
              ..limit(1))
            .getSingleOrNull();
    if (queued == null) return const {};
    final rows = await (select(
      tasks,
    )..where((t) => t.pendingChanges.like('%"relations"%'))).get();
    return {
      for (final row in rows)
        row.id: ?decodeTaskChanges(row.pendingChanges!).relations,
    };
  }

  /// Per task among [ids], the inverse of the relation changes other tasks
  /// still have queued that name it.
  static Map<int, RelationChange> _inverseEdgesOn(
    Set<int> ids,
    Map<int, RelationChange> queuedRelations,
  ) {
    final added = <int, Set<TaskRelationRef>>{};
    final removed = <int, Set<TaskRelationRef>>{};
    void collect(
      Map<int, Set<TaskRelationRef>> into,
      Iterable<TaskRelationRef> refs,
      int from,
    ) {
      for (final ref in refs) {
        if (ref.otherTaskId == from || !ids.contains(ref.otherTaskId)) {
          continue;
        }
        into
            .putIfAbsent(ref.otherTaskId, () => {})
            .add(TaskRelationRef(inverseRelationKind(ref.kind), from));
      }
    }

    for (final MapEntry(key: from, value: relations)
        in queuedRelations.entries) {
      collect(added, relations.added, from);
      collect(removed, relations.removed, from);
    }
    return {
      for (final id in {...added.keys, ...removed.keys})
        id: RelationChange(
          added: added[id] ?? const {},
          removed: removed[id] ?? const {},
        ),
    };
  }

  Future<Set<int>> _existingTaskIds(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final query = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.id.isIn(ids));
    return {for (final row in await query.get()) row.read(tasks.id)!};
  }

  /// Removes every task that [syncRunId] did not return, see [_purge].
  Future<int> purgeNotInRun(String syncRunId) => transaction(
    () async => await _purge(
      await _ids(
        (tasks.syncRunId.isNull() | tasks.syncRunId.equals(syncRunId).not()) &
            _purgeable,
      ),
    ),
  );

  Future<void> deleteRow(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// The rows among [ids] that carry a queued op.
  Future<Map<int, TaskRow>> _queuedRows(List<int> ids) async {
    final rows = await (select(
      tasks,
    )..where((t) => t.id.isIn(ids) & _purgeable.not())).get();
    return {for (final row in rows) row.id: row};
  }

  Future<Set<int>> _existingLabelIds(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final query = selectOnly(labels)
      ..addColumns([labels.id])
      ..where(labels.id.isIn(ids));
    return {for (final row in await query.get()) row.read(labels.id)!};
  }

  Future<Set<int>> _existingUserIds(Set<int> ids) async {
    if (ids.isEmpty) return const {};
    final query = selectOnly(users)
      ..addColumns([users.id])
      ..where(users.id.isIn(ids));
    return {for (final row in await query.get()) row.read(users.id)!};
  }

  static Iterable<int> _applied(IdSetChange? change, Iterable<int> current) =>
      change?.applyTo(current) ?? current;

  /// [current] with the relative instants computed from [row]'s dates when
  /// [changes] set the list or a date; otherwise as it is.
  static List<TaskReminder> _remindersFor(
    TaskRow row,
    TaskChanges changes, {
    required List<TaskReminder> current,
  }) => changes.reminders != null || changesDates(changes)
      ? withLocalInstants(
          current,
          dueDate: row.dueDate,
          startDate: row.startDate,
          endDate: row.endDate,
        )
      : current;

  /// [incoming] with the queued fields of [local] on top; a queued done
  /// keeps the moment it was done here.
  static TaskRow _keepQueued(TaskRow incoming, TaskRow local) {
    final row = incoming.copyWith(
      pendingChanges: Value(local.pendingChanges),
      pendingDelete: local.pendingDelete,
    );
    return switch (local.pendingChanges) {
      final json? => applyTaskChanges(
        row,
        decodeTaskChanges(json),
        now: local.doneAt ?? DateTime.timestamp(),
      ),
      null => row,
    };
  }

  Future<List<Task>> _load({
    required Expression<bool> where,
    required List<OrderingTerm> orderBy,
  }) async {
    final query = select(tasks).join([
      leftOuterJoin(users, users.id.equalsExp(tasks.createdById)),
    ])..where(where);
    if (orderBy.isNotEmpty) query.orderBy(orderBy);
    final rows = await query.get();
    return await _hydrate([
      for (final row in rows)
        (task: row.readTable(tasks), createdBy: row.readTableOrNull(users)),
    ]);
  }

  /// Four batched queries per list instead of four per task.
  Future<List<Task>> _hydrate(List<_TaskRows> rows) async {
    if (rows.isEmpty) return const [];
    final labelsByTask = <int, List<Label>>{};
    final assigneesByTask = <int, List<User>>{};
    final remindersByTask = <int, List<TaskReminder>>{};
    final relatedByTask = <int, Map<TaskRelationKind, List<Task>>>{};
    final ids = [for (final row in rows) row.task.id];
    for (var start = 0; start < ids.length; start += _chunkSize) {
      final chunk = ids.sublist(
        start,
        (start + _chunkSize).clamp(0, ids.length),
      );
      await _loadLabels(chunk, labelsByTask);
      await _loadAssignees(chunk, assigneesByTask);
      await _loadReminders(chunk, remindersByTask);
      await _loadRelations(chunk, relatedByTask);
    }
    return [
      for (final (:task, :createdBy) in rows)
        taskFromRow(
          task,
          createdBy: createdBy == null ? null : userFromRow(createdBy),
          labels: labelsByTask[task.id] ?? const [],
          assignees: assigneesByTask[task.id] ?? const [],
          reminders: remindersByTask[task.id] ?? const [],
          relatedTasks: relatedByTask[task.id] ?? const {},
        ),
    ];
  }

  Future<void> _loadLabels(List<int> ids, Map<int, List<Label>> into) async {
    final query =
        select(taskLabels).join([
            innerJoin(labels, labels.id.equalsExp(taskLabels.labelId)),
            leftOuterJoin(users, users.id.equalsExp(labels.createdById)),
          ])
          ..where(taskLabels.taskId.isIn(ids))
          ..orderBy([OrderingTerm.asc(labels.id)]);
    for (final row in await query.get()) {
      into
          .putIfAbsent(row.readTable(taskLabels).taskId, () => [])
          .add(
            labelFromRow(
              row.readTable(labels),
              createdBy: switch (row.readTableOrNull(users)) {
                final user? => userFromRow(user),
                null => null,
              },
            ),
          );
    }
  }

  Future<void> _loadAssignees(List<int> ids, Map<int, List<User>> into) async {
    final query =
        select(taskAssignees)
            .join([innerJoin(users, users.id.equalsExp(taskAssignees.userId))])
          ..where(taskAssignees.taskId.isIn(ids))
          ..orderBy([OrderingTerm.asc(users.id)]);
    for (final row in await query.get()) {
      into
          .putIfAbsent(row.readTable(taskAssignees).taskId, () => [])
          .add(userFromRow(row.readTable(users)));
    }
  }

  Future<void> _loadReminders(
    List<int> ids,
    Map<int, List<TaskReminder>> into,
  ) async {
    final query = select(taskReminders)
      ..where((r) => r.taskId.isIn(ids))
      ..orderBy([(r) => OrderingTerm.asc(r.ordinal)]);
    for (final row in await query.get()) {
      into.putIfAbsent(row.taskId, () => []).add(reminderFromRow(row));
    }
  }

  /// Only relations whose other task is local and not queued for deletion;
  /// the nested task carries no labels, assignees, reminders or relations
  /// of its own. In the order the edges were stored, which is the server's
  /// order for a pulled task: the web nests subtasks in that order.
  Future<void> _loadRelations(
    List<int> ids,
    Map<int, Map<TaskRelationKind, List<Task>>> into,
  ) async {
    final query =
        select(taskRelations).join([
            innerJoin(tasks, tasks.id.equalsExp(taskRelations.otherTaskId)),
          ])
          ..where(taskRelations.taskId.isIn(ids) & _visible)
          ..orderBy([OrderingTerm.asc(taskRelations.rowId)]);
    for (final row in await query.get()) {
      final relation = row.readTable(taskRelations);
      final kind = TaskRelationKind.fromWire(relation.kind);
      if (kind == null) continue;
      into
          .putIfAbsent(relation.taskId, () => {})
          .putIfAbsent(kind, () => [])
          .add(taskFromRow(row.readTable(tasks)));
    }
  }
}
