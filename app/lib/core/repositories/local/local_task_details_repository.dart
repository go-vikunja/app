import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
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
  Future<TaskDetails> details(int taskId) async {
    final id = await _serverId(taskId);
    final details = await _read.tasks.readDetails(id);
    // The sync cannot see a task read elsewhere: mark-read bumps nothing.
    await _db.tasksDao.storeCommentState(
      id,
      commentCount: details.commentCount,
      isUnread: details.isUnread,
    );
    return details;
  }

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
    final id = await _serverId(taskId);
    await _db.tasksDao.storeCommentState(id, isUnread: false);
    await _write.tasks.markRead(id);
  }

  @override
  Future<TaskComment> addComment(int taskId, CommentDraft draft) async {
    _checkContent(draft);
    final id = await _serverId(taskId);
    final created = await _write.comments.create(id, draft.html);
    await _db.tasksDao.addToCommentCount(id, 1);
    return created;
  }

  @override
  Future<TaskComment> editComment(
    int taskId,
    TaskComment comment,
    CommentDraft draft,
  ) async {
    _checkContent(draft);
    final id = await _serverId(taskId);
    final stored = await _write.comments.update(id, comment.id, draft.html);
    return comment.copyWith(
      html: stored.html,
      updated: stored.updated ?? comment.updated,
    );
  }

  @override
  Future<void> deleteComment(int taskId, int commentId) async {
    final id = await _serverId(taskId);
    await _write.comments.delete(id, commentId);
    await _db.tasksDao.addToCommentCount(id, -1);
  }

  @override
  Future<void> addReaction(ReactionEntity kind, int id, String value) async {
    _checkReactionLength(value);
    await _write.reactions.add(kind, await _reactionTarget(kind, id), value);
  }

  @override
  Future<void> removeReaction(ReactionEntity kind, int id, String value) async {
    // No length check: v1 stores longer values, which must stay removable.
    await _write.reactions.remove(kind, await _reactionTarget(kind, id), value);
  }

  // Not async*: its cancel would wait for a row change that may never come.
  @override
  Stream<DateTime> watchServerChanges(int taskId) => Stream.multi((changes) {
    DateTime? seen;
    final rows = _db.tasksDao
        .watchTask(taskId)
        .listen(
          (task) {
            final updated = task?.updated;
            final before = seen;
            if (updated == null ||
                (before != null && !updated.isAfter(before))) {
              return;
            }
            seen = updated;
            if (before != null) changes.add(updated);
          },
          onError: changes.addError,
          onDone: changes.close,
        );
    changes
      ..onPause = rows.pause
      ..onResume = rows.resume
      ..onCancel = rows.cancel;
  });

  Future<int> _reactionTarget(ReactionEntity kind, int id) async =>
      switch (kind) {
        ReactionEntity.task => await _serverId(id),
        ReactionEntity.comment => id,
      };

  Future<int> _serverId(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    if (id < 0) throw TaskNotSyncedYet(taskId);
    return id;
  }

  static void _checkContent(CommentDraft draft) {
    final html = draft.html.trim();
    if (html.isEmpty || isRichTextEmpty(html)) {
      throw ArgumentError.value(draft, 'draft', 'A comment needs content');
    }
  }

  static void _checkReactionLength(String value) {
    final length = value.runes.length;
    if (length == 0 || length > maxReactionLength) {
      throw ArgumentError.value(
        length,
        'value',
        'A reaction is 1 to $maxReactionLength code points long',
      );
    }
  }

  // The server keeps `created` to the second, so ties are common.
  static int _oldestFirst(TaskComment a, TaskComment b) {
    final byCreated = (a.created?.millisecondsSinceEpoch ?? 0).compareTo(
      b.created?.millisecondsSinceEpoch ?? 0,
    );
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }
}
