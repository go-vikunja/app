// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects_dao.dart';

// ignore_for_file: type=lint
mixin _$ProjectsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $ProjectViewsTable get projectViews => attachedDatabase.projectViews;
  $UsersTable get users => attachedDatabase.users;
  ProjectsDaoManager get managers => ProjectsDaoManager(this);
}

class ProjectsDaoManager {
  final _$ProjectsDaoMixin _db;
  ProjectsDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$ProjectViewsTableTableManager get projectViews =>
      $$ProjectViewsTableTableManager(_db.attachedDatabase, _db.projectViews);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
}
