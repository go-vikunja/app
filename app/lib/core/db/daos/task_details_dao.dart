import 'dart:math';

import 'package:drift/drift.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/tables/task_details.dart';
import 'package:vikunja_mobile/core/db/tables/tasks.dart';

part 'task_details_dao.g.dart';

typedef _ReactionEntry = ({String value, User user});

/// The attachments, cover, reactions and comments of a task as the server
/// last answered them, by the task's server id. A read replaces what is
/// stored; a write the server took, or a cover change queued here, changes
/// it. Both leave alone a task that is not stored here, and the writes one
/// whose details or comments were never stored, whose stored set they
/// would make look complete. A read that started before such a write may
/// not have it and stores nothing ([detailsVersion], [commentsVersion]).
@DriftAccessor(
  tables: [
    Tasks,
    TaskDetailLoads,
    TaskAttachments,
    TaskReactions,
    TaskComments,
    TaskCommentReactions,
  ],
)
final class TaskDetailsDao extends DatabaseAccessor<AppDatabase>
    with _$TaskDetailsDaoMixin {
  new(super.attachedDatabase);

  // In memory, per isolate: the reads run in the app's, and a restart ends
  // them.
  final _detailsVersions = <int, int>{};
  final _commentsVersions = <int, int>{};
  final _commentWrites = <int, int>{};

  /// Taken before a read for [storeDetails]; every write to the task's
  /// stored attachments, cover and reactions changes it.
  int detailsVersion(int taskId) => _detailsVersions[taskId] ?? 0;

  /// Taken before a read for [storeComments]; every write to the task's
  /// stored comments and their reactions changes it.
  int commentsVersion(int taskId) => _commentsVersions[taskId] ?? 0;

  /// Whether a details read that took [version] ([commentsVersion]) before
  /// it started may store the task's comment count it read: no comment of
  /// the task was written or deleted here since ([writingComment]), and none
  /// is on its way, which the server may or may not have counted.
  bool commentCountHolds(int taskId, int version) =>
      version == commentsVersion(taskId) && !_commentWrites.containsKey(taskId);

  /// Runs [write], which writes or deletes a comment of the task on the
  /// server and then moves its stored count.
  Future<T> writingComment<T>(int taskId, Future<T> Function() write) async {
    _commentWrites.update(taskId, (writes) => writes + 1, ifAbsent: () => 1);
    try {
      return await write();
    } finally {
      final left = _commentWrites[taskId]! - 1;
      if (left == 0) {
        _commentWrites.remove(taskId);
      } else {
        _commentWrites[taskId] = left;
      }
      _changed(_commentsVersions, taskId);
    }
  }

  /// Nothing when [version] is given and no longer the task's.
  Future<void> storeDetails(
    int taskId,
    TaskDetails details, {
    required DateTime at,
    int? version,
  }) => transaction(() async {
    if (!await _taskStored(taskId)) return;
    if (version != null && version != detailsVersion(taskId)) return;
    await (delete(taskAttachments)..where((a) => a.taskId.equals(taskId))).go();
    await (delete(taskReactions)..where((r) => r.taskId.equals(taskId))).go();
    await batch((b) {
      b
        ..insertAll(taskAttachments, [
          for (final (position, attachment) in details.attachments.indexed)
            _attachmentRow(taskId, attachment, position),
        ], mode: InsertMode.insertOrReplace)
        ..insertAll(taskReactions, [
          for (final (position, (:value, :user)) in _entriesOf(
            details.reactions,
          ).indexed)
            TaskReactionRow(
              taskId: taskId,
              position: position,
              value: value,
              userId: user.id,
              username: user.username,
              name: user.name,
            ),
        ]);
    });
    await _stamp(
      taskId,
      TaskDetailLoadsCompanion(
        detailsLoadedAt: Value(at),
        coverImageAttachmentId: Value(details.coverImageAttachmentId),
      ),
    );
  });

  /// With the comment count of the task's row; null when never stored.
  Future<({TaskDetails value, DateTime readAt})?> storedDetails(int taskId) =>
      transaction(() async {
        final load = await _loadOf(taskId);
        final at = load?.detailsLoadedAt;
        if (load == null || at == null) return null;
        final attachments =
            await (select(taskAttachments)
                  ..where((a) => a.taskId.equals(taskId))
                  ..orderBy([(a) => OrderingTerm.asc(a.position)]))
                .get();
        final reactions =
            await (select(taskReactions)
                  ..where((r) => r.taskId.equals(taskId))
                  ..orderBy([(r) => OrderingTerm.asc(r.position)]))
                .get();
        final count =
            await (selectOnly(tasks)
                  ..addColumns([tasks.commentCount])
                  ..where(tasks.id.equals(taskId)))
                .map((row) => row.read(tasks.commentCount))
                .getSingleOrNull();
        return (
          value: TaskDetails(
            attachments: [for (final row in attachments) _attachmentOf(row)],
            coverImageAttachmentId: load.coverImageAttachmentId,
            reactions: _reactionsOf([
              for (final row in reactions)
                (
                  value: row.value,
                  user: User(
                    id: row.userId,
                    username: row.username,
                    name: row.name,
                  ),
                ),
            ]),
            commentCount: count ?? 0,
          ),
          readAt: at,
        );
      });

  /// A page of comments: the first ([replace]) in place of every stored
  /// one, a later one beside those. Nothing when [version] is given and no
  /// longer the task's.
  Future<void> storeComments(
    int taskId,
    List<TaskComment> comments, {
    required bool replace,
    required DateTime at,
    int? version,
  }) => transaction(() async {
    if (!await _taskStored(taskId)) return;
    if (version != null && version != commentsVersion(taskId)) return;
    if (replace) {
      await (delete(taskComments)..where((c) => c.taskId.equals(taskId))).go();
    }
    await _putComments(taskId, comments);
    await _stamp(taskId, TaskDetailLoadsCompanion(commentsLoadedAt: Value(at)));
  });

  /// Oldest first, by `(created, id)`; null when never stored.
  Future<({List<TaskComment> value, DateTime readAt})?> storedComments(
    int taskId,
  ) => transaction(() async {
    final at = (await _loadOf(taskId))?.commentsLoadedAt;
    if (at == null) return null;
    final rows =
        await (select(taskComments)
              ..where((c) => c.taskId.equals(taskId))
              ..orderBy([
                (c) => OrderingTerm.asc(c.created, nulls: NullsOrder.first),
                (c) => OrderingTerm.asc(c.id),
              ]))
            .get();
    final reactions =
        await (select(taskCommentReactions)
              ..where((r) => r.taskId.equals(taskId))
              ..orderBy([(r) => OrderingTerm.asc(r.position)]))
            .get();
    final byComment = <int, List<_ReactionEntry>>{};
    for (final row in reactions) {
      (byComment[row.commentId] ??= []).add((
        value: row.value,
        user: User(id: row.userId, username: row.username, name: row.name),
      ));
    }
    return (
      value: [
        for (final row in rows)
          TaskComment(
            id: row.id,
            html: row.html,
            author: User(
              id: row.authorId,
              username: row.authorUsername,
              name: row.authorName,
            ),
            created: row.created,
            updated: row.updated,
            reactions: _reactionsOf(byComment[row.id] ?? const []),
          ),
      ],
      readAt: at,
    );
  });

  /// A comment written here.
  Future<void> putComment(int taskId, TaskComment comment) {
    _changed(_commentsVersions, taskId);
    return transaction(() async {
      if ((await _loadOf(taskId))?.commentsLoadedAt == null) return;
      await _putComments(taskId, [comment]);
    });
  }

  Future<void> editComment(
    int taskId,
    int commentId, {
    required String html,
    required DateTime? updated,
  }) {
    _changed(_commentsVersions, taskId);
    return (update(
      taskComments,
    )..where((c) => c.taskId.equals(taskId) & c.id.equals(commentId))).write(
      TaskCommentsCompanion(html: Value(html), updated: Value(updated)),
    );
  }

  Future<void> removeComment(int taskId, int commentId) {
    _changed(_commentsVersions, taskId);
    return (delete(
      taskComments,
    )..where((c) => c.taskId.equals(taskId) & c.id.equals(commentId))).go();
  }

  /// [user] added to or removed from [value] on the task [id] (by its
  /// server id) or the comment [id], last in the value as the server keeps
  /// it.
  Future<void> toggleReaction(
    ReactionEntity kind,
    int id,
    String value,
    User user, {
    required bool add,
  }) => transaction(() async {
    switch (kind) {
      case ReactionEntity.task:
        _changed(_detailsVersions, id);
        if ((await _loadOf(id))?.detailsLoadedAt == null) return;
        final mine = taskReactions.taskId.equals(id);
        if (!add) {
          await (delete(taskReactions)..where(
                (r) => mine & r.value.equals(value) & r.userId.equals(user.id),
              ))
              .go();
          return;
        }
        final rows = await (select(taskReactions)..where((_) => mine)).get();
        if (rows.any((r) => r.value == value && r.userId == user.id)) return;
        await into(taskReactions).insert(
          TaskReactionRow(
            taskId: id,
            position: _after(rows.map((r) => r.position)),
            value: value,
            userId: user.id,
            username: user.username,
            name: user.name,
          ),
        );
      case ReactionEntity.comment:
        final comment =
            await (select(taskComments)
                  ..where((c) => c.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (comment == null) return;
        _changed(_commentsVersions, comment.taskId);
        final mine =
            taskCommentReactions.taskId.equals(comment.taskId) &
            taskCommentReactions.commentId.equals(id);
        if (!add) {
          await (delete(taskCommentReactions)..where(
                (r) => mine & r.value.equals(value) & r.userId.equals(user.id),
              ))
              .go();
          return;
        }
        final rows = await (select(
          taskCommentReactions,
        )..where((_) => mine)).get();
        if (rows.any((r) => r.value == value && r.userId == user.id)) return;
        await into(taskCommentReactions).insert(
          TaskCommentReactionRow(
            taskId: comment.taskId,
            commentId: id,
            position: _after(rows.map((r) => r.position)),
            value: value,
            userId: user.id,
            username: user.username,
            name: user.name,
          ),
        );
    }
  });

  /// An attachment the server has now, last.
  Future<void> addAttachment(int taskId, TaskAttachment attachment) {
    _changed(_detailsVersions, taskId);
    return transaction(() async {
      if ((await _loadOf(taskId))?.detailsLoadedAt == null) return;
      final rows = await (select(
        taskAttachments,
      )..where((a) => a.taskId.equals(taskId))).get();
      if (rows.any((row) => row.id == attachment.id)) return;
      await into(taskAttachments).insert(
        _attachmentRow(
          taskId,
          attachment,
          _after(rows.map((row) => row.position)),
        ),
      );
    });
  }

  /// The attachment gone, and with it the cover if it was.
  Future<void> removeAttachment(int taskId, int attachmentId) {
    _changed(_detailsVersions, taskId);
    return transaction(() async {
      await (delete(taskAttachments)
            ..where((a) => a.taskId.equals(taskId) & a.id.equals(attachmentId)))
          .go();
      await (update(taskDetailLoads)..where(
            (l) =>
                l.taskId.equals(taskId) &
                l.coverImageAttachmentId.equals(attachmentId),
          ))
          .write(
            const TaskDetailLoadsCompanion(coverImageAttachmentId: Value(0)),
          );
    });
  }

  /// 0 for none.
  Future<void> storeCover(int taskId, int attachmentId) {
    _changed(_detailsVersions, taskId);
    return (update(taskDetailLoads)..where(
          (l) => l.taskId.equals(taskId) & l.detailsLoadedAt.isNotNull(),
        ))
        .write(
          TaskDetailLoadsCompanion(coverImageAttachmentId: Value(attachmentId)),
        );
  }

  Future<TaskAttachment?> storedAttachment(int taskId, int attachmentId) async {
    final row =
        await (select(taskAttachments)..where(
              (a) => a.taskId.equals(taskId) & a.id.equals(attachmentId),
            ))
            .getSingleOrNull();
    return row == null ? null : _attachmentOf(row);
  }

  Future<void> _putComments(int taskId, List<TaskComment> comments) async {
    final byId = {for (final comment in comments) comment.id: comment};
    await (delete(taskCommentReactions)
          ..where((r) => r.taskId.equals(taskId) & r.commentId.isIn(byId.keys)))
        .go();
    await batch((b) {
      b
        ..insertAllOnConflictUpdate(taskComments, [
          for (final comment in byId.values)
            TaskCommentRow(
              taskId: taskId,
              id: comment.id,
              html: comment.html,
              authorId: comment.author.id,
              authorUsername: comment.author.username,
              authorName: comment.author.name,
              created: comment.created,
              updated: comment.updated,
            ),
        ])
        ..insertAll(taskCommentReactions, [
          for (final comment in byId.values)
            for (final (position, (:value, :user)) in _entriesOf(
              comment.reactions,
            ).indexed)
              TaskCommentReactionRow(
                taskId: taskId,
                commentId: comment.id,
                position: position,
                value: value,
                userId: user.id,
                username: user.username,
                name: user.name,
              ),
        ]);
    });
  }

  Future<bool> _taskStored(int taskId) async =>
      await (selectOnly(tasks)
            ..addColumns([tasks.id])
            ..where(tasks.id.equals(taskId)))
          .getSingleOrNull() !=
      null;

  Future<TaskDetailLoadRow?> _loadOf(int taskId) => (select(
    taskDetailLoads,
  )..where((l) => l.taskId.equals(taskId))).getSingleOrNull();

  Future<void> _stamp(int taskId, TaskDetailLoadsCompanion changes) =>
      into(taskDetailLoads).insert(
        changes.copyWith(taskId: Value(taskId)),
        onConflict: DoUpdate((_) => changes),
      );

  static void _changed(Map<int, int> versions, int taskId) =>
      versions[taskId] = (versions[taskId] ?? 0) + 1;

  static int _after(Iterable<int> positions) => positions.fold(-1, max) + 1;

  static TaskAttachmentRow _attachmentRow(
    int taskId,
    TaskAttachment attachment,
    int position,
  ) => TaskAttachmentRow(
    taskId: taskId,
    id: attachment.id,
    position: position,
    name: attachment.name,
    mime: attachment.mime,
    size: attachment.size,
    created: attachment.created,
    createdById: attachment.createdBy?.id,
    createdByUsername: attachment.createdBy?.username,
    createdByName: attachment.createdBy?.name,
  );

  static TaskAttachment _attachmentOf(TaskAttachmentRow row) => TaskAttachment(
    id: row.id,
    taskId: row.taskId,
    name: row.name,
    mime: row.mime,
    size: row.size,
    created: row.created,
    createdBy: switch ((row.createdById, row.createdByUsername)) {
      (final id?, final username?) => User(
        id: id,
        username: username,
        name: row.createdByName ?? '',
      ),
      _ => null,
    },
  );

  static Iterable<_ReactionEntry> _entriesOf(Reactions reactions) sync* {
    for (final MapEntry(key: value, value: users) in reactions.entries) {
      for (final user in users) {
        yield (value: value, user: user);
      }
    }
  }

  /// In the order of [entries]: a value where it first shows, its users
  /// as they follow.
  static Reactions _reactionsOf(Iterable<_ReactionEntry> entries) {
    final reactions = <String, List<User>>{};
    for (final (:value, :user) in entries) {
      (reactions[value] ??= []).add(user);
    }
    return reactions;
  }
}
