// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_snapshots_dao.dart';

// ignore_for_file: type=lint
mixin _$ListSnapshotsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ListSnapshotsTable get listSnapshots => attachedDatabase.listSnapshots;
  $ListSnapshotTasksTable get listSnapshotTasks =>
      attachedDatabase.listSnapshotTasks;
  ListSnapshotsDaoManager get managers => ListSnapshotsDaoManager(this);
}

class ListSnapshotsDaoManager {
  final _$ListSnapshotsDaoMixin _db;
  ListSnapshotsDaoManager(this._db);
  $$ListSnapshotsTableTableManager get listSnapshots =>
      $$ListSnapshotsTableTableManager(_db.attachedDatabase, _db.listSnapshots);
  $$ListSnapshotTasksTableTableManager get listSnapshotTasks =>
      $$ListSnapshotTasksTableTableManager(
        _db.attachedDatabase,
        _db.listSnapshotTasks,
      );
}
