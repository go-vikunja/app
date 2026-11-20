import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/db/daos/tasks_dao.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

/// The sync that follows a write that already stands: its failure is only
/// logged. [refresh] starts before the first await, so callers that do not
/// wait still start it in order.
Future<void> refreshQuietly(
  Future<void> Function() refresh,
  Logger log,
  String after,
) async {
  try {
    await refresh();
  } on Object catch (error) {
    log.fine('Sync after $after failed: ${error.runtimeType}');
  }
}

String checkedTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) throw ArgumentError.value(title, 'title');
  return trimmed;
}

/// Lives here, not in [TasksDao]: the database layer does not know the
/// repositories' exceptions.
Future<int> serverTaskId(TasksDao tasks, int taskId) async {
  final id = await tasks.resolveId(taskId);
  if (id < 0) throw TaskNotSyncedYet(taskId);
  return id;
}
