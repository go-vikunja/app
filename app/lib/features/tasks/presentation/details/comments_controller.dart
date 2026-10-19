import 'dart:async';

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
/// settings name until the user turns it for this sheet.
final class CommentsController extends ValueNotifier<CommentsState> {
  new({required this._read}) : super(const CommentsState());

  final CommentPageReader _read;
  int? _taskId;
  int _generation = 0;
  bool _orderChosen = false;
  bool _disposed = false;

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
    _generation++;
    _set(CommentsState(newestFirst: value.newestFirst));
  }

  /// "Show comments" stays where it is while the first page loads, so
  /// a screen reader keeps its focus there.
  Future<void> show() async {
    if (value.shown || value.loading) return;
    await _loadPage(1);
  }

  Future<void> loadMore() async {
    if (value.loading || !value.shown) return;
    await _loadPage(value.loadedPages + 1);
  }

  /// Retries the page that failed.
  Future<void> retry() => _loadPage(value.loadedPages + 1);

  Future<void> toggleOrder() async {
    _orderChosen = true;
    _generation++;
    _set(CommentsState(shown: value.shown, newestFirst: !value.newestFirst));
    if (value.shown) await _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    final taskId = _taskId;
    if (taskId == null) return;
    final generation = ++_generation;
    _set(value.copyWith(loading: true));
    try {
      final result = await _read(
        taskId,
        page: page,
        newestFirst: value.newestFirst,
      );
      if (generation != _generation) return;
      final known = {for (final comment in value.comments) comment.id};
      _set(
        value.copyWith(
          comments: [
            ...value.comments,
            ...result.items.where((comment) => !known.contains(comment.id)),
          ],
          shown: true,
          loadedPages: page,
          hasMore: result.hasMore,
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
