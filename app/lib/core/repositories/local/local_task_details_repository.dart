import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

/// The details straight from the server, addressed by the task's server
/// id: a task created here once its create was answered, before that
/// [TaskNotSyncedYet] without a request.
final class LocalTaskDetailsRepository implements TaskDetailsRepository {
  new(this._db, this._read, this._write);

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;

  @override
  Future<TaskDetails> details(int taskId) async =>
      await _read.tasks.readDetails(await _serverId(taskId));

  @override
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  }) async {
    final comments = await _read.comments.list(
      await _serverId(taskId),
      page: page,
      newestFirst: newestFirst,
    );
    final sorted = [...comments.items]..sort(_oldestFirst);
    return Page(
      items: List.unmodifiable(newestFirst ? sorted.reversed : sorted),
      page: comments.page,
      perPage: comments.perPage,
      totalPages: comments.totalPages,
      total: comments.total,
    );
  }

  @override
  Future<void> markRead(int taskId) async {
    await _write.tasks.markRead(await _serverId(taskId));
  }

  Future<int> _serverId(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    if (id < 0) throw TaskNotSyncedYet(taskId);
    return id;
  }

  // The server keeps `created` to the second, so ties are common.
  static int _oldestFirst(TaskComment a, TaskComment b) {
    final byCreated = (a.created?.millisecondsSinceEpoch ?? 0).compareTo(
      b.created?.millisecondsSinceEpoch ?? 0,
    );
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }
}
