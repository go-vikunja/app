import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/label_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/task_mappers.dart';
import 'package:vikunja_mobile/core/db/mappers/user_mappers.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';
import 'package:vikunja_mobile/core/db/watch_tables.dart';

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

  /// Open tasks across all projects: nearest due date first, tasks without
  /// one last, newest first within a date.
  Stream<List<Task>> watchOpenTasks() =>
      watchTables(_readTables, loadOpenTasks);

  Future<List<Task>> loadOpenTasks() => _load(
    where: tasks.done.equals(false),
    orderBy: [
      OrderingTerm.asc(tasks.dueDate, nulls: NullsOrder.last),
      OrderingTerm.desc(tasks.id),
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
        ? tasks.projectId.equals(projectId)
        : tasks.projectId.equals(projectId) & tasks.done.equals(false),
    orderBy: [OrderingTerm.asc(tasks.position), OrderingTerm.desc(tasks.id)],
  );

  Future<Task?> find(int id) async {
    final found = await _load(where: tasks.id.equals(id), orderBy: const []);
    return found.singleOrNull;
  }

  Future<int> count() {
    final count = tasks.id.count();
    final query = selectOnly(tasks)..addColumns([count]);
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Upserts the tasks with the users and labels they carry, replacing their
  /// labels, assignees, reminders and relations; marks them seen in
  /// [syncRunId].
  Future<void> upsertAll(List<Task> all, {required String syncRunId}) {
    final ids = [for (final task in all) task.id];
    return batch((b) {
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
        ..insertAllOnConflictUpdate(tasks, [
          for (final task in all)
            taskRow(task, syncRunId: syncRunId).toCompanion(false),
        ])
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
            (t) => t.syncRunId.isNull() | t.syncRunId.equals(syncRunId).not(),
          ))
          .go();

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
