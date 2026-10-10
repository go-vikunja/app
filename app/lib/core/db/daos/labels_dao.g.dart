// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'labels_dao.dart';

// ignore_for_file: type=lint
mixin _$LabelsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LabelsTable get labels => attachedDatabase.labels;
  $UsersTable get users => attachedDatabase.users;
  LabelsDaoManager get managers => LabelsDaoManager(this);
}

class LabelsDaoManager {
  final _$LabelsDaoMixin _db;
  LabelsDaoManager(this._db);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db.attachedDatabase, _db.labels);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
}
