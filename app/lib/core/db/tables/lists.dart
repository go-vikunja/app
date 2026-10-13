import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// When a list was last downloaded, by list key (`view:<id>` for a project
/// view, `overview:<pseudo project id>` for the Overview's saved filter).
@DataClassName('ListSnapshotRow')
class ListSnapshots extends Table {
  TextColumn get listKey => text()();
  IntColumn get loadedAt => integer().map(const EpochMillis())();

  @override
  Set<Column<Object>> get primaryKey => {listKey};
}

/// The tasks of that download and their positions in the list. No foreign
/// key on `task_id`: the server may list a task this device does not have
/// yet.
@DataClassName('ListSnapshotTaskRow')
class ListSnapshotTasks extends Table {
  TextColumn get listKey => text()();
  IntColumn get taskId => integer()();
  RealColumn get position => real()();

  @override
  Set<Column<Object>> get primaryKey => {listKey, taskId};
}

/// How the user left each list (`ListPreferences`), as JSON per key; part
/// of the account's database, so it goes with the account.
@DataClassName('ListPreferenceRow')
class ListPreferenceEntries extends Table {
  @override
  String get tableName => 'list_preferences';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
