import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// Real projects only; of the pseudo projects (Favorites, saved filters)
/// only the saved filters' names are kept, in `sync_state`.
@DataClassName('ProjectRow')
class Projects extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get identifier => text()();
  TextColumn get hexColor => text()();
  IntColumn get parentProjectId => integer()();
  BoolColumn get isArchived => boolean()();
  BoolColumn get isFavorite => boolean()();
  RealColumn get position => real()();
  IntColumn get ownerId => integer().nullable()();
  IntColumn get created => integer().map(const EpochMillis()).nullable()();
  IntColumn get updated => integer().map(const EpochMillis()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProjectViewRow')
@TableIndex(name: 'project_views_project', columns: {#projectId})
class ProjectViews extends Table {
  IntColumn get id => integer()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// `ProjectViewKind.wireName`.
  TextColumn get kind => text()();
  RealColumn get position => real()();

  /// The view's `ViewFilter` as the server's JSON, null for none.
  TextColumn get filterJson => text().nullable()();

  /// `BucketConfigurationMode.wireName`.
  TextColumn get bucketConfigurationMode => text()();
  IntColumn get defaultBucketId => integer()();
  IntColumn get doneBucketId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
