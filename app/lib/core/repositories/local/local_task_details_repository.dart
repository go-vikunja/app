import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

final _log = Logger('AccountData');

/// The details straight from the server, addressed by the task's server
/// id: a task created here once its create was answered, before that
/// [TaskNotSyncedYet] without a request. What is read and written is kept
/// in the account's database, stamped with [_now]; a failure to keep it
/// leaves the read or write standing.
final class LocalTaskDetailsRepository implements TaskDetailsRepository {
  new(
    this._db,
    this._read,
    this._write, {
    this._subscriberId,
    this._me,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;

  /// The user's id on a server whose reminders follow the subscriptions:
  /// each details read then also records the user's own
  /// subscription to the task, which only such a read carries, for the
  /// notifications. Null records nothing.
  final int? _subscriberId;

  /// The signed-in user as the server lists those who reacted; null leaves
  /// the stored reactions as they are after a reaction is written.
  final User? _me;
  final DateTime Function() _now;

  @override
  Future<TaskDetails> details(int taskId) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    final version = _db.taskDetailsDao.detailsVersion(id);
    final commentsVersion = _db.taskDetailsDao.commentsVersion(id);
    final queuedBefore = await _queuedCover(id);
    final read = await _read.tasks.readDetails(id);
    // A cover queued here, or sent while the read was under way, stands
    // over what the server answered.
    final queued = await _queuedCover(id) ?? queuedBefore;
    final details = queued == null
        ? read
        : read.copyWith(coverImageAttachmentId: queued);
    // The sync cannot see a task read elsewhere: mark-read bumps nothing.
    // A comment written or deleted here since the read started, or on its
    // way, moves the count itself; the server may have counted it or not.
    if (_db.taskDetailsDao.commentCountHolds(id, commentsVersion)) {
      await _db.tasksDao.storeCommentState(
        id,
        commentCount: details.commentCount,
        isUnread: details.isUnread,
      );
    }
    await _recordSubscription(id, details.subscription);
    await _keep(
      'details',
      () => _db.taskDetailsDao.storeDetails(
        id,
        details,
        at: _now(),
        version: version,
      ),
    );
    return details;
  }

  @override
  Future<StoredRead<TaskDetails>?> storedDetails(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    return id < 0 ? null : await _db.taskDetailsDao.storedDetails(id);
  }

  @override
  Future<StoredRead<List<TaskComment>>?> storedComments(int taskId) async {
    final id = await _db.tasksDao.resolveId(taskId);
    return id < 0 ? null : await _db.taskDetailsDao.storedComments(id);
  }

  Future<int?> _queuedCover(int id) async =>
      (await _db.outboxDao.pendingChangesFor(id))?.coverImageAttachmentId;

  /// A failure only leaves the stored state as it was; the read stands.
  Future<void> _recordSubscription(int id, Subscription? read) async {
    final userId = _subscriberId;
    if (userId == null) return;
    try {
      await _db.tasksDao.storeOwnSubscription(id, read, userId: userId);
    } on Object catch (error) {
      _log.warning(
        'Could not store whether the user follows a task: '
        '${error.runtimeType}',
      );
    }
  }

  @override
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  }) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    final version = _db.taskDetailsDao.commentsVersion(id);
    final comments = await _read.comments.list(
      id,
      page: page,
      newestFirst: newestFirst,
    );
    final sorted = [...comments.items]..sort(_oldestFirst);
    await _keep(
      'comments',
      () => _db.taskDetailsDao.storeComments(
        id,
        sorted,
        replace: page == 1,
        at: _now(),
        version: version,
      ),
    );
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
    final id = await serverTaskId(_db.tasksDao, taskId);
    await _write.tasks.markRead(id);
    await _db.tasksDao.storeCommentState(id, isUnread: false);
  }

  @override
  Future<TaskComment> addComment(int taskId, CommentDraft draft) async {
    _checkContent(draft);
    final id = await serverTaskId(_db.tasksDao, taskId);
    return await _db.taskDetailsDao.writingComment(id, () async {
      final created = await _write.comments.create(id, draft.html);
      await _db.tasksDao.addToCommentCount(id, 1);
      await _keep(
        'a comment',
        () => _db.taskDetailsDao.putComment(id, created),
      );
      return created;
    });
  }

  @override
  Future<TaskComment> editComment(
    int taskId,
    TaskComment comment,
    CommentDraft draft,
  ) async {
    _checkContent(draft);
    final id = await serverTaskId(_db.tasksDao, taskId);
    final stored = await _write.comments.update(id, comment.id, draft.html);
    final edited = comment.copyWith(
      html: stored.html,
      updated: stored.updated ?? comment.updated,
    );
    await _keep(
      'an edit',
      () => _db.taskDetailsDao.editComment(
        id,
        comment.id,
        html: edited.html,
        updated: edited.updated,
      ),
    );
    return edited;
  }

  @override
  Future<void> deleteComment(int taskId, int commentId) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    await _db.taskDetailsDao.writingComment(id, () async {
      await _write.comments.delete(id, commentId);
      await _db.tasksDao.addToCommentCount(id, -1);
      await _keep(
        'a deletion',
        () => _db.taskDetailsDao.removeComment(id, commentId),
      );
    });
  }

  @override
  Future<void> addReaction(ReactionEntity kind, int id, String value) async {
    _checkReactionLength(value);
    final target = await _reactionTarget(kind, id);
    await _write.reactions.add(kind, target, value);
    await _keepReaction(kind, target, value, add: true);
  }

  @override
  Future<void> removeReaction(ReactionEntity kind, int id, String value) async {
    // No length check: v1 stores longer values, which must stay removable.
    final target = await _reactionTarget(kind, id);
    await _write.reactions.remove(kind, target, value);
    await _keepReaction(kind, target, value, add: false);
  }

  Future<void> _keepReaction(
    ReactionEntity kind,
    int target,
    String value, {
    required bool add,
  }) async {
    final me = _me;
    if (me == null) return;
    await _keep(
      'a reaction',
      () =>
          _db.taskDetailsDao.toggleReaction(kind, target, value, me, add: add),
    );
  }

  Future<void> _keep(String what, Future<void> Function() store) async {
    try {
      await store();
    } on Object catch (error) {
      _log.warning('Could not store $what of a task: ${error.runtimeType}');
    }
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
        ReactionEntity.task => await serverTaskId(_db.tasksDao, id),
        ReactionEntity.comment => id,
      };

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
