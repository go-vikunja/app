import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_content.dart';

/// The downloads of a project's views: the refresh the user starts, and
/// quiet ones beside it for a view that has a download, once when it opens
/// stale, shortly after its own queued moves left the queue, and back
/// online. A quiet download's failure is kept by view; it is not the
/// user's to handle and only picks the words of a view never downloaded.
mixin ProjectViewDownloads<W extends ConsumerStatefulWidget>
    on RefreshableList<W> {
  /// A view's tasks and positions older than this download again when the
  /// view opens.
  static const _staleAfter = Duration(minutes: 5);

  /// After the view's own moves were sent, it downloads again this much
  /// later, so the server's positions (spread apart where equal, or all
  /// recalculated) and the board's done column effects show.
  static const _afterQueuedSent = Duration(seconds: 2);

  int? _queuedIn;
  Set<int> _queuedIds = const {};
  Timer? _afterQueued;
  final _quietlyRefreshed = <int>{};
  final _quietlyRefreshing = <int>{};
  final _quietFailures = <int, Object>{};

  int get projectId;

  /// The view chosen, which shows once it has loaded.
  int get currentViewId;
  bool get currentViewIsBoard;

  /// What the screen showed last: of the view chosen or, while that one
  /// loads, of the one before.
  ProjectViewContent? get lastShownContent;

  @override
  Future<void>? startRefresh() =>
      _download(currentViewId, board: currentViewIsBoard, inNewRun: true);

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    _quietFailures.clear();
    _queuedIn = null;
    _queuedIds = const {};
    _afterQueued?.cancel();
  }

  @override
  void dispose() {
    _afterQueued?.cancel();
    super.dispose();
  }

  /// What failed: the refresh the user started on this screen, which a
  /// view picked in the tabs clears, else [viewId]'s last quiet download.
  Object? downloadFailureOf(int viewId) =>
      refreshFailure ?? _quietFailures[viewId];

  /// [inNewRun] for a refresh the user started; the quiet ones join a sync
  /// under way.
  Future<void>? _download(
    int viewId, {
    required bool board,
    bool inNewRun = false,
  }) {
    final repository = ref.read(taskRepositoryProvider);
    return board
        ? repository?.refreshBoard(projectId, viewId, inNewRun: inNewRun)
        : repository?.refreshProjectList(
            projectId,
            viewId: viewId,
            inNewRun: inNewRun,
          );
  }

  bool _isStale(DateTime? loadedAt) =>
      loadedAt == null ||
      ref.read(clockProvider)().difference(loadedAt) >= _staleAfter;

  /// Only for a view that has a download: a list view's snapshot, a
  /// board, or a table or Gantt view whose filter the device cannot
  /// evaluate.
  void refreshWhenStale(
    ProjectView? view,
    DateTime? loadedAt, {
    required bool board,
  }) {
    final viewId = view?.id ?? 0;
    if (viewId == 0 || !(board || downloadsSnapshot(view!))) return;
    if (!_quietlyRefreshed.add(viewId)) return;
    if (!_isStale(loadedAt)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshQuietly(viewId, board: board));
    });
  }

  /// Shortly after one of the view's own queued moves (the board's
  /// placements, the list's positions; by task id) left the queue (sent or
  /// discarded), and no other one meanwhile, the view downloads again; one
  /// that stays queued, failed, holds back nothing.
  void followQueued(int viewId, Set<int>? queued, {required bool board}) {
    if (queued == null) return;
    final before = _queuedIn == viewId ? _queuedIds : const <int>{};
    _queuedIn = viewId;
    _queuedIds = queued;
    if (before.every(queued.contains)) return;
    _afterQueued?.cancel();
    _afterQueued = Timer(_afterQueuedSent, () {
      _afterQueued = null;
      if (mounted && currentViewIsBoard == board && currentViewId == viewId) {
        unawaited(_refreshQuietly(viewId, board: board));
      }
    });
  }

  /// Back online, the view shown downloads again when it failed offline or
  /// is missing or stale: its failure would otherwise promise a download
  /// that never comes.
  void refreshAfterReconnect() {
    final viewId = currentViewId;
    if (!_quietlyRefreshed.contains(viewId) ||
        _quietlyRefreshing.contains(viewId) ||
        refreshing) {
      return;
    }
    final shown = lastShownContent;
    final stale =
        shown != null && shown.view?.id == viewId && _isStale(shown.loadedAt);
    if (!stale && !_quietFailures.containsKey(viewId)) return;
    setState(() {
      _quietFailures.remove(viewId);
      if (refreshFailure is NetworkFailure) clearRefreshFailure();
    });
    unawaited(_refreshQuietly(viewId, board: currentViewIsBoard));
  }

  /// Offline the list shows the local data with the offline notice; a
  /// failure here is not the user's to handle, it only picks the words of
  /// a view never downloaded.
  Future<void> _refreshQuietly(int viewId, {required bool board}) async {
    if (!_quietlyRefreshing.add(viewId)) return;
    try {
      await _download(viewId, board: board);
    } on Object catch (error) {
      if (mounted) setState(() => _quietFailures[viewId] = error);
    } finally {
      _quietlyRefreshing.remove(viewId);
    }
  }
}
