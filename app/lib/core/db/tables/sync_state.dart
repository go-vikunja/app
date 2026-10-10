import 'package:drift/drift.dart';

/// Key/value state of the sync engine: the checkpoint of the current run and
/// when the last run completed. See `SyncStateKeys`.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
