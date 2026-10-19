import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// A list that is no project, grouped by due date like the Overview: the
/// open favourite tasks from the local database (Favorites, -1), or a saved
/// filter's open tasks as of its last download (-2 and below), which the
/// device cannot evaluate itself yet.
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

  bool get _isFavorites => widget.pseudoProjectId == Project.favoritesId;

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  // Favorites are local; one sync run brings their changes.
  @override
  Future<void>? startRefresh() {
    final repository = ref.read(taskRepositoryProvider);
    return _isFavorites
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
    if (_downloading || refreshing) return;
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
    if (list case AsyncData(:final value) when !_isFavorites) {
      _downloadWhenNeeded(value.loadedAt, listed: !gone);
    }
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
        title: Text(title),
        actions: [RefreshButton(onPressed: refreshing ? null : refresh)],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton(
        // A page over the shell finds the heroes of every tab's top route.
        heroTag: null,
        onPressed: () => unawaited(showNewTaskSheet(context)),
        tooltip: l10n.newTask,
        child: const Icon(Icons.add),
      ),
      body: buildRefreshable(
        list,
        loadingLabel: l10n.projectTasksLoading,
        builder: (value, notice) {
          final loadedAt = value.loadedAt;
          return _Sections(
            sections: groupTasksByDueDate(withLeavingTasks(value.tasks), now),
            projectsById: projectsById,
            pendingIds: pendingIds,
            now: now,
            minimumPriority: minimumPriority,
            header: stackedNotes([
              ?notice,
              if (loadedAt != null)
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

class _Sections extends StatelessWidget {
  const new({
    required this.sections,
    required this.projectsById,
    required this.pendingIds,
    required this.now,
    required this.minimumPriority,
    required this.header,
    required this.emptyState,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final List<DueSection> sections;
  final Map<int, Project> projectsById;
  final Set<int> pendingIds;
  final DateTime now;
  final int minimumPriority;
  final Widget? header;
  final Widget emptyState;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (sections.isEmpty) {
      return CenteredScrollView(header: header, child: emptyState);
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header case final header?) NoticeSliver(notice: header),
        for (final section in sections) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(
              title: _sectionTitle(l10n, section.group),
              count: section.tasks.length,
            ),
          ),
          SliverList.builder(
            itemCount: section.tasks.length,
            itemBuilder: (context, index) {
              final task = section.tasks[index];
              final project = projectsById[task.projectId];
              // The server refuses changes to the tasks of an archived
              // project, which a saved filter can list.
              final archived = isArchivedInTree(task.projectId, projectsById);
              return TaskRow(
                key: ValueKey(task.id),
                task: task,
                now: now,
                minimumPriority: minimumPriority,
                projectTitle: project?.displayTitle(l10n),
                projectColor: parseHexColor(project?.hexColor ?? ''),
                pending: pendingIds.contains(task.id),
                onTap: () => unawaited(showTaskDetail(context, task: task)),
                onDoneChanged: archived
                    ? null
                    : (done) => onDoneChanged(task, done: done),
                onFavoriteChanged: archived
                    ? null
                    : (favorite) => onFavoriteChanged(task, favorite: favorite),
              );
            },
          ),
        ],
        // Room for the floating action button below the last row.
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
        ),
      ],
    );
  }

  static String _sectionTitle(AppLocalizations l10n, DueGroup group) =>
      switch (group) {
        DueGroup.overdue => l10n.sectionOverdue,
        DueGroup.today => l10n.sectionToday,
        DueGroup.nextSevenDays => l10n.sectionNextSevenDays,
        DueGroup.later => l10n.sectionLater,
        DueGroup.noDueDate => l10n.sectionNoDueDate,
      };
}
