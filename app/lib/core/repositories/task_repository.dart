import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

/// Tasks as this device knows them; the same stream and error rules as
/// `ProjectRepository`.
abstract interface class TaskRepository {
  /// Open tasks across all projects, nearest due date first.
  Stream<List<Task>> watchOpenTasks();

  /// Every task, done ones included, without labels, assignees, reminders
  /// or relations: enough to search titles and identifiers.
  Stream<List<Task>> watchSearchableTasks();

  /// Open tasks outside archived projects and their subprojects, nearest
  /// due date first (none last), then newest first: Upcoming's source.
  Stream<List<Task>> watchActiveOpenTasks();

  /// [watchActiveOpenTasks], or the open tasks of the saved filter the user
  /// picked for the Overview on the web, as of its last download (the sync
  /// downloads it each run) with this device's changes on top: a task done
  /// or deleted here leaves at once, a task created here appears after the
  /// next download.
  Stream<OverviewTasks> watchOverviewTasks();

  /// What a project's list view is built from; [viewId] 0 stands for a
  /// project without a list view. Without [includeDone] the project's done
  /// tasks are left out unless the view's last download has them (as
  /// subtasks they still come along), for a view that would not show them:
  /// a long-lived project holds far more done tasks than open ones.
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
  });

  /// Runs the sync and downloads the view's tasks and their positions.
  /// Throws the `VikunjaFailure` of the download; a [viewId] of 0 only
  /// syncs.
  Future<void> refreshProjectList(int projectId, {required int viewId});

  /// What a kanban view's board is built from.
  Stream<BoardSource> watchBoard(int projectId, int viewId);

  /// Runs the sync, then downloads the board: every bucket with its first
  /// page of cards, and again each further page loaded before. Throws the
  /// `VikunjaFailure` of the download and keeps the previous board then.
  Future<void> refreshBoard(int projectId, int viewId);

  /// Downloads the next page of one bucket's cards and adds it to the
  /// board; online only, throws the `VikunjaFailure`.
  Future<void> loadMoreOfBucket(int projectId, int viewId, int bucketId);

  /// Queues the task's [placement] on the view, with [done] when the move
  /// changes it (into or out of the done bucket); like the other writes,
  /// it applies at once.
  Future<void> placeTask(
    int taskId, {
    required int viewId,
    required BucketPlacement placement,
    bool? done,
  });

  /// Queues the task's [position] in a list view sorted manually; like the
  /// other writes, it applies at once (as the list source's queued
  /// positions until sent).
  Future<void> positionTask(
    int taskId, {
    required int viewId,
    required double position,
  });

  /// The open tasks marked as favourite, outside archived projects, nearest
  /// due date first (none last), then newest first: the Favorites list.
  Stream<List<Task>> watchFavoriteTasks();

  /// A saved filter's list ([pseudoProjectId] is -2 or lower).
  Stream<SavedFilterTasks> watchSavedFilterTasks(int pseudoProjectId);

  /// Runs the sync and downloads the saved filter's open tasks; throws the
  /// `VikunjaFailure` of the download.
  Future<void> refreshSavedFilter(int pseudoProjectId);

  Future<void> refreshOpenTasks();

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
