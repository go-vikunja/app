import 'package:drift/drift.dart';

/// The columns of a kanban view as of its last board download, whose cards
/// are the view's `list_snapshot_tasks` rows. No foreign key on `view_id`:
/// a project's views are replaced wholesale on every project write, so the
/// sync's project phase removes the boards of views that are gone instead.
@DataClassName('KanbanBucketRow')
class KanbanBuckets extends Table {
  IntColumn get viewId => integer()();
  IntColumn get bucketId => integer()();
  TextColumn get title => text()();
  IntColumn get taskLimit => integer().named('limit')();

  /// The server's total of cards in the bucket, not only the loaded ones.
  IntColumn get taskCount => integer().named('count')();
  RealColumn get position => real()();

  /// How many pages of the bucket's cards the board holds: what a refresh
  /// downloads again.
  IntColumn get loadedPages => integer()();

  @override
  Set<Column<Object>> get primaryKey => {viewId, bucketId};
}
