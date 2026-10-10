import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/task_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/task_id_remaps.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';
import 'package:vikunja_mobile/core/outbox/task_changes_json.dart';

part 'tasks_dao.g.dart';

typedef _TaskRows = ({TaskRow task, UserRow? createdBy});

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

  Future<List<Task>> loadOpenTasks() => _load(
    where: tasks.done.equals(false) & _visible,
    orderBy: [
      OrderingTerm.asc(tasks.dueDate, nulls: NullsOrder.last),
      ..._newestFirst,
    ],
  );

  /// The web's default order: position, then newest first.
  Stream<List<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  }) => watchTables(
    _readTables,
    () => loadProjectTasks(projectId, showDone: showDone),
  );

  Future<List<Task>> loadProjectTasks(
    int projectId, {
    required bool showDone,
  }) => _load(
    where: showDone
        ? tasks.projectId.equals(projectId) & _visible
        : tasks.projectId.equals(projectId) &
              tasks.done.equals(false) &
              _visible,
    orderBy: [OrderingTerm.asc(tasks.position), ..._newestFirst],
  );

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

  /// The stored row, a task queued for deletion included.
  Future<TaskRow?> findRow(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

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

  Future<int> purgeInProjects(Iterable<int> projectIds) => (delete(
    tasks,
  )..where((t) => t.projectId.isIn(projectIds) & _purgeable)).go();

  /// Removes the tasks of [projectId] whose id is not in [keep]. The ids to
  /// delete are picked locally, so the statements stay small whatever the
  /// size of [keep].
  Future<int> purgeInProjectExcept(int projectId, Set<int> keep) async {
    final candidates = await _ids(
      tasks.projectId.equals(projectId) & _purgeable,
    );
    final gone = [
      for (final id in candidates)
        if (!keep.contains(id)) id,
    ];
    var purged = 0;
    await transaction(() async {
      for (var start = 0; start < gone.length; start += _chunkSize) {
        final chunk = gone.sublist(
          start,
          (start + _chunkSize).clamp(0, gone.length),
        );
        purged += await (delete(tasks)..where((t) => t.id.isIn(chunk))).go();
      }
    });
    return purged;
  }

  /// Upserts the tasks with the users and labels they carry, replacing their
  /// labels, assignees, reminders and relations; marks them seen in
  /// [syncRunId], or leaves the run a row has when null. A row with queued
  /// changes keeps those fields over the incoming values, and a row queued
  /// for deletion stays hidden.
  Future<void> upsertAll(List<Task> all, {String? syncRunId}) async {
    final ids = [for (final task in all) task.id];
    final queued = await _queuedRows(ids);
    TasksCompanion row(Task task) {
      var stored = taskRow(task, syncRunId: syncRunId);
      if (queued[task.id] case final local?) {
        stored = _keepQueued(stored, local);
      }
      final companion = stored.toCompanion(false);
      return syncRunId == null
          ? companion.copyWith(syncRunId: const Value.absent())
          : companion;
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
        ..insertAllOnConflictUpdate(tasks, [for (final task in all) row(task)])
        ..deleteWhere(taskLabels, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskAssignees, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskReminders, (t) => t.taskId.isIn(ids))
        ..deleteWhere(taskRelations, (t) => t.taskId.isIn(ids))
        ..insertAllOnConflictUpdate(taskLabels, [
          for (final task in all) ...taskLabelRows(task),
        ])
        ..insertAllOnConflictUpdate(taskAssignees, [
          for (final task in all) ...taskAssigneeRows(task),
        ])
        ..insertAllOnConflictUpdate(taskReminders, [
          for (final task in all)
            for (final reminder in taskReminderRows(task))
              reminder.toCompanion(false),
        ])
        ..insertAllOnConflictUpdate(taskRelations, [
          for (final task in all) ...taskRelationRows(task),
        ]);
    });
  }

  /// Removes every task that [syncRunId] did not return; their labels,
  /// assignees, reminders and relations go with them.
  Future<int> purgeNotInRun(String syncRunId) =>
      (delete(tasks)..where(
            (t) =>
                (t.syncRunId.isNull() | t.syncRunId.equals(syncRunId).not()) &
                _purgeable,
          ))
          .go();

  Future<void> deleteRow(int id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  /// The rows among [ids] that carry a queued op.
  Future<Map<int, TaskRow>> _queuedRows(List<int> ids) async {
    final rows = await (select(
      tasks,
    )..where((t) => t.id.isIn(ids) & _purgeable.not())).get();
    return {for (final row in rows) row.id: row};
  }

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

  /// Only relations whose other task is local; the nested task carries no
  /// labels, assignees, reminders or relations of its own.
  Future<void> _loadRelations(
    List<int> ids,
    Map<int, Map<TaskRelationKind, List<Task>>> into,
  ) async {
    final query =
        select(taskRelations).join([
            innerJoin(tasks, tasks.id.equalsExp(taskRelations.otherTaskId)),
          ])
          ..where(taskRelations.taskId.isIn(ids))
          ..orderBy([OrderingTerm.asc(tasks.id)]);
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
