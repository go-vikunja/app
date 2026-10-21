import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

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

  CommentsState copyWith({
    bool? shown,
    bool? newestFirst,
    List<TaskComment>? comments,
    int? loadedPages,
    bool? hasMore,
    bool? loading,
    Object? failure,
  }) => CommentsState(
    shown: shown ?? this.shown,
    newestFirst: newestFirst ?? this.newestFirst,
    comments: comments ?? this.comments,
    loadedPages: loadedPages ?? this.loadedPages,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    failure: failure,
  );
}

typedef CommentPageReader = Future<Page<TaskComment>> Function(
  int taskId, {
  required int page,
  required bool newestFirst,
});

/// A task's comments on demand, a page at a time, in the order the user's
/// settings name until the user turns it for this sheet. Comments written,
/// edited or deleted here apply at once; the server pages by offset, so a
/// deletion makes the next "Load more" read the last loaded page again to
/// skip nothing. A refresh under way when such a change comes may have
/// read the server before it, so it is dropped and read again once
/// [writing] has nothing pending.
final class CommentsController extends ValueNotifier<CommentsState> {
  new({required this._read}) : super(const CommentsState());

  final CommentPageReader _read;
  int? _taskId;
  int _generation = 0;
  int? _refreshing;
  int _writes = 0;
  bool _refreshDue = false;
  bool _orderChosen = false;
  bool _disposed = false;

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
  /// what is shown stays until they arrive and when they fail.
  Future<void> refreshLoaded() async {
    final taskId = _taskId;
    if (taskId == null || value.loadedPages == 0 || value.loading) return;
    if (_writes > 0) {
      _refreshDue = true;
      return;
    }
    final pages = value.loadedPages;
    final generation = _refreshing = ++_generation;
    try {
      final comments = <TaskComment>[];
      var hasMore = false;
      for (var page = 1; page <= pages; page++) {
        final result = await _read(
          taskId,
          page: page,
          newestFirst: value.newestFirst,
        );
        if (generation != _generation) return;
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
      if (_refreshing == generation) _refreshing = null;
    }
  }

  /// Runs [write], which changes on the server what a change made here
  /// already shows: refreshes wait until it is done.
  Future<T> writing<T>(Future<T> Function() write) async {
    _writes++;
    _dropRefresh();
    try {
      return await write();
    } finally {
      _writes--;
      _refreshIfDue();
    }
  }

  /// A comment written here, where the server's order puts it: first when
  /// newest first, last when oldest first once no page is left (a later
  /// page brings it otherwise). While the thread is not shown it starts
  /// with the comment when it [wasEmpty], else its first page is read.
  Future<void> add(TaskComment comment, {required bool wasEmpty}) async {
    if (!value.shown) {
      if (!wasEmpty) return await show();
      _generation++;
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
    _dropRefresh();
    if (value.newestFirst) {
      _set(
        value.copyWith(
          comments: [comment, ...value.comments],
          failure: value.failure,
        ),
      );
    } else if (!value.hasMore) {
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
    if (!value.comments.any((comment) => comment.id == commentId)) return;
    _dropRefresh();
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
    _dropRefresh();
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

  Future<void> _loadNext() {
    final next = value.loadedPages + 1;
    final behind = (_removed + _perPage - 1) ~/ _perPage;
    return _load(math.max(1, next - behind), next);
  }

  void _restart() {
    _generation++;
    _removed = 0;
  }

  void _dropRefresh() {
    if (_refreshing == null || _refreshing != _generation) return;
    _refreshing = null;
    _generation++;
    _refreshDue = true;
    _refreshIfDue();
  }

  void _refreshIfDue() {
    if (_writes > 0 || !_refreshDue || _disposed) return;
    _refreshDue = false;
    unawaited(refreshLoaded());
  }

  /// Pages [from] to [to], appending what is not shown yet; [from] is below
  /// [to] only after deletions, to pick up what moved onto loaded pages.
  /// What changed here meanwhile stays as it is.
  Future<void> _load(int from, int to) async {
    final taskId = _taskId;
    if (taskId == null) return;
    final generation = ++_generation;
    final removedBefore = _removed;
    _set(value.copyWith(loading: true));
    try {
      final read = <TaskComment>[];
      var hasMore = value.hasMore;
      for (var page = from; page <= to; page++) {
        final result = await _read(
          taskId,
          page: page,
          newestFirst: value.newestFirst,
        );
        if (generation != _generation) return;
        _perPage = result.perPage;
        read.addAll(result.items);
        hasMore = result.hasMore;
      }
      _removed -= removedBefore;
      final known = {for (final comment in value.comments) comment.id};
      _set(
        value.copyWith(
          comments: [
            ...value.comments,
            for (final comment in read)
              if (!_deleted.contains(comment.id) && known.add(comment.id))
                comment,
          ],
          shown: true,
          loadedPages: to,
          hasMore: hasMore,
          loading: false,
        ),
      );
    } on Object catch (error) {
      _log.fine('Loading comments failed: ${error.runtimeType}');
      if (generation == _generation) {
        _set(value.copyWith(shown: true, loading: false, failure: error));
      }
    }
  }

  void _set(CommentsState state) {
    if (!_disposed) value = state;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
