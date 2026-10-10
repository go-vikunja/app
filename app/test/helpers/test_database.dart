import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

/// An in-memory database, closed when the test ends.
AppDatabase testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}
