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

  /// Every task, done ones included, without labels, assignees, reminders
  /// or relations: enough to search titles and identifiers.
  Stream<List<Task>> watchSearchableTasks();

  Future<void> refreshOpenTasks();

  Future<void> refreshProjectTasks(int projectId, {required bool showDone});

  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone});

  /// Writes apply to the local row at once and are queued for the server;
  /// they never throw for network reasons. [setDone] on a repeating task
  /// shows it done until the server answers with the next occurrence.
  /// The task as this device knows it, following it across the id change
  /// a queued create gets once the server has assigned the real id. Emits
  /// null once the task is gone.
  Stream<Task?> watchTask(int taskId);

  /// Creates the task locally at once under a temporary negative id and
  /// queues the server create; returns that local id.
  Future<int> createTask(NewTask task);

  /// Applies the fields set in [changes] at once and queues them.
  Future<void> updateTask(int taskId, TaskChanges changes);

  Future<void> setDone(int taskId, {required bool done});

  /// Takes back a done of [previous], which may already have been answered:
  /// a repeating task gets the dates it had before the server moved them on.
  Future<void> undoDone(Task previous);

  Future<void> setFavorite(int taskId, {required bool favorite});

  /// Hides the task at once; the server delete follows. A task the server
  /// already deleted counts as success.
  Future<void> deleteTask(int taskId);

  /// Asks the server for a copy (labels, assignees, attachments and
  /// reminders included, plus a `copiedfrom` relation), so it needs a
  /// connection and the task's queued changes sent first; stores the copy
  /// and returns its id. Throws the `VikunjaFailure`; while the task's
  /// changes cannot be sent, the one the queue waits out (offline a
  /// `NetworkFailure`), else [TaskNotSyncedYet].
  Future<int> duplicateTask(int taskId);

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

/// The task has changes this device could not send yet (its create, or a
/// change the server refused), and the action needs the task as the
/// server has it: available once they are synced.
final class TaskNotSyncedYet implements Exception {
  const new(this.taskId);

  final int taskId;

  @override
  String toString() => 'TaskNotSyncedYet($taskId)';
}
