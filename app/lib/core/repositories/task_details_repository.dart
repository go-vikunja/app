import 'package:vikunja_domain/vikunja_domain.dart';

/// What a read of the server brought last, as the device keeps it, and
/// when it was read.
typedef StoredRead<T> = ({T value, DateTime readAt});

/// What the detail sheet shows beyond the synced row, read on demand from
/// the server, like `SubscriptionRepository`: a failure is the
/// `VikunjaFailure` of the request (offline a `NetworkFailure`), and a task
/// whose create is still queued throws `TaskNotSyncedYet`. Each read is
/// also stored, in place of the one before, for [storedDetails] and
/// [storedComments] to show without a connection; one that started before
/// a write to what is stored is not, as it may not have the write.
/// Comments and reactions are written online; what the server answers
/// goes back to the caller to show at once and into what is stored. The
/// synced row keeps the comment count and the unread flag, which these
/// calls keep in step.
abstract interface class TaskDetailsRepository {
  /// Attachments, reactions, comment count, unread flag, subscription and
  /// permission of the task, from one read; the row takes the count and
  /// the flag. A cover change still queued here shows over the server's
  /// until it is sent.
  Future<TaskDetails> details(int taskId);

  /// The attachments, cover and reactions of the last [details] stored
  /// here, with the row's comment count; null when there are none.
  Future<StoredRead<TaskDetails>?> storedDetails(int taskId);

  /// One page of comments, sorted by `(created, id)`, oldest first unless
  /// [newestFirst]. The first page is stored in place of the comments
  /// stored before, a later one beside them, so what is stored is what
  /// the pages read since the last first page brought.
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  });

  /// The stored comments, oldest first; null when none were ever stored.
  Future<StoredRead<List<TaskComment>>?> storedComments(int taskId);

  /// Clears the unread flag on the server, then that of the row, so a
  /// failed mark leaves the row unread. Idempotent; callers ignore the
  /// failure.
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
  /// task by its local id like the other calls, a comment by its own); the
  /// stored reactions follow.
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
