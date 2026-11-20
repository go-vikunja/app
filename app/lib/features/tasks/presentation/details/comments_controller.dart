import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart'
    show StoredRead;
import 'package:vikunja_mobile/features/tasks/presentation/details/refresh_guard.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart'
    show keepsStored;

final _log = Logger('Comments');

@immutable
final class CommentsState {
  const new({
    this.shown = false,
    this.newestFirst = false,
    this.comments = const [],
    this.loadedPages = 0,
    this.hasMore = false,
    this.loading = false,
    this.failure,
    this.storedAt,
  });

  /// The first page the user asked for arrived or failed; until the user
  /// asks nothing is read.
  final bool shown;
  final bool newestFirst;
  final List<TaskComment> comments;
  final int loadedPages;
  final bool hasMore;
  final bool loading;

  /// Of the last page asked for; the pages before it stay.
  final Object? failure;

  /// Set while [comments] are the ones stored on the device, which the
  /// server answered then: while the first page loads, and once it failed
  /// for a reason that may pass ([failure], [keepsStored]).
  final DateTime? storedAt;

  static const _unset = Object();

  /// [failure] is replaced whether given or not; [storedAt] passed as null
  /// is cleared.
  CommentsState copyWith({
    bool? shown,
    bool? newestFirst,
    List<TaskComment>? comments,
    int? loadedPages,
    bool? hasMore,
    bool? loading,
    Object? failure,
    Object? storedAt = _unset,
  }) => CommentsState(
    shown: shown ?? this.shown,
    newestFirst: newestFirst ?? this.newestFirst,
    comments: comments ?? this.comments,
    loadedPages: loadedPages ?? this.loadedPages,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    failure: failure,
    storedAt: identical(storedAt, _unset)
        ? this.storedAt
        : storedAt as DateTime?,
  );
}

typedef CommentPageReader = Future<Page<TaskComment>> Function(
  int taskId, {
  required int page,
  required bool newestFirst,
});

typedef StoredCommentsReader = Future<StoredRead<List<TaskComment>>?> Function(
  int taskId,
);

/// A task's comments on demand, a page at a time, in the order the user's
/// settings name until the user turns it for this sheet. Comments written,
/// edited or deleted here apply at once; the server pages by offset, so a
/// deletion makes the next "Load more" read the last loaded page again to
/// skip nothing. A refresh under way when such a change comes may have
/// read the server before it, so it is dropped and read again once
/// [writing] has nothing pending; pages under way are read again once
/// they are in.
///
/// While the first page loads, and when it fails for a reason that may
/// pass ([keepsStored]), the comments last stored on the device show, if
/// any ([CommentsState.storedAt]), in the order chosen; a page of the
/// server replaces them.
final class CommentsController extends ValueNotifier<CommentsState> {
  new({required this._read, this._stored}) : super(const CommentsState());

  final CommentPageReader _read;
  final StoredCommentsReader? _stored;
  late final _guard = RefreshGuard(refreshLoaded);
  int? _taskId;
  bool _changedWhileLoading = false;
  bool _orderChosen = false;

  /// Deleted here: a page read before the server had that gone brings
  /// them still.
  final _deleted = <int>{};

  /// Comments deleted from the loaded pages since they were read: the
  /// server's next page starts that many comments later.
  int _removed = 0;
  int _perPage = 50;

  /// The settings' order, until the user picks one or the comments show.
  void useDefaultOrder({required bool newestFirst}) {
    if (_orderChosen ||
        value.shown ||
        value.loading ||
        value.newestFirst == newestFirst) {
      return;
    }
    _set(value.copyWith(newestFirst: newestFirst));
  }

  /// A task whose id changed (a queued create got its server id) starts
  /// over.
  void forTask(int taskId) {
    if (_taskId == taskId) return;
    _taskId = taskId;
    _deleted.clear();
    _restart();
    _set(CommentsState(newestFirst: value.newestFirst));
  }

  /// "Show comments" stays where it is while the first page loads, so
  /// a screen reader keeps its focus there.
  Future<void> show() async {
    if (value.shown || value.loading) return;
    await _load(1, 1);
  }

  Future<void> loadMore() async {
    if (value.loading || !value.shown) return;
    await _loadNext();
  }

  /// Retries the page that failed.
  Future<void> retry() => _loadNext();

  Future<void> toggleOrder() async {
    _orderChosen = true;
    _restart();
    _set(CommentsState(shown: value.shown, newestFirst: !value.newestFirst));
    if (value.shown) await _load(1, 1);
  }

  /// The loaded pages again, quietly, when the task changed on the server:
  /// what is shown stays until they arrive and when they fail. Stored
  /// comments that show try the first page again.
  Future<void> refreshLoaded() async {
    final taskId = _taskId;
    if (taskId == null || value.loading) return;
    final stored = value.storedAt != null && value.shown;
    if (!stored && value.loadedPages == 0) return;
    if (_guard.hasWrites) {
      _guard.markDue();
      return;
    }
    if (stored) return await retry();
    final pages = value.loadedPages;
    final generation = _guard.refreshing = ++_guard.generation;
    try {
      final comments = <TaskComment>[];
      var hasMore = false;
      for (var page = 1; page <= pages; page++) {
        final result = await _read(
          taskId,
          page: page,
          newestFirst: value.newestFirst,
        );
        if (generation != _guard.generation) return;
        _perPage = result.perPage;
        final known = {for (final comment in comments) comment.id};
        comments.addAll(
          result.items.where(
            (c) => !known.contains(c.id) && !_deleted.contains(c.id),
          ),
        );
        hasMore = result.hasMore;
      }
      _removed = 0;
      _set(
        value.copyWith(
          comments: comments,
          loadedPages: pages,
          hasMore: hasMore,
          failure: value.failure,
        ),
      );
    } on Object catch (error) {
      _log.fine('Refreshing comments failed: ${error.runtimeType}');
    } finally {
      if (_guard.refreshing == generation) _guard.refreshing = null;
    }
  }

  /// Runs [write], which changes on the server what a change made here
  /// already shows: refreshes wait until it is done.
  Future<T> writing<T>(Future<T> Function() write) => _guard.writing(write);

  /// A comment written here, where the server's order puts it: first when
  /// newest first, last when oldest first, after the pages not read yet,
  /// which are read for it. While the thread is not shown it starts with
  /// the comment when it [wasEmpty], else it is read: its first page when
  /// newest first, every page when oldest first. Stored comments that show
  /// count as not shown.
  Future<void> add(TaskComment comment, {required bool wasEmpty}) async {
    if (!value.shown || value.storedAt != null) {
      if (!wasEmpty) return await _load(1, 1, toEnd: !value.newestFirst);
      _guard.generation++;
      _set(
        CommentsState(
          shown: true,
          newestFirst: value.newestFirst,
          comments: [comment],
          loadedPages: 1,
        ),
      );
      return;
    }
    if (value.comments.any((known) => known.id == comment.id)) return;
    _guard.drop();
    if (value.newestFirst) {
      _set(
        value.copyWith(
          comments: [comment, ...value.comments],
          failure: value.failure,
        ),
      );
    } else if (value.hasMore) {
      await _loadNext(toEnd: true);
    } else {
      final comments = [...value.comments, comment];
      _set(
        value.copyWith(
          comments: comments,
          // A refresh reads the page the comment opened too.
          loadedPages: math.max(
            value.loadedPages,
            (comments.length + _perPage - 1) ~/ _perPage,
          ),
          failure: value.failure,
        ),
      );
    }
  }

  /// An edit's answer carries only the text and the time of the change.
  void applyEdit(TaskComment edited) => _change(
    edited.id,
    (comment) => comment.copyWith(
      html: edited.html,
      updated: edited.updated ?? comment.updated,
    ),
  );

  void setReactions(int commentId, Reactions reactions) =>
      _change(commentId, (comment) => comment.copyWith(reactions: reactions));

  void remove(int commentId) {
    _deleted.add(commentId);
    _noteChange();
    if (!value.comments.any((comment) => comment.id == commentId)) return;
    _guard.drop();
    if (value.hasMore) _removed++;
    _set(
      value.copyWith(
        comments: [
          for (final comment in value.comments)
            if (comment.id != commentId) comment,
        ],
        failure: value.failure,
      ),
    );
  }

  TaskComment? find(int commentId) {
    for (final comment in value.comments) {
      if (comment.id == commentId) return comment;
    }
    return null;
  }

  void _change(int commentId, TaskComment Function(TaskComment) change) {
    if (find(commentId) == null) return;
    _guard.drop();
    _noteChange();
    _set(
      value.copyWith(
        comments: [
          for (final comment in value.comments)
            if (comment.id == commentId) change(comment) else comment,
        ],
        failure: value.failure,
      ),
    );
  }

  /// Pages under way may have been read before a change made here, and the
  /// device may keep none of them; they are read again once they are in.
  void _noteChange() {
    if (value.loading) _changedWhileLoading = true;
  }

  Future<void> _loadNext({bool toEnd = false}) {
    final next = value.loadedPages + 1;
    final behind = (_removed + _perPage - 1) ~/ _perPage;
    return _load(math.max(1, next - behind), next, toEnd: toEnd);
  }

  void _restart() {
    _guard.generation++;
    _removed = 0;
    _changedWhileLoading = false;
  }

  /// Pages [from] to [to], [toEnd] on to the last, appending what is not
  /// shown yet; [from] is below [to] only after deletions, to pick up what
  /// moved onto loaded pages. What changed here meanwhile stays as it is.
  /// Before the server's first page the stored comments stand in.
  Future<void> _load(int from, int to, {bool toEnd = false}) async {
    final taskId = _taskId;
    if (taskId == null) return;
    final generation = ++_guard.generation;
    final removedBefore = _removed;
    _set(value.copyWith(loading: true));
    final stored = value.loadedPages == 0 ? _readStored(taskId) : null;
    if (stored != null) {
      unawaited(
        stored.then((stored) {
          if (stored == null ||
              generation != _guard.generation ||
              !value.loading) {
            return;
          }
          _set(
            value.copyWith(
              comments: _inOrder(stored.value),
              storedAt: stored.readAt,
              failure: value.failure,
            ),
          );
        }),
      );
    }
    try {
      final read = <TaskComment>[];
      var hasMore = value.hasMore;
      var last = to;
      for (var page = from; page <= last; page++) {
        final result = await _read(
          taskId,
          page: page,
          newestFirst: value.newestFirst,
        );
        if (generation != _guard.generation) return;
        _perPage = result.perPage;
        read.addAll(result.items);
        hasMore = result.hasMore;
        if (toEnd && page == last && hasMore && result.items.isNotEmpty) {
          last++;
        }
      }
      _removed -= removedBefore;
      final before = value.storedAt == null
          ? value.comments
          : const <TaskComment>[];
      final known = {for (final comment in before) comment.id};
      _set(
        value.copyWith(
          comments: [
            ...before,
            for (final comment in read)
              if (!_deleted.contains(comment.id) && known.add(comment.id))
                comment,
          ],
          shown: true,
          loadedPages: last,
          hasMore: hasMore,
          loading: false,
          storedAt: null,
        ),
      );
      if (_changedWhileLoading) {
        _changedWhileLoading = false;
        _guard
          ..markDue()
          ..refreshIfDue();
      }
    } on Object catch (error) {
      _log.fine('Loading comments failed: ${error.runtimeType}');
      if (generation != _guard.generation) return;
      // Nothing it read was stored, so the change has nothing to correct.
      _changedWhileLoading = false;
      if (keepsStored(error) && stored != null) {
        final kept = await stored;
        if (generation != _guard.generation) return;
        if (kept != null) {
          _set(
            value.copyWith(
              comments: _inOrder(kept.value),
              storedAt: kept.readAt,
              shown: true,
              loading: false,
              hasMore: false,
              failure: error,
            ),
          );
          return;
        }
      }
      _set(
        value.copyWith(
          comments: value.storedAt == null ? null : const [],
          storedAt: null,
          shown: true,
          loading: false,
          failure: error,
        ),
      );
    }
  }

  /// Null when nothing is stored or it cannot be read.
  Future<StoredRead<List<TaskComment>>?> _readStored(int taskId) async {
    final read = _stored;
    if (read == null) return null;
    try {
      return await read(taskId);
    } on Object catch (error) {
      _log.warning('Reading stored comments failed: ${error.runtimeType}');
      return null;
    }
  }

  /// [oldestFirst] in the order shown, without those deleted here.
  List<TaskComment> _inOrder(List<TaskComment> oldestFirst) {
    final kept = [
      for (final comment in oldestFirst)
        if (!_deleted.contains(comment.id)) comment,
    ];
    return value.newestFirst ? kept.reversed.toList() : kept;
  }

  void _set(CommentsState state) {
    if (!_guard.disposed) value = state;
  }

  @override
  void dispose() {
    _guard.dispose();
    super.dispose();
  }
}
