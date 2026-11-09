import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';

export 'package:vikunja_mobile/core/outbox/task_deletion.dart';

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
  /// picked for the Overview on the web: evaluated here from its stored
  /// definition, so every change shows at once; while the definition is
  /// unknown or the device cannot evaluate it, as of its last download (the
  /// sync downloads it each run) with a task done or deleted here leaving at
  /// once and one created here appearing after the next download.
  Stream<OverviewTasks> watchOverviewTasks();

  /// What a project's list view is built from; [viewId] 0 stands for a
  /// project without a list view. The view's filter and search are
  /// evaluated here on every change (`ProjectListSource.matchingIds`).
  /// Without [includeDone] the project's done tasks are left out unless the
  /// view's last download has them or its filter matches them (as subtasks
  /// they still come along), for a view that would not show them: a
  /// long-lived project holds far more done tasks than open ones.
  ///
  /// A [request] (a timeline's range) is what a client sends the view's
  /// tasks endpoint: `matchingIds` then holds the tasks the server would
  /// answer, the request's filter ANDed with the view's with include-nulls
  /// if either asks, and is never null; where the device cannot evaluate
  /// the view's filter, the tasks of the view's last download that the
  /// request's filter matches.
  Stream<ProjectListSource> watchProjectList(
    int projectId, {
    required int viewId,
    bool includeDone = true,
    ViewFilter? request,
  });

  /// Runs the sync and downloads the view's tasks and their positions,
  /// for a table or Gantt view only when the device cannot evaluate its
  /// filter. Throws the `VikunjaFailure` of the download; a [viewId] of 0
  /// only syncs.
  Future<void> refreshProjectList(int projectId, {required int viewId});

  /// What a kanban view's board is built from, with its filter evaluated
  /// here (`BoardSource.matchingIds`).
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

  /// How many of the project's own tasks there are and how many are done,
  /// its subprojects' left out.
  Stream<ProjectProgress> watchProjectProgress(int projectId);

  /// By project id, how many open tasks each project holds itself;
  /// projects without any are left out.
  Stream<Map<int, int>> watchOpenTaskCounts();

  /// A saved filter's list ([pseudoProjectId] is -2 or lower): evaluated
  /// here from its stored definition, else its last download.
  Stream<SavedFilterTasks> watchSavedFilterTasks(int pseudoProjectId);

  /// The open tasks with the label [labelId], as a saved filter
  /// `done = false && labels in <id>` lists them: outside archived
  /// projects and favourite ones anywhere, nearest due date first (none
  /// last), then newest first.
  Stream<List<Task>> watchLabelTasks(int labelId);

  /// Runs the sync, which brings a changed definition; a saved filter the
  /// device cannot evaluate is then downloaded. Throws the `VikunjaFailure`
  /// of the download.
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

  /// Queues [html], an edit in the editor that started from the
  /// description [base], as the task's description; nothing when they are
  /// equal or both empty (`''` and the editor's `<p></p>`). When the
  /// server's description is no longer [base] at send time (it changed on
  /// the web), the change fails with `DescriptionConflict` instead of
  /// overwriting it, and waits as a sync problem for [keepMyDescription] or
  /// [useWebDescription]. False when the task is not on this device (or
  /// queued for deletion), so nothing could be queued.
  Future<bool> updateDescription(
    int taskId,
    String html, {
    required String base,
  });

  /// Sets [item], parsed from the description [html], to [checked],
  /// changing only its checkbox, and queues that as a description change.
  /// When the server's description changed meanwhile, the tap is applied
  /// to the server's instead (by the item's `data-task-id`, else its
  /// position and text; dropped when the item is gone). False, with
  /// nothing changed, when the task's description is no longer [html] or
  /// [item] cannot be toggled in it: the view is stale.
  Future<bool> toggleChecklistItem(
    int taskId, {
    required String html,
    required RichTaskItem item,
    required bool checked,
  });

  Future<void> setDone(int taskId, {required bool done});

  /// Takes back a done of [previous], which may already have been answered:
  /// a repeating task gets the dates it had before the server moved them on.
  Future<void> undoDone(Task previous);

  Future<void> setFavorite(int taskId, {required bool favorite});

  /// Hides the task at once and queues its delete behind the task's own
  /// queued changes, which stay: they reach the server first, so a restore
  /// from the server's trash has them. A create that never reached the
  /// server goes together with its delete once the sender gets to it,
  /// without a request. A task the server already deleted counts as
  /// success.
  Future<TaskDeletion> deleteTask(int taskId);

  /// Takes a delete back and returns the task as it is now. A delete still
  /// queued here, one the server refused included, is removed: the task
  /// shows again with its queued changes, without a request. A delete on
  /// its way is waited for. A delete the server has made is restored from
  /// its trash (Vikunja 2.8.0 and later), and the answered task is stored
  /// at once; ops of the task the server refused because the task or its
  /// project was gone or in the trash go back to the queue.
  ///
  /// A queued delete whose earlier attempt may have reached the server (a
  /// timeout, a 5xx, a kill in flight) is removed too, and the task is
  /// also restored from the trash in case it got there; a task the server
  /// never trashed is read back as it is. When that request does not get
  /// through the task shows again all the same, and if the server did
  /// trash it, the next sync may take it away again. A refusal that keeps
  /// the task in the trash (`Forbidden`, `DomainError`, `NotFound` code
  /// 3018) is thrown, with the task showing again.
  ///
  /// Throws the `VikunjaFailure` of the restore: `NotFound` code 4002 when
  /// the task is gone for good or never reached the server, `DomainError`
  /// code 3008 in an archived project, `NotFound` code 3018 in a trashed
  /// project, `Forbidden` without write permission, a `NetworkFailure`
  /// offline; `NotFound` without a code on a server without the trash.
  /// Throws [TaskDeleteInFlight] when another process is still sending the
  /// delete after `restoreWait`.
  Future<Task> restoreTask(int taskId);

  /// Asks the server for a copy (labels, assignees, attachments and
  /// reminders included, plus a `copiedfrom` relation), so it needs a
  /// connection and the task's queued changes sent first; stores the copy
  /// and returns its id. Throws the `VikunjaFailure`; while the task's
  /// changes cannot be sent, the one the queue waits out (offline a
  /// `NetworkFailure`), else [TaskNotSyncedYet].
  Future<int> duplicateTask(int taskId);

  /// Stores a copy of the file at [sourcePath] in the account's uploads
  /// folder (moves it there with [moveSource], for a file the app owns,
  /// such as a picker's or a share inbox copy) and queues its upload to
  /// the task, behind the task's create while that is queued; works
  /// offline. Returns the op's id, null when the task is not on this
  /// device or queued for deletion (nothing is kept then). Throws
  /// [UploadTooLarge] above the upload limit, before anything is stored.
  /// A file given with [moveSource] is gone whenever it is not queued.
  Future<String?> queueUpload(
    int taskId, {
    required String sourcePath,
    required String fileName,
    String? mimeType,
    bool moveSource = false,
  });

  /// The task's queued uploads, oldest first, failed ones included;
  /// follows the task across the id change of its create.
  Stream<List<PendingUpload>> watchPendingUploads(int taskId);

  /// Every attachment a queued upload created, as the server answered,
  /// once it is through; the detail sheet adds it without a read.
  Stream<TaskAttachment> get uploadedAttachments;

  /// Drops the queued upload and its stored copy; an upload on its way is
  /// aborted (what the server already stored stays there).
  Future<void> cancelUpload(String operationId);

  /// Queued changes not yet accepted by the server, failed ones included.
  Stream<int> watchPendingChanges();

  Stream<List<SyncProblem>> watchSyncProblems();

  Future<void> retrySyncProblem(String operationId);

  /// Drops the queued change and restores the row from the server. Throws
  /// the `VikunjaFailure` of that read and changes nothing then.
  Future<void> discardSyncProblem(String operationId);

  /// The description the server has now for the task of a
  /// `DescriptionConflict`, to show next to the queued one; null when the
  /// server no longer has the task. Throws the `VikunjaFailure` of the read.
  Future<String?> webDescription(String operationId);

  /// "Keep mine" for a `DescriptionConflict`: the change goes again and
  /// overwrites [webDescription], the one from the web the user saw; when
  /// the web changed it once more by the time it is sent, the change fails
  /// again instead.
  Future<void> keepMyDescription(
    String operationId, {
    required String webDescription,
  });

  /// "Use the web's" for a `DescriptionConflict`: the queued description
  /// goes and the server's comes back; the other fields of the change are
  /// still sent. Throws the `VikunjaFailure` of the server read and changes
  /// nothing then.
  Future<void> useWebDescription(String operationId);

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

/// The task's delete is still on its way to the server, usually sent by
/// another process, so it can be taken back only once it has arrived.
final class TaskDeleteInFlight implements Exception {
  const new(this.taskId);

  final int taskId;

  @override
  String toString() => 'TaskDeleteInFlight($taskId)';
}
