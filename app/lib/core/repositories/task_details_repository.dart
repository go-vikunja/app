import 'package:vikunja_domain/vikunja_domain.dart';

/// What the detail sheet shows beyond the synced row, read on demand and
/// online only, like `SubscriptionRepository`: a failure is the
/// `VikunjaFailure` of the request (offline a `NetworkFailure`), and a task
/// whose create is still queued throws `TaskNotSyncedYet`. Comments and
/// reactions are written online too; what the server answers goes back to
/// the caller to show at once. The synced row keeps only the comment count
/// and the unread flag, which these calls keep in step.
abstract interface class TaskDetailsRepository {
  /// Attachments, reactions, comment count, unread flag, subscription and
  /// permission of the task, from one read; the row takes the count and
  /// the flag.
  Future<TaskDetails> details(int taskId);

  /// One page of comments, sorted by `(created, id)`, oldest first unless
  /// [newestFirst].
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  });

  /// Clears the unread flag of the row at once, then on the server.
  /// Idempotent; callers ignore the failure.
  Future<void> markRead(int taskId);

  /// The comment as stored; the row's comment count goes up by one. A
  /// draft without content is an `ArgumentError` without a request (the
  /// server would store whitespace and `<p></p>`). Not idempotent: an
  /// answer lost on the way leaves the comment on the server.
  Future<TaskComment> addComment(int taskId, CommentDraft draft);

  /// [comment] with the new body and `updated`; its author, `created` and
  /// reactions stay, as the server's answer leaves them out or blank. Only
  /// the author may (`Forbidden` for anyone else). A draft without content
  /// is refused like [addComment]'s.
  Future<TaskComment> editComment(
    int taskId,
    TaskComment comment,
    CommentDraft draft,
  );

  /// Only the author may; one that is gone counts as deleted. The row's
  /// comment count goes down by one. A `ServerFailure` 404 means the server
  /// did not apply it and still has the comment.
  Future<void> deleteComment(int taskId, int commentId);

  /// The user's own reaction with [value] on the task or comment [id] (a
  /// task by its local id like the other calls, a comment by its own).
  /// Adding twice or removing one the user does not have changes nothing.
  /// An added [value] is 1 to [maxReactionLength] code points, else an
  /// `ArgumentError` without a request; v1 servers stored longer ones,
  /// which can still be removed.
  Future<void> addReaction(ReactionEntity kind, int id, String value);

  Future<void> removeReaction(ReactionEntity kind, int id, String value);

  /// Each newer server `updated` the synced row of the task shows from now
  /// on: a comment written by anyone, a change made elsewhere, own writes
  /// once a sync brought them back. Not the state at subscription; follows
  /// a queued create to its server id.
  Stream<DateTime> watchServerChanges(int taskId);
}
