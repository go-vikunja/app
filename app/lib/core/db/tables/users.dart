import 'package:drift/drift.dart';

/// Every user seen as an owner, creator or assignee. Never purged: the rows
/// are a cache for display only.
@DataClassName('UserRow')
class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get username => text()();
  TextColumn get name => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
