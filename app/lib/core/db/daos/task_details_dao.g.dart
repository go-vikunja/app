// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_details_dao.dart';

// ignore_for_file: type=lint
mixin _$TaskDetailsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskDetailLoadsTable get taskDetailLoads => attachedDatabase.taskDetailLoads;
  $TaskAttachmentsTable get taskAttachments => attachedDatabase.taskAttachments;
  $TaskReactionsTable get taskReactions => attachedDatabase.taskReactions;
  $TaskCommentsTable get taskComments => attachedDatabase.taskComments;
  $TaskCommentReactionsTable get taskCommentReactions =>
      attachedDatabase.taskCommentReactions;
  TaskDetailsDaoManager get managers => TaskDetailsDaoManager(this);
}

class TaskDetailsDaoManager {
  final _$TaskDetailsDaoMixin _db;
  TaskDetailsDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskDetailLoadsTableTableManager get taskDetailLoads =>
      $$TaskDetailLoadsTableTableManager(
        _db.attachedDatabase,
        _db.taskDetailLoads,
      );
  $$TaskAttachmentsTableTableManager get taskAttachments =>
      $$TaskAttachmentsTableTableManager(
        _db.attachedDatabase,
        _db.taskAttachments,
      );
  $$TaskReactionsTableTableManager get taskReactions =>
      $$TaskReactionsTableTableManager(_db.attachedDatabase, _db.taskReactions);
  $$TaskCommentsTableTableManager get taskComments =>
      $$TaskCommentsTableTableManager(_db.attachedDatabase, _db.taskComments);
  $$TaskCommentReactionsTableTableManager get taskCommentReactions =>
      $$TaskCommentReactionsTableTableManager(
        _db.attachedDatabase,
        _db.taskCommentReactions,
      );
}
