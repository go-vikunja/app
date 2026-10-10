import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

/// Tasks from the account's database. The whole account is local, so a
/// project list is never paged and every refresh is a full sync run.
final class LocalTaskRepository implements TaskRepository {
  new(this._db, this._sync);

  final AppDatabase _db;
  final SyncEngine _sync;

  @override
  Stream<List<Task>> watchOpenTasks() => _db.tasksDao.watchOpenTasks();

  @override
  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  }) => _db.tasksDao
      .watchProjectTasks(projectId, showDone: showDone)
      .map((tasks) => PagedList(items: tasks, hasMore: false));

  @override
  Future<void> refreshOpenTasks() => _sync.refresh();

  @override
  Future<void> refreshProjectTasks(int projectId, {required bool showDone}) =>
      _sync.refresh();

  @override
  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone}) =>
      Future.value();

  @override
  void dispose() {}
}
