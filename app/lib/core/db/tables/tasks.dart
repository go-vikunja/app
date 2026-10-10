import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/labels.dart';
import 'package:vikunja_mobile/core/db/tables/users.dart';

@DataClassName('TaskRow')
@TableIndex(name: 'tasks_project', columns: {#projectId})
@TableIndex(name: 'tasks_done_due', columns: {#done, #dueDate})
class Tasks extends Table {
  IntColumn get id => integer()();

  // No foreign key: a task can arrive before its project is known locally
  // (a project created while a sync runs), and the purge keeps them in step.
  IntColumn get projectId => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  BoolColumn get done => boolean()();
  IntColumn get doneAt => integer().map(const EpochMillis()).nullable()();
  IntColumn get dueDate => integer().map(const EpochMillis()).nullable()();
  IntColumn get startDate => integer().map(const EpochMillis()).nullable()();
  IntColumn get endDate => integer().map(const EpochMillis()).nullable()();
  IntColumn get priority => integer()();
  RealColumn get percentDone => real()();
  TextColumn get hexColor => text()();
  TextColumn get identifier => text()();
  IntColumn get taskIndex => integer().named('index')();
  BoolColumn get isFavorite => boolean()();
  RealColumn get position => real()();

  /// Seconds.
  IntColumn get repeatAfter => integer()();
  IntColumn get repeatMode => integer()();
  IntColumn get bucketId => integer()();
  IntColumn get createdById => integer().nullable()();
  IntColumn get created => integer().map(const EpochMillis()).nullable()();
  IntColumn get updated => integer().map(const EpochMillis()).nullable()();

  /// The sync run that last returned this task; the finishing phase purges
  /// every task the run did not touch. Survives a restart, unlike a set of
  /// seen ids in memory.
  TextColumn get syncRunId => text().nullable()();

  /// The merged `TaskChanges` of this task's unsent outbox ops as JSON; the
  /// sync's upserts keep these fields. Null once everything is sent.
  TextColumn get pendingChanges => text().nullable()();

  /// A queued delete: the row is hidden from every query and count until
  /// the server confirms.
  BoolColumn get pendingDelete =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The primary key doubles as the `task_id` index.
@DataClassName('TaskLabelRow')
class TaskLabels extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get labelId =>
      integer().references(Labels, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {taskId, labelId};
}

@DataClassName('TaskAssigneeRow')
class TaskAssignees extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {taskId, userId};
}

/// Reminders have no server id and may repeat, so their position in the
/// task's list is the key.
@DataClassName('TaskReminderRow')
class TaskReminders extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get ordinal => integer()();
  IntColumn get reminder => integer().map(const EpochMillis()).nullable()();

  /// Seconds, negative before the referenced date.
  IntColumn get relativePeriod => integer()();

  /// `ReminderRelativeTo.wireName`, null for an absolute reminder.
  TextColumn get relativeTo => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, ordinal};
}

/// Only the edge; the other task is looked up locally when the entity is
/// built. No foreign key on `other_task_id`, because the other task may be
/// one the user cannot read.
@DataClassName('TaskRelationRow')
class TaskRelations extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get otherTaskId => integer()();

  /// `TaskRelationKind.wireName`.
  TextColumn get kind => text()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, otherTaskId, kind};
}
