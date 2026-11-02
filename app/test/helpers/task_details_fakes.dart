import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/links/deep_link_source.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_resolver.dart';

/// The details of tasks as the server holds them: [detailsByTask] is what
/// a read answers per task id (absent: nothing beyond the row,
/// `TaskDetails()`), [commentsByTask] every comment of a task in any
/// order, served sorted by `(created, id)` in pages of [commentsPerPage].
///
/// Writes change that state like the server: a new comment by [me] under
/// [nextCommentId] at [clock], appended to the task's comments and counted
/// in its details; an edit or delete of a comment by someone else fails
/// with `Forbidden`, an edit of one that is gone with `NotFound` 4015, a
/// delete of one that is gone passes; reactions by [me] go onto the task's
/// details or the comment, a value already there or one not there changes
/// nothing, and an added value outside 1 to 20 code points is an
/// `ArgumentError` before the call is recorded.
///
/// Every call is recorded in [calls] (`details 3`, `comments 3 page 1
/// oldest`, `comments 3 page 2 newest`, `markRead 3`, `addComment 3`,
/// `editComment 3 7`, `deleteComment 3 7`, `addReaction task 3 👍`,
/// `removeReaction comment 7 👍`), every mark read in [markedRead] and
/// every comment body sent in [sentHtml]; [beforeCall] can hold one, and
/// [detailsFailure], [commentsFailure], [markReadFailure],
/// [addCommentFailure], [editCommentFailure], [deleteCommentFailure] and
/// [reactionFailure] (a `VikunjaFailure`, or `TaskNotSyncedYet`) are
/// thrown instead while set, before anything changes. [serverChanged]
/// is what [watchServerChanges] delivers for a task. [onRowChange] gets
/// what the real repository changes on the synced row: the count and the
/// flag a details read brings, the flag a mark read clears, the count a
/// comment written or deleted moves.
final class FakeTaskDetailsRepository implements TaskDetailsRepository {
  new({DateTime Function()? clock})
    : clock = clock ?? (() => DateTime.utc(2026, 10, 21, 12));

  final Map<int, TaskDetails> detailsByTask = {};
  final Map<int, List<TaskComment>> commentsByTask = {};
  int commentsPerPage = 50;
  final List<String> calls = [];
  final List<int> markedRead = [];
  final List<String> sentHtml = [];
  Exception? detailsFailure;
  Exception? commentsFailure;
  Exception? markReadFailure;
  Exception? addCommentFailure;
  Exception? editCommentFailure;
  Exception? deleteCommentFailure;
  Exception? reactionFailure;
  Future<void> Function(String call)? beforeCall;

  /// The signed-in user: the author of new comments and the one who reacts.
  User me = const User(id: 1, username: 'me', name: 'Me');
  int nextCommentId = 500;
  DateTime Function() clock;

  void Function(int taskId, Task Function(Task row) change)? onRowChange;

  final _changes = <int, StreamController<DateTime>>{};

  @override
  Future<TaskDetails> details(int taskId) async {
    await _call('details $taskId', detailsFailure);
    final details = detailsByTask[taskId] ?? const TaskDetails();
    onRowChange?.call(
      taskId,
      (row) => row.copyWith(
        commentCount: details.commentCount,
        isUnread: details.isUnread,
      ),
    );
    return details;
  }

  @override
  Future<Page<TaskComment>> comments(
    int taskId, {
    int page = 1,
    bool newestFirst = false,
  }) async {
    await _call(
      'comments $taskId page $page ${newestFirst ? 'newest' : 'oldest'}',
      commentsFailure,
    );
    final all = [...?commentsByTask[taskId]]
      ..sort((a, b) {
        final byCreated = (a.created ?? DateTime(0)).compareTo(
          b.created ?? DateTime(0),
        );
        return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
      });
    final ordered = newestFirst ? all.reversed.toList() : all;
    final start = (page - 1) * commentsPerPage;
    return Page(
      items: start >= ordered.length
          ? const []
          : ordered.sublist(
              start,
              (start + commentsPerPage).clamp(0, ordered.length),
            ),
      page: page,
      perPage: commentsPerPage,
      totalPages: (ordered.length / commentsPerPage).ceil(),
      total: ordered.length,
    );
  }

  @override
  Future<void> markRead(int taskId) async {
    onRowChange?.call(taskId, (row) => row.copyWith(isUnread: false));
    await _call('markRead $taskId', markReadFailure);
    markedRead.add(taskId);
  }

  @override
  Future<TaskComment> addComment(int taskId, CommentDraft draft) async {
    await _call('addComment $taskId', addCommentFailure);
    sentHtml.add(draft.html);
    final now = clock().toUtc();
    final comment = TaskComment(
      id: nextCommentId++,
      html: draft.html,
      author: me,
      created: now,
      updated: now,
    );
    (commentsByTask[taskId] ??= []).add(comment);
    _countComments(taskId, 1);
    onRowChange?.call(
      taskId,
      (row) => row.copyWith(commentCount: row.commentCount + 1),
    );
    return comment;
  }

  @override
  Future<TaskComment> editComment(
    int taskId,
    TaskComment comment,
    CommentDraft draft,
  ) async {
    await _call('editComment $taskId ${comment.id}', editCommentFailure);
    final stored = _ownComment(taskId, comment.id);
    if (stored == null) throw const NotFound(code: 4015);
    sentHtml.add(draft.html);
    final edited = stored.copyWith(html: draft.html, updated: clock().toUtc());
    _replaceComment(taskId, edited);
    return edited;
  }

  @override
  Future<void> deleteComment(int taskId, int commentId) async {
    await _call('deleteComment $taskId $commentId', deleteCommentFailure);
    if (_ownComment(taskId, commentId) == null) return;
    commentsByTask[taskId]!.removeWhere((comment) => comment.id == commentId);
    _countComments(taskId, -1);
    onRowChange?.call(
      taskId,
      (row) => row.copyWith(
        commentCount: row.commentCount > 0 ? row.commentCount - 1 : 0,
      ),
    );
  }

  @override
  Future<void> addReaction(ReactionEntity kind, int id, String value) async {
    final length = value.runes.length;
    if (length == 0 || length > maxReactionLength) {
      throw ArgumentError.value(value, 'value');
    }
    await _call('addReaction ${kind.name} $id $value', reactionFailure);
    _react(kind, id, (reactions) {
      final users = reactions[value] ?? const <User>[];
      if (users.any((user) => user.id == me.id)) return reactions;
      return {
        ...reactions,
        value: [...users, me],
      };
    });
  }

  @override
  Future<void> removeReaction(ReactionEntity kind, int id, String value) async {
    await _call('removeReaction ${kind.name} $id $value', reactionFailure);
    _react(kind, id, (reactions) {
      final users = [
        for (final user in reactions[value] ?? const <User>[])
          if (user.id != me.id) user,
      ];
      return {
        for (final MapEntry(key: other, value: others) in reactions.entries)
          if (other != value || users.isNotEmpty)
            other: other == value ? users : others,
      };
    });
  }

  @override
  Stream<DateTime> watchServerChanges(int taskId) => _changesOf(taskId).stream;

  /// Delivers [updated] to the sheets watching [taskId], as a sync bringing
  /// a newer row would.
  void serverChanged(int taskId, DateTime updated) =>
      _changesOf(taskId).add(updated.toUtc());

  StreamController<DateTime> _changesOf(int taskId) =>
      _changes.putIfAbsent(taskId, StreamController<DateTime>.broadcast);

  /// The stored comment [commentId] of [taskId]; `Forbidden` when someone
  /// else wrote it.
  TaskComment? _ownComment(int taskId, int commentId) {
    final stored = commentsByTask[taskId]
        ?.where((comment) => comment.id == commentId)
        .firstOrNull;
    if (stored != null && stored.author.id != me.id) throw const Forbidden();
    return stored;
  }

  void _replaceComment(int taskId, TaskComment comment) {
    final comments = commentsByTask[taskId]!;
    comments[comments.indexWhere((stored) => stored.id == comment.id)] =
        comment;
  }

  void _countComments(int taskId, int delta) {
    final details = detailsByTask[taskId];
    if (details == null) return;
    detailsByTask[taskId] = details.copyWith(
      commentCount: (details.commentCount + delta).clamp(0, 1 << 31),
    );
  }

  void _react(
    ReactionEntity kind,
    int id,
    Reactions Function(Reactions reactions) change,
  ) {
    switch (kind) {
      case ReactionEntity.task:
        final details = detailsByTask[id] ?? const TaskDetails();
        detailsByTask[id] = details.copyWith(
          reactions: change(details.reactions),
        );
      case ReactionEntity.comment:
        for (final MapEntry(key: taskId, value: comments)
            in commentsByTask.entries) {
          for (final comment in comments) {
            if (comment.id != id) continue;
            _replaceComment(
              taskId,
              comment.copyWith(reactions: change(comment.reactions)),
            );
            return;
          }
        }
        throw const NotFound(code: 4015);
    }
  }

  Future<void> _call(String call, Exception? failure) async {
    calls.add(call);
    await beforeCall?.call(call);
    if (failure != null) throw failure;
  }
}

/// Resolves from the `local` tasks first (an id by `Task.id`, an
/// identifier by `Task.identifier` ignoring case), then from [online];
/// [failures] fails one reference online, and a reference found nowhere
/// fails with `NotFound` code 4002. Every reference [resolve] gets is
/// recorded in [resolved], the ones that went online in [onlineRequests],
/// and every [findLocal] in [localLookups]; [beforeResolve] can hold or
/// fail a resolve.
final class FakeTaskResolver implements TaskResolver {
  new({List<Task> Function()? local}) : _local = local ?? (() => const []);

  final List<Task> Function() _local;
  final Map<TaskReference, Task> online = {};
  final Map<TaskReference, Exception> failures = {};
  final List<TaskReference> resolved = [];
  final List<TaskReference> onlineRequests = [];
  final List<TaskReference> localLookups = [];
  Future<void> Function(TaskReference reference)? beforeResolve;

  @override
  Future<Task> resolve(TaskReference reference) async {
    resolved.add(reference);
    await beforeResolve?.call(reference);
    if (_findLocal(reference) case final task?) return task;
    onlineRequests.add(reference);
    if (failures[reference] case final failure?) throw failure;
    return online[reference] ?? (throw const NotFound(code: 4002));
  }

  @override
  Future<Task?> findLocal(TaskReference reference) async {
    localLookups.add(reference);
    return _findLocal(reference);
  }

  Task? _findLocal(TaskReference reference) => _local()
      .where(
        (task) => switch (reference) {
          TaskById(:final id) => task.id == id,
          TaskByIdentifier(:final identifier, :final index) =>
            task.identifier.toLowerCase() == '$identifier-$index'.toLowerCase(),
        },
      )
      .firstOrNull;
}

/// Attachment images by `(taskId, attachmentId, preview)`: [images] what a
/// load answers, [failures] what it throws; a key in neither fails with
/// `NotFound` code 4002 unless [fallback] is set. [peek] answers only
/// images loaded before, like the real cache. A failed load is
/// remembered until it is forgotten, a failure that cannot pass for good.
/// Every load is recorded in [loads] (`3 7 md`, `3 7 original`);
/// [beforeLoad] can hold one.
final class FakeAttachmentImages implements AttachmentImages {
  final Map<(int, int, AttachmentPreviewSize?), AttachmentImage> images = {};
  final Map<(int, int, AttachmentPreviewSize?), Exception> failures = {};
  AttachmentImage? fallback;
  final List<String> loads = [];
  Future<void> Function(String load)? beforeLoad;
  final _loaded = <(int, int, AttachmentPreviewSize?)>{};
  final _failed = <(int, int, AttachmentPreviewSize?), Object>{};

  @override
  Future<AttachmentImage> load(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) async {
    final description =
        '$taskId $attachmentId ${preview?.wireName ?? 'original'}';
    loads.add(description);
    await beforeLoad?.call(description);
    final key = (taskId, attachmentId, preview);
    final image = images[key] ?? fallback;
    final failure =
        failures[key] ?? (image == null ? const NotFound(code: 4002) : null);
    if (failure != null) {
      _failed[key] = failure;
      throw failure;
    }
    _failed.remove(key);
    _loaded.add(key);
    return image!;
  }

  @override
  bool remembersFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) => _failed.containsKey((taskId, attachmentId, preview));

  @override
  void forgetFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    if (_failed[key] case final failure?
        when attachmentImageFailureMayPass(failure)) {
      _failed.remove(key);
    }
  }

  @override
  void forgetFailures() => _failed.removeWhere(
    (_, failure) => attachmentImageFailureMayPass(failure),
  );

  @override
  AttachmentImage? peek(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    return _loaded.contains(key) ? images[key] ?? fallback : null;
  }
}

/// [initial] is answered once by [initialLink]; [push] delivers a link
/// while the app runs.
final class FakeDeepLinkSource implements DeepLinkSource {
  new({this.initial});

  Uri? initial;
  final controller = StreamController<Uri>.broadcast();
  int initialLinkCalls = 0;

  @override
  Future<Uri?> initialLink() async {
    initialLinkCalls++;
    final link = initial;
    initial = null;
    return link;
  }

  @override
  Stream<Uri> get links => controller.stream;

  void push(Uri uri) => controller.add(uri);
}

/// A 1×1 PNG that `Image.memory` decodes.
final Uint8List samplePngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwTpv5HwAE'
  'NAIyWy0K4AAAAABJRU5ErkJggg==',
);

final AttachmentImage samplePngImage = AttachmentImage(
  bytes: samplePngBytes,
  contentType: 'image/png',
);

/// An SVG's original, which servers before 2.7.1 also send for a preview.
final AttachmentImage sampleSvgImage = AttachmentImage(
  bytes: utf8.encode(
    '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
  ),
  contentType: 'image/svg+xml',
);
