import 'package:vikunja_domain/vikunja_domain.dart';

/// What the detail sheet shows beyond the synced row, read on demand and
/// online only, like `SubscriptionRepository`: nothing is stored, a failure
/// is the `VikunjaFailure` of the request (offline a `NetworkFailure`), and
/// a task whose create is still queued throws `TaskNotSyncedYet`.
abstract interface class TaskDetailsRepository {
  /// Attachments, reactions, comment count, unread flag and subscription of
  /// the task, from one read.
  Future<TaskDetails> details(int taskId);

  /// One page of comments, sorted by `(created, id)`, oldest first unless
  /// [newestFirst].
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  });

  /// Clears the unread flag on the server. Idempotent; callers ignore the
  /// failure.
  Future<void> markRead(int taskId);
}
