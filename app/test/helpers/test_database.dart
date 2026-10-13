import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

/// An in-memory database, closed when the test ends.
AppDatabase testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The project's visible tasks, newest first, as its list is built from.
Future<List<Task>> projectTasksIn(
  AppDatabase db,
  int projectId, {
  bool showDone = true,
}) async {
  final source = await db.tasksDao.loadProjectList(projectId, '');
  return [
    for (final task in source.projectTasks)
      if (showDone || !task.done) task,
  ];
}
