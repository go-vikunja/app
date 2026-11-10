import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_actions.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tree_column.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/due_sections_list.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_failure.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';

final _log = Logger('SmartList');

enum _Action { edit, favourite, delete }

/// A list that is no project, grouped by due date like the Overview: the
/// open favourite tasks from the local database (Favorites, -1), or a saved
/// filter's open tasks (-2 and below), evaluated here from its stored
/// definition, or as of its last download where the device cannot (the
/// definition is unknown, the engine refuses it, or it needs a board). A
/// saved filter's menu edits, favourites and deletes it online.
class SmartListScreen extends ConsumerStatefulWidget {
  const new({required this.pseudoProjectId, super.key});

  final int pseudoProjectId;

  @override
  ConsumerState<SmartListScreen> createState() => _SmartListScreenState();
}

class _SmartListScreenState extends ConsumerState<SmartListScreen>
    with RefreshableList<SmartListScreen>, TaskListActions<SmartListScreen> {
  /// A filter's tasks older than this download again when it opens.
  static const _staleAfter = Duration(minutes: 5);

  var _openingChecked = false;

  /// Whether a quiet download ran since the filter's tasks last showed;
  /// another starts by itself only once they go again.
  var _downloadedWhileMissing = false;
  var _downloading = false;
  Object? _quietFailure;
  var _managing = false;

  bool get _isFavorites => widget.pseudoProjectId == Project.favoritesId;

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  /// Favorites and a filter evaluated here are local; one sync run brings
  /// their changes.
  bool get _isLocal =>
      _isFavorites ||
      ref
              .read(savedFilterTasksProvider(widget.pseudoProjectId))
              .value
              ?.evaluation ==
          FilterEvaluation.local;

  @override
  Future<void>? startRefresh() {
    final repository = ref.read(taskRepositoryProvider);
    return _isLocal
        ? repository?.refreshOpenTasks()
        : repository?.refreshSavedFilter(widget.pseudoProjectId);
  }

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    _quietFailure = null;
  }

  bool _isStale(DateTime loadedAt) =>
      ref.read(clockProvider)().difference(loadedAt) >= _staleAfter;

  /// On opening when the tasks are missing or stale, and again whenever
  /// they go while the filter is still listed (the sync purged them).
  void _downloadWhenNeeded(DateTime? loadedAt, {required bool listed}) {
    final opening = !_openingChecked;
    _openingChecked = true;
    if (loadedAt != null) {
      _downloadedWhileMissing = false;
      if (!opening || !_isStale(loadedAt)) return;
    } else {
      // A filter deleted on the web: the server would only say not found.
      if (_downloadedWhileMissing || !listed) return;
      _downloadedWhileMissing = true;
    }
    if (_downloading || refreshing) return;
    // Within this build, so the empty state says so at once.
    _downloading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshQuietly());
    });
  }

  /// Back online, tasks missing or stale download again: the failure kept
  /// from offline would otherwise promise a download that never comes.
  void _downloadAfterReconnect() {
    if (_downloading || refreshing || _isLocal) return;
    final loadedAt = ref
        .read(savedFilterTasksProvider(widget.pseudoProjectId))
        .value
        ?.loadedAt;
    if (loadedAt != null && !_isStale(loadedAt)) return;
    if (loadedAt == null && _isGone(ref.read(savedFiltersProvider).value)) {
      return;
    }
    setState(() {
      _quietFailure = null;
      if (refreshFailure is NetworkFailure) clearRefreshFailure();
      _downloading = true;
    });
    unawaited(_refreshQuietly());
  }

  /// Offline the banner says so; a failure only picks the words of a
  /// filter never downloaded.
  Future<void> _refreshQuietly() async {
    _downloading = true;
    Object? failure;
    try {
      await ref
          .read(taskRepositoryProvider)
          ?.refreshSavedFilter(widget.pseudoProjectId);
    } on Object catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _quietFailure = failure;
    });
  }

  SavedFilterRef? _filterIn(List<SavedFilterRef> filters) => filters
      .where((filter) => filter.projectId == widget.pseudoProjectId)
      .firstOrNull;

  /// No longer listed by the last sync: deleted on the web. Null [filters]
  /// are still loading.
  bool _isGone(List<SavedFilterRef>? filters) =>
      filters != null && _filterIn(filters) == null;

  String _title(AppLocalizations l10n, List<SavedFilterRef>? filters) {
    if (_isFavorites) return l10n.projectFavouritesTitle;
    // Not the generic title for the moment the filters take to load.
    if (filters == null) return '';
    final filter = _filterIn(filters);
    if (filter == null) return l10n.savedFilterUnknownTitle;
    return projectDisplayTitle(l10n, filter.title, projectId: filter.projectId);
  }

  /// One change at a time, said in a snackbar once the server took it, or
  /// why it did not.
  Future<bool> _manage(String done, Future<void> Function() send) async {
    if (_managing) return false;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _managing = true);
    try {
      await send();
      unawaited(HapticFeedback.selectionClick());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      return true;
    } on Object catch (error) {
      _log.warning('Changing a saved filter failed: ${error.runtimeType}');
      unawaited(HapticFeedback.heavyImpact());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(savedFilterFailureText(l10n, error, fromForm: false)),
          ),
        );
      return false;
    } finally {
      if (mounted) setState(() => _managing = false);
    }
  }

  Future<void> _onAction(_Action action, SavedFilterRef filter) async {
    final repository = ref.read(savedFilterRepositoryProvider);
    if (repository == null) return;
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    switch (action) {
      case _Action.edit:
        unawaited(router.push(AppRoutes.savedFilterEdit(filter.projectId)));
      case _Action.favourite:
        final favourite = !filter.isFavorite;
        await _manage(
          favourite ? l10n.projectFavourited : l10n.projectUnfavourited,
          () => repository.setFavorite(filter.projectId, favorite: favourite),
        );
      case _Action.delete:
        final confirmed = await confirmAdaptive(
          context,
          title: l10n.savedFilterDeleteTitle(
            projectDisplayTitle(
              l10n,
              filter.title,
              projectId: filter.projectId,
            ),
          ),
          body: l10n.savedFilterDeleteBody,
          confirmLabel: l10n.projectDelete,
          destructive: true,
        );
        if (!confirmed || !mounted) return;
        final deleted = await _manage(
          l10n.savedFilterDeleted,
          () => repository.delete(filter.projectId),
        );
        if (deleted) router.go(AppRoutes.projects);
    }
  }

  Widget _menu(AppLocalizations l10n, SavedFilterRef filter) {
    if (_managing) {
      return SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              semanticsLabel: l10n.projectSaving,
            ),
          ),
        ),
      );
    }
    return PopupMenuButton<_Action>(
      tooltip: l10n.moreActions,
      onSelected: (action) => unawaited(_onAction(action, filter)),
      itemBuilder: (context) => [
        projectMenuItem(
          _Action.edit,
          icon: Icons.edit_outlined,
          label: l10n.projectEdit,
        ),
        projectMenuItem(
          _Action.favourite,
          icon: filter.isFavorite ? Icons.star : Icons.star_outline,
          label: filter.isFavorite
              ? l10n.projectRemoveFromFavourites
              : l10n.projectAddToFavourites,
        ),
        projectMenuItem(
          _Action.delete,
          icon: Icons.delete_outline,
          label: l10n.projectDelete,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = _isFavorites ? null : ref.watch(savedFiltersProvider).value;
    if (!_isFavorites) {
      ref.listen(offlineProvider, (previous, next) {
        if (previous != null && next == null) _downloadAfterReconnect();
      });
    }
    final title = _title(l10n, filters);
    final gone = !_isFavorites && _isGone(filters);
    final list = _isFavorites
        ? ref
              .watch(favoriteTasksProvider)
              .whenData((tasks) => SavedFilterTasks(tasks: tasks))
        : ref.watch(savedFilterTasksProvider(widget.pseudoProjectId));
    if (list case AsyncData(:final value)
        when !_isFavorites && value.evaluation == FilterEvaluation.snapshot) {
      _downloadWhenNeeded(value.loadedAt, listed: !gone);
    }
    final listed = filters == null ? null : _filterIn(filters);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectsById = {for (final project in projects) project.id: project};
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final offline = ref.watch(offlineProvider) != null;
    final downloadFailure = refreshFailure ?? _quietFailure;

    return Scaffold(
      appBar: AppBar(
        // The tree beside it is where to go next; back still goes back.
        automaticallyImplyLeading: !ProjectTreeColumnScope.shownOf(context),
        title: ScreenTitle(title),
        actions: [
          RefreshButton(onPressed: refreshing ? null : refresh),
          if (listed != null) _menu(l10n, listed),
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // A page over the shell finds the heroes of every tab's top route.
        heroTag: null,
        onPressed: () => unawaited(showNewTaskSheet(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTask),
      ),
      body: buildRefreshable(
        list,
        loadingLabel: l10n.projectTasksLoading,
        maxWidth: ReadableWidth.list,
        builder: (value, notice) {
          final loadedAt = value.loadedAt;
          final local = value.evaluation == FilterEvaluation.local;
          return DueSectionsList(
            sections: groupTasksByDueDate(withLeavingTasks(value.tasks), now),
            projectsById: projectsById,
            pendingIds: pendingIds,
            now: now,
            minimumPriority: minimumPriority,
            header: stackedNotes([
              ?notice,
              if (!local && loadedAt != null)
                ListNote(
                  icon: Icons.filter_list,
                  text: l10n.smartListFilterNotice(
                    formatRelativeTime(
                      l10n,
                      // The tick may lag behind a download just finished.
                      loadedAt.isAfter(now) ? now : loadedAt,
                      now: now,
                    ),
                  ),
                ),
            ]),
            emptyState: switch ((_isFavorites, loadedAt)) {
              (true, _) => EmptyState(
                icon: Icons.star_outline,
                title: l10n.favoritesEmptyTitle,
                body: l10n.favoritesEmptyBody,
              ),
              _ when local => EmptyState(
                icon: Icons.task_alt,
                title: l10n.overviewEmptyTitle,
                body: l10n.overviewFilterEmptyBody(title),
              ),
              (false, null) when gone => EmptyState(
                icon: Icons.filter_list_off,
                title: l10n.smartListFilterGoneTitle,
                body: l10n.smartListFilterGoneBody,
              ),
              (false, null) when offline || downloadFailure is NetworkFailure =>
                EmptyState(
                  icon: Icons.cloud_download_outlined,
                  title: l10n.overviewFilterNotLoadedTitle,
                  body: l10n.smartListFilterNotLoadedBody(title),
                ),
              (false, null) when downloadFailure != null => EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l10n.smartListFilterDownloadFailedTitle,
                body: l10n.smartListFilterDownloadFailedBody(title),
              ),
              // A download runs or has just finished, its tasks about to
              // show; without one, this build started one.
              (false, null) => EmptyState(
                icon: Icons.cloud_download_outlined,
                title: l10n.smartListFilterDownloadingTitle,
                body: l10n.smartListFilterDownloadingBody(title),
              ),
              (false, _) => EmptyState(
                icon: Icons.task_alt,
                title: l10n.overviewEmptyTitle,
                body: l10n.overviewFilterEmptyBody(title),
              ),
            },
            onDoneChanged: (task, {required done}) =>
                unawaited(setTaskDone(task, done: done)),
            onFavoriteChanged: (task, {required favorite}) =>
                unawaited(setTaskFavorite(task, favorite: favorite)),
          );
        },
      ),
    );
  }
}
