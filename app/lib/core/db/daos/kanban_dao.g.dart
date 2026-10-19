// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kanban_dao.dart';

// ignore_for_file: type=lint
mixin _$KanbanDaoMixin on DatabaseAccessor<AppDatabase> {
  $KanbanBucketsTable get kanbanBuckets => attachedDatabase.kanbanBuckets;
  $ListSnapshotsTable get listSnapshots => attachedDatabase.listSnapshots;
  $ListSnapshotTasksTable get listSnapshotTasks =>
      attachedDatabase.listSnapshotTasks;
  $ProjectsTable get projects => attachedDatabase.projects;
  $ProjectViewsTable get projectViews => attachedDatabase.projectViews;
  KanbanDaoManager get managers => KanbanDaoManager(this);
}

class KanbanDaoManager {
  final _$KanbanDaoMixin _db;
  KanbanDaoManager(this._db);
  $$KanbanBucketsTableTableManager get kanbanBuckets =>
      $$KanbanBucketsTableTableManager(_db.attachedDatabase, _db.kanbanBuckets);
  $$ListSnapshotsTableTableManager get listSnapshots =>
      $$ListSnapshotsTableTableManager(_db.attachedDatabase, _db.listSnapshots);
  $$ListSnapshotTasksTableTableManager get listSnapshotTasks =>
      $$ListSnapshotTasksTableTableManager(
        _db.attachedDatabase,
        _db.listSnapshotTasks,
      );
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$ProjectViewsTableTableManager get projectViews =>
      $$ProjectViewsTableTableManager(_db.attachedDatabase, _db.projectViews);
}
