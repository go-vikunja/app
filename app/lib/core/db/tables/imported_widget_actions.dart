import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

/// The widget Done taps already applied, by the id their widget gave them:
/// the import records one in the transaction that queues its Done, so a
/// tap whose file outlives the commit (the app killed before it was
/// deleted) is never applied twice, which would move a repeating task
/// twice.
@DataClassName('ImportedWidgetActionRow')
class ImportedWidgetActions extends Table {
  TextColumn get id => text()();
  IntColumn get importedAt => integer().map(const EpochMillis())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
