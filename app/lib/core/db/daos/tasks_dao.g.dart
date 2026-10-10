// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_dao.dart';

// ignore_for_file: type=lint
mixin _$TasksDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $LabelsTable get labels => attachedDatabase.labels;
  $TaskLabelsTable get taskLabels => attachedDatabase.taskLabels;
  $UsersTable get users => attachedDatabase.users;
  $TaskAssigneesTable get taskAssignees => attachedDatabase.taskAssignees;
  $TaskRemindersTable get taskReminders => attachedDatabase.taskReminders;
  $TaskRelationsTable get taskRelations => attachedDatabase.taskRelations;
  $TaskIdRemapsTable get taskIdRemaps => attachedDatabase.taskIdRemaps;
  TasksDaoManager get managers => TasksDaoManager(this);
}

class TasksDaoManager {
  final _$TasksDaoMixin _db;
  TasksDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db.attachedDatabase, _db.labels);
  $$TaskLabelsTableTableManager get taskLabels =>
      $$TaskLabelsTableTableManager(_db.attachedDatabase, _db.taskLabels);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$TaskAssigneesTableTableManager get taskAssignees =>
      $$TaskAssigneesTableTableManager(_db.attachedDatabase, _db.taskAssignees);
  $$TaskRemindersTableTableManager get taskReminders =>
      $$TaskRemindersTableTableManager(_db.attachedDatabase, _db.taskReminders);
  $$TaskRelationsTableTableManager get taskRelations =>
      $$TaskRelationsTableTableManager(_db.attachedDatabase, _db.taskRelations);
  $$TaskIdRemapsTableTableManager get taskIdRemaps =>
      $$TaskIdRemapsTableTableManager(_db.attachedDatabase, _db.taskIdRemaps);
}
