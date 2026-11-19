// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_ops_dao.dart';

// ignore_for_file: type=lint
mixin _$LabelOpsDaoMixin on DatabaseAccessor<AppDatabase> {
  $OutboxTable get outbox => attachedDatabase.outbox;
  $LabelsTable get labels => attachedDatabase.labels;
  $UsersTable get users => attachedDatabase.users;
  $LabelIdRemapsTable get labelIdRemaps => attachedDatabase.labelIdRemaps;
  $SyncStateTable get syncState => attachedDatabase.syncState;
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskLabelsTable get taskLabels => attachedDatabase.taskLabels;
  LabelOpsDaoManager get managers => LabelOpsDaoManager(this);
}

class LabelOpsDaoManager {
  final _$LabelOpsDaoMixin _db;
  LabelOpsDaoManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db.attachedDatabase, _db.outbox);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db.attachedDatabase, _db.labels);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$LabelIdRemapsTableTableManager get labelIdRemaps =>
      $$LabelIdRemapsTableTableManager(_db.attachedDatabase, _db.labelIdRemaps);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db.attachedDatabase, _db.syncState);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskLabelsTableTableManager get taskLabels =>
      $$TaskLabelsTableTableManager(_db.attachedDatabase, _db.taskLabels);
}
