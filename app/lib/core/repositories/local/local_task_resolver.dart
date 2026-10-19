import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver.dart';

final _digitsOnly = RegExp(r'^\d+$');

/// A task the database does not have is read online and stored without a
/// sync run, like a duplicate: the next full sync keeps it when the user
/// can still see it and purges it otherwise.
final class LocalTaskResolver implements TaskResolver {
  new(this._db, this._read);

  final AppDatabase _db;
  final VikunjaReadClient _read;

  @override
  Future<Task> resolve(TaskReference reference) async {
    switch (reference) {
      case TaskById(:final id):
        final local = await _db.tasksDao.find(await _db.tasksDao.resolveId(id));
        if (local != null) return local;
        return await _store(await _read.tasks.read(id));
      case TaskByIdentifier(:final identifier, :final index):
        final local = await _db.tasksDao.findByIdentifier(identifier, index);
        if (local?.task case final task?) return task;
        if (local != null) {
          return await _store(
            await _read.tasks.readByIndex('${local.projectId}', index),
          );
        }
        // The server reads a segment of digits as a project id, so a
        // project with such an identifier is reachable only by its id.
        if (_digitsOnly.hasMatch(identifier)) {
          throw const NotFound(code: 3001);
        }
        return await _store(await _read.tasks.readByIndex(identifier, index));
    }
  }

  @override
  Future<Task?> findLocal(TaskReference reference) async => switch (reference) {
    TaskById(:final id) => await _db.tasksDao.find(
      await _db.tasksDao.resolveId(id),
    ),
    TaskByIdentifier(:final identifier, :final index) =>
      (await _db.tasksDao.findByIdentifier(identifier, index))?.task,
  };

  Future<Task> _store(Task task) async {
    await _db.tasksDao.upsertAll([task]);
    // A row queued for deletion stays hidden through the upsert.
    return await _db.tasksDao.find(task.id) ??
        (throw const NotFound(code: 4002));
  }
}
