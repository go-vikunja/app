import 'package:drift/drift.dart';
import 'package:vikunja_mobile/core/db/epoch_millis.dart';

@DataClassName('LabelRow')
class Labels extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get hexColor => text()();
  IntColumn get createdById => integer().nullable()();
  IntColumn get created => integer().map(const EpochMillis()).nullable()();
  IntColumn get updated => integer().map(const EpochMillis()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
