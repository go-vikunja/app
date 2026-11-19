import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';

// What the detail sheet last read from the server beyond the synced row,
// for offline. People are kept by name in each row, not in `users`: every
// task list reads that table, so each details read would reload them all.
// The keys start with `task_id`, so the cascades need no index of their own.

/// When the task's details (attachments, cover, reactions) and comments
/// were last stored; a null time means never.
@DataClassName('TaskDetailLoadRow')
class TaskDetailLoads extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get detailsLoadedAt =>
      integer().map(const EpochMillis()).nullable()();
  IntColumn get commentsLoadedAt =>
      integer().map(const EpochMillis()).nullable()();

  /// 0 for none; may name an attachment that is gone, as on the server.
  IntColumn get coverImageAttachmentId =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {taskId};
}

/// In the server's order ([position]).
@DataClassName('TaskAttachmentRow')
class TaskAttachments extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get id => integer()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get mime => text()();
  IntColumn get size => integer()();
  IntColumn get created => integer().map(const EpochMillis()).nullable()();
  IntColumn get createdById => integer().nullable()();
  TextColumn get createdByUsername => text().nullable()();
  TextColumn get createdByName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, id};
}

/// One row per value and user. [position] runs across the task's values,
/// so reading by it gives back the values and their users in the server's
/// order.
@DataClassName('TaskReactionRow')
class TaskReactions extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get value => text()();
  IntColumn get userId => integer()();
  TextColumn get username => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, position};
}

@DataClassName('TaskCommentRow')
class TaskComments extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get id => integer()();
  TextColumn get html => text()();
  IntColumn get authorId => integer()();
  TextColumn get authorUsername => text()();
  TextColumn get authorName => text()();
  IntColumn get created => integer().map(const EpochMillis()).nullable()();
  IntColumn get updated => integer().map(const EpochMillis()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, id};
}

/// A comment's reactions, kept like [TaskReactions].
@DataClassName('TaskCommentReactionRow')
class TaskCommentReactions extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get commentId => integer()();
  IntColumn get position => integer()();
  TextColumn get value => text()();
  IntColumn get userId => integer()();
  TextColumn get username => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, commentId, position};

  @override
  List<String> get customConstraints => [
    // drift_dev reads only literals here, so no constant can shorten it.
    // ignore: no_adjacent_strings_in_list
    'FOREIGN KEY (task_id, comment_id) REFERENCES task_comments (task_id, id) '
        'ON DELETE CASCADE',
  ];
}
