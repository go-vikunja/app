import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';

/// Tasks as this device knows them; the same stream and error rules as
/// `ProjectRepository`. Project tasks are paged: [loadMoreProjectTasks]
/// appends the next page and throws on failure.
abstract interface class TaskRepository {
  /// Open tasks across all projects, nearest due date first.
  Stream<List<Task>> watchOpenTasks();

  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  });

  Future<void> refreshOpenTasks();

  Future<void> refreshProjectTasks(int projectId, {required bool showDone});

  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone});

  /// Writes apply to the local row at once and are queued for the server;
  /// they never throw for network reasons. [setDone] on a repeating task
  /// shows it done until the server answers with the next occurrence.
  Future<void> setDone(int taskId, {required bool done});

  /// Takes back a done of [previous], which may already have been answered:
  /// a repeating task gets the dates it had before the server moved them on.
  Future<void> undoDone(Task previous);

  Future<void> setFavorite(int taskId, {required bool favorite});

  /// Hides the task at once; the server delete follows. A task the server
  /// already deleted counts as success.
  Future<void> deleteTask(int taskId);

  /// Queued changes not yet accepted by the server, failed ones included.
  Stream<int> watchPendingChanges();

  Stream<List<SyncProblem>> watchSyncProblems();

  Future<void> retrySyncProblem(String operationId);

  /// Drops the queued change and restores the row from the server. Throws
  /// the `VikunjaFailure` of that read and changes nothing then.
  Future<void> discardSyncProblem(String operationId);

  /// "Send now": drains the queue at once, backoffs included. Returns the
  /// failure the oldest change still waits out afterwards, null when the
  /// queue was sent or holds only sync problems.
  Future<VikunjaFailure?> sendPendingChanges();

  void dispose();
}
