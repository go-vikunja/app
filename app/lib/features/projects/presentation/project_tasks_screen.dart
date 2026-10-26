import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/core/time/today_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';
import 'package:vikunja_mobile/features/projects/application/list_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/application/table_model.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_actions.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_table_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/projects/presentation/table_columns_sheet.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/project_timeline_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/timeline/timeline_controls.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';

enum _Action {
  refresh,
  edit,
  views,
  share,
  duplicate,
  archive,
  unarchive,
  follow,
  newSubproject,
  favourite,
  delete,
}

/// What the view was last built from (a [ProjectListSource] or a
/// [BoardSource]), kept on screen while another view or its preferences
/// load.
typedef _Shown = ({
  Object? repository,
  Object source,
  ViewFilterKind kind,
  ProjectView? view,
  ViewPreferences preferences,
});

/// A project's views from the local database, each kind with its own
/// controls and body. A list view has the web's subtask nesting and sort,
/// the view's own filter where the device can evaluate it and the server's
/// last answer where it cannot; a table view lists the same tasks flat with
/// the chosen columns and the web table's sort; a Gantt view is a timeline
/// of the tasks in its range; a kanban view is a board as of its last
/// download with this device's changes on top. Table and Gantt views
/// download nothing unless the device cannot evaluate their filter. An
/// archived project says so and offers no new task, as the server refuses
/// changes to it; a project the user may only read says that and offers
/// nothing it would refuse. The menu manages the project as the web's
/// does; a project that disappears once seen says it is gone.
class ProjectTasksScreen extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends ConsumerState<ProjectTasksScreen>
    with
        RefreshableList<ProjectTasksScreen>,
        TaskListActions<ProjectTasksScreen>,
        ProjectManagementActions<ProjectTasksScreen> {
  /// A view's tasks and positions older than this download again when the
  /// view opens.
  static const _staleAfter = Duration(minutes: 5);

  /// After the view's own moves were sent, it downloads again this much
  /// later, so the server's positions (spread apart where equal, or all
  /// recalculated) and the board's done column effects show.
  static const _afterQueuedSent = Duration(seconds: 2);

  /// Room after the last item of a board's column, to scroll it clear of
  /// the floating action button.
  static const _fabRoom = 80.0;

  late final _follow = FollowController(
    entity: SubscriptionEntity.project,
    read: (id) => _subscriptions().forProject(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setProjectSubscribed(id, subscribed: subscribed),
  );

  var _rememberedLoaded = false;
  var _seen = false;
  int? _rememberedViewId;
  int? _chosenViewId;
  var _viewId = 0;
  ProjectViewKind _viewKind = ProjectViewKind.list;
  int? _queuedIn;
  Set<int> _queuedIds = const {};
  Timer? _afterQueued;
  final _quietlyRefreshed = <int>{};
  final _quietlyRefreshing = <int>{};
  final _quietFailures = <int, Object>{};
  _Shown? _lastShown;

  // The chips move between the list and its loading and failure states,
  // so the tapped one keeps its focus.
  final GlobalKey _controlsKey = GlobalKey();

  /// Saved filters show as projects with ids below zero; nobody follows
  /// them.
  bool get _followable => widget.projectId > 0;

  bool get _showsBoard => _viewKind == ProjectViewKind.kanban;

  @override
  void initState() {
    super.initState();
    if (_followable && !ref.read(activeAccountIsGuestProvider)) {
      unawaited(_follow.load(widget.projectId));
    }
    unawaited(_loadRememberedView());
  }

  @override
  void dispose() {
    _afterQueued?.cancel();
    _follow.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedView() async {
    int? remembered;
    try {
      remembered = await ref
          .read(listPreferencesProvider)
          ?.lastViewOf(widget.projectId);
    } on Object {
      remembered = null;
    }
    if (!mounted) return;
    setState(() {
      _rememberedViewId = remembered;
      _rememberedLoaded = true;
    });
  }

  SubscriptionRepository _subscriptions() =>
      ref.read(subscriptionRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  Future<void>? startRefresh() => _download(_viewId, board: _showsBoard);

  Future<void>? _download(int viewId, {required bool board}) {
    final repository = ref.read(taskRepositoryProvider);
    return board
        ? repository?.refreshBoard(widget.projectId, viewId)
        : repository?.refreshProjectList(widget.projectId, viewId: viewId);
  }

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    _quietFailures.clear();
    _lastShown = null;
    _queuedIn = null;
    _queuedIds = const {};
    _afterQueued?.cancel();
  }

  static DateTime? _loadedAtOf(Object source) => switch (source) {
    BoardSource(:final loadedAt) => loadedAt,
    ProjectListSource(:final snapshot) => snapshot.loadedAt,
    _ => null,
  };

  bool _isStale(DateTime? loadedAt) =>
      loadedAt == null ||
      ref.read(clockProvider)().difference(loadedAt) >= _staleAfter;

  /// Only for a view that has a download: a list view's snapshot, a
  /// board, or a table or Gantt view whose filter the device cannot
  /// evaluate.
  void _refreshWhenStale(
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
  void _followQueued(int viewId, Set<int>? queued, {required bool board}) {
    if (queued == null) return;
    final before = _queuedIn == viewId ? _queuedIds : const <int>{};
    _queuedIn = viewId;
    _queuedIds = queued;
    if (before.every(queued.contains)) return;
    _afterQueued?.cancel();
    _afterQueued = Timer(_afterQueuedSent, () {
      _afterQueued = null;
      if (mounted && _showsBoard == board && _viewId == viewId) {
        unawaited(_refreshQuietly(viewId, board: board));
      }
    });
  }

  /// Back online, the view shown downloads again when it failed offline or
  /// is missing or stale: its failure would otherwise promise a download
  /// that never comes.
  void _refreshAfterReconnect() {
    final viewId = _viewId;
    if (!_quietlyRefreshed.contains(viewId) ||
        _quietlyRefreshing.contains(viewId) ||
        refreshing) {
      return;
    }
    final shown = _lastShown;
    final stale =
        shown != null &&
        shown.view?.id == viewId &&
        _isStale(_loadedAtOf(shown.source));
    if (!stale && !_quietFailures.containsKey(viewId)) return;
    setState(() {
      _quietFailures.remove(viewId);
      if (refreshFailure is NetworkFailure) clearRefreshFailure();
    });
    unawaited(_refreshQuietly(viewId, board: _showsBoard));
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

  void _selectView(int viewId) {
    if (viewId == _viewId) return;
    unawaited(
      ref.read(listPreferencesProvider)?.rememberView(widget.projectId, viewId),
    );
    setState(() {
      _chosenViewId = viewId;
      clearRefreshFailure();
      clearLeavingTasks();
    });
  }

  void _savePreferences(String listKey, ViewPreferences preferences) =>
      unawaited(
        ref.read(listPreferencesProvider)?.saveView(listKey, preferences),
      );

  Future<void> _chooseTableSort(
    String listKey,
    ViewPreferences current, {
    required Set<TableColumn> columns,
    required Set<TableColumn> storedColumns,
  }) async {
    final l10n = context.l10n;
    final applied = current.tableSort.forColumns(columns);
    final sort = await showOptionSheet<TableSort>(
      context,
      title: l10n.projectSort,
      options: [
        for (final sort in tableSortsInMenuOrder)
          SheetOption(
            value: sort,
            label: sort.isDefault
                ? l10n.projectTableSortDefault
                : tableSortLabel(l10n, sort),
            selected: sort == applied,
          ),
      ],
    );
    if (sort == null || !mounted) return;
    _savePreferences(listKey, current.copyWith(tableSort: sort));
    // Only a shown column sorts the table, so the chosen one shows.
    if (sort.forColumns(columns) != sort) {
      final column = TableColumn.values.firstWhere(
        (column) => column.sortField == sort.field,
      );
      unawaited(
        ref.read(listPreferencesProvider)?.saveTableColumns({
          ...storedColumns,
          column,
        }),
      );
    }
  }

  Future<void> _chooseTableColumns(Set<TableColumn> current) =>
      showTableColumnsSheet(
        context,
        columns: current,
        onChanged: (columns) => unawaited(
          ref.read(listPreferencesProvider)?.saveTableColumns(columns),
        ),
      );

  Future<void> _chooseSort(String listKey, ViewPreferences current) async {
    final l10n = context.l10n;
    final sort = await showOptionSheet<TaskListSort>(
      context,
      title: l10n.projectSort,
      options: [
        for (final sort in sortsInMenuOrder(l10n))
          SheetOption(
            value: sort,
            label: sortLabel(l10n, sort),
            selected: sort == current.sort,
          ),
      ],
    );
    if (sort == null || !mounted) return;
    _savePreferences(listKey, current.copyWith(sort: sort));
  }

  void _toggleShowDone(String listKey, ViewPreferences current) {
    _savePreferences(listKey, current.copyWith(showDone: !current.showDone));
    setState(() {
      clearRefreshFailure();
      clearLeavingTasks();
    });
  }

  Future<void> _toggleFollow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final titles = {
      for (final project in ref.read(projectsProvider).value ?? <Project>[])
        project.id: project.displayTitle(l10n),
    };
    final before = _follow.value;
    final message = await toggleFollowing(
      context,
      _follow,
      id: widget.projectId,
      projectTitle: (id) => titles[id] ?? l10n.projectUnknownTitle,
    );
    if (!mounted) return;
    final text =
        message ??
        switch ((before, _follow.value)) {
          (FollowKnown(following: false), FollowKnown(following: true)) =>
            l10n.projectFollowed,
          (FollowKnown(following: true), FollowKnown(following: false)) =>
            l10n.projectUnfollowed,
          _ => null,
        };
    if (text == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(offlineProvider, (previous, next) {
      if (previous != null && next == null) _refreshAfterReconnect();
    });
    // Not projectByIdProvider: a change of the views alone must show.
    final projects = ref.watch(projectsProvider);
    final projectsById = {
      for (final project in projects.value ?? const <Project>[])
        project.id: project,
    };
    final project = projectsById[widget.projectId];
    if (project != null) _seen = true;
    if (_seen && project == null && projects.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.projectUnknownTitle)),
        body: CenteredScrollView(
          child: EmptyState(
            icon: Icons.search_off,
            title: l10n.projectGoneTitle,
            body: l10n.projectGoneBody,
          ),
        ),
      );
    }
    final views = shownViewsOf(project);
    final viewId = _viewId = resolveViewId(
      views,
      remembered: _chosenViewId ?? _rememberedViewId,
      defaultKind: ref.watch(
        userSettingsProvider.select(
          (settings) => settings.value?.defaultViewKind,
        ),
      ),
    );
    final view = views.where((view) => view.id == viewId).firstOrNull;
    final viewKind = _viewKind = view?.kind ?? ProjectViewKind.list;
    final board = viewKind == ProjectViewKind.kanban;
    final kind = view == null
        ? ViewFilterKind.openOnly
        : classifyViewFilter(view.filter);
    final listKey = listKeyFor(projectId: widget.projectId, viewId: viewId);
    final preferencesValue = board
        ? const AsyncData(ViewPreferences())
        : ref.watch(viewPreferencesProvider(listKey));
    final preferences = preferencesValue.value ?? const ViewPreferences();
    final columnsValue = viewKind == ProjectViewKind.table
        ? ref.watch(tableColumnsProvider)
        : const AsyncData(TableColumn.defaults);
    final storedColumns = columnsValue.value ?? TableColumn.defaults;
    // Every row shows its title, whatever the stored choice says.
    final columns = {...storedColumns, TableColumn.title};
    final AsyncValue<Object> source;
    switch (viewKind) {
      case ProjectViewKind.kanban:
        final boardSource = boardSourceProvider(widget.projectId, viewId);
        ref.listen(
          boardSource,
          (_, next) => _followQueued(
            viewId,
            next.value?.queued.keys.toSet(),
            board: true,
          ),
        );
        source = ref.watch(boardSource);
      case ProjectViewKind.gantt:
        final timeline = preferences.timeline;
        source = ref.watch(
          timelineSourceProvider(
            widget.projectId,
            viewId: viewId,
            range: timeline.range(ref.watch(todayProvider)),
            withoutDates: timeline.withoutDates,
          ),
        );
      case ProjectViewKind.table:
        source = ref.watch(
          projectListSourceProvider(
            widget.projectId,
            viewId: viewId,
            includeDone: showsDoneTasks(kind, preferences),
          ),
        );
      case ProjectViewKind.list:
        final listSource = projectListSourceProvider(
          widget.projectId,
          viewId: viewId,
          includeDone: showsDoneTasks(kind, preferences),
        );
        ref.listen(
          listSource,
          (_, next) => _followQueued(
            viewId,
            next.value?.queuedPositions.keys.toSet(),
            board: false,
          ),
        );
        source = ref.watch(listSource);
    }
    final repository = ref.watch(taskRepositoryProvider);
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final offline = ref.watch(offlineProvider) != null;
    final archived = isArchivedInTree(widget.projectId, projectsById);
    final access = ref.watch(projectAccessProvider(widget.projectId));
    // The server ignores a guest's favourites and refuses its
    // subscriptions; the project is the owner's to rename, archive, copy,
    // share, set up views for or delete, whatever the share's permission.
    final guest = ref.watch(activeAccountIsGuestProvider);
    final defaultProjectId = ref.watch(
      userSettingsProvider.select(
        (settings) => settings.value?.defaultProjectId,
      ),
    );
    // Until then the view shown may still change.
    final ready =
        _rememberedLoaded &&
        !(projects.isLoading && !projects.hasValue) &&
        !(preferencesValue.isLoading && !preferencesValue.hasValue) &&
        !(columnsValue.isLoading && !columnsValue.hasValue);
    final current = ready ? source : const AsyncLoading<Object>();
    final lastShown = _lastShown;
    final AsyncValue<Object> shownData;
    switch (current) {
      // Not while a failed load is retried: the rows of another view would
      // pass for this one's.
      case AsyncLoading(hasError: false)
          when lastShown != null && identical(lastShown.repository, repository):
        shownData = AsyncData(lastShown.source);
      case AsyncValue(:final value?) when current is! AsyncLoading:
        _lastShown = (
          repository: repository,
          source: value,
          kind: kind,
          view: view,
          preferences: preferences,
        );
        _refreshWhenStale(view, _loadedAtOf(value), board: board);
        shownData = current;
      default:
        shownData = current;
    }
    final tabs = views.length > 1
        ? ProjectViewTabs(
            views: views,
            selectedId: viewId,
            onSelected: _selectView,
          )
        : null;
    final onShowDoneChanged = kind == ViewFilterKind.openOnly
        ? () => _toggleShowDone(listKey, preferences)
        : null;
    final listControls = switch (viewKind) {
      ProjectViewKind.list => ProjectListControls(
        key: _controlsKey,
        sort: preferences.sort,
        onSort: () => unawaited(_chooseSort(listKey, preferences)),
        showDone: preferences.showDone,
        onShowDoneChanged: onShowDoneChanged,
      ),
      ProjectViewKind.table => ProjectTableControls(
        key: _controlsKey,
        sortLabel: tableSortLabel(
          l10n,
          preferences.tableSort.forColumns(columns),
        ),
        onSort: () => unawaited(
          _chooseTableSort(
            listKey,
            preferences,
            columns: columns,
            storedColumns: storedColumns,
          ),
        ),
        onColumns: () => unawaited(_chooseTableColumns(columns)),
        showDone: preferences.showDone,
        onShowDoneChanged: onShowDoneChanged,
      ),
      ProjectViewKind.gantt => ProjectTimelineControls(
        key: _controlsKey,
        viewId: viewId,
        listKey: listKey,
        preferences: preferences,
      ),
      ProjectViewKind.kanban => null,
    };
    final progress = _followable && ProjectAppBarBottom.showsProgressIn(context)
        ? ref.watch(projectProgressProvider(widget.projectId)).value
        : null;
    final downloadFailure = refreshFailure ?? _quietFailures[viewId];
    final offlineOrUnreachable = offline || downloadFailure is NetworkFailure;
    final downloadFailed =
        downloadFailure != null && downloadFailure is! NetworkFailure;
    final archivedNote = archived
        ? ListNote(icon: Icons.archive_outlined, text: l10n.projectArchivedNote)
        : access.isReadOnly && _followable
        ? ListNote(
            icon: Icons.visibility_outlined,
            text: l10n.shareReadOnlyProjectNote,
          )
        : null;
    final addsTasks = !archived && access.canAddTasks;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.displayTitle(l10n) ?? l10n.projectUnknownTitle),
        actions: [
          if (project != null &&
              _followable &&
              !archived &&
              access.canEdit &&
              !guest)
            IconButton(
              onPressed: managingProject
                  ? null
                  : () => unawaited(toggleProjectFavourite(project)),
              tooltip: project.isFavorite
                  ? l10n.projectRemoveFromFavourites
                  : l10n.projectAddToFavourites,
              isSelected: project.isFavorite,
              icon: const Icon(Icons.star_outline),
              selectedIcon: const FilledStar(),
            ),
          if (managingProject)
            SizedBox.square(
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
            )
          else
            PopupMenuButton<_Action>(
              tooltip: l10n.moreActions,
              onSelected: (action) => _onAction(action, project: project),
              itemBuilder: (context) {
                final projectItems = _projectItems(
                  context,
                  project: project,
                  access: access,
                  guest: guest,
                  archived: archived,
                  parentArchived:
                      project != null &&
                      project.parentProjectId != 0 &&
                      isArchivedInTree(project.parentProjectId, projectsById),
                  isDefault: project?.id == defaultProjectId,
                );
                return [
                  // For whoever cannot pull the list, a screen reader among
                  // them.
                  projectMenuItem(
                    _Action.refresh,
                    icon: Icons.refresh,
                    label: l10n.refresh,
                    enabled: !refreshing,
                  ),
                  if (projectItems.isNotEmpty) const PopupMenuDivider(),
                  ...projectItems,
                ];
              },
            ),
        ],
        bottom: ProjectAppBarBottom(
          progress: progress,
          textScaler: MediaQuery.textScalerOf(context),
          tabs: tabs,
        ),
      ),
      floatingActionButton: !addsTasks
          ? null
          : FloatingActionButton.extended(
              onPressed: () => unawaited(
                showNewTaskSheet(context, projectId: widget.projectId),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newTask),
            ),
      body: buildRefreshable(
        shownData,
        loadingLabel: l10n.projectTasksLoading,
        header: listControls,
        // A board's columns and a timeline's rows scroll inside a
        // horizontal scroll.
        notificationPredicate: board || viewKind == ProjectViewKind.gantt
            ? (notification) => notification.metrics.axis == Axis.vertical
            : defaultScrollNotificationPredicate,
        builder: (value, notice) {
          final shown = _lastShown;
          final shownView = shown == null ? view : shown.view;
          if (value is BoardSource) {
            final boardView = shownView ?? value.view;
            if (boardView == null) return const SizedBox.shrink();
            return _BoardBody(
              projectId: widget.projectId,
              view: boardView,
              source: value,
              archived: archived,
              writable: access.canReorderOrBoard,
              canChangeView: access.canManageViews,
              offline: offlineOrUnreachable,
              downloadFailed: downloadFailed,
              notes: [?notice, ?archivedNote],
              now: now,
              minimumPriority: minimumPriority,
              pendingIds: pendingIds,
              bottomPadding: addsTasks ? _fabRoom : 0,
            );
          }
          final list = value as ProjectListSource;
          final shownKind = shown?.kind ?? kind;
          final shownPreferences = shown?.preferences ?? preferences;
          final leaving = leavingTasksIn(list.tasksById);
          final loadedAt = list.snapshot.loadedAt;
          final filterNotice =
              shownKind == ViewFilterKind.other &&
                  list.matchingIds == null &&
                  loadedAt != null
              ? ListNote(
                  icon: Icons.filter_alt_outlined,
                  text: l10n.projectViewFilterNotice(
                    describeViewFilter(shownView?.filter),
                    formatRelativeTime(
                      l10n,
                      // The tick may lag behind a download just finished.
                      loadedAt.isAfter(now) ? now : loadedAt,
                      now: now,
                    ),
                  ),
                )
              : null;
          final header = stackedNotes([
            ?listControls,
            ?notice,
            ?archivedNote,
            ?filterNotice,
          ]);
          switch (shownView?.kind) {
            case ProjectViewKind.table:
              final sort = shownPreferences.tableSort.forColumns(columns);
              return ProjectTableBody(
                projectId: widget.projectId,
                projectsById: projectsById,
                rows: buildTableRows(
                  list,
                  kind: shownKind,
                  showDone: shownPreferences.showDone,
                  compare: (a, b) => compareTasksForTable(a, b, sort),
                  leaving: leaving,
                ),
                columns: columns,
                source: list,
                kind: shownKind,
                view: shownView,
                showDone: shownPreferences.showDone,
                offline: offlineOrUnreachable,
                downloadFailed: downloadFailed,
                header: header,
                now: now,
                minimumPriority: minimumPriority,
                pendingIds: pendingIds,
                onDoneChanged: (task, {required done}) =>
                    unawaited(setTaskDone(task, done: done)),
                onFavoriteChanged: (task, {required favorite}) =>
                    unawaited(setTaskFavorite(task, favorite: favorite)),
              );
            case ProjectViewKind.gantt:
              return ProjectTimelineBody(
                // Collapsed rows belong to one view.
                key: ValueKey(shownView!.id),
                view: shownView,
                source: list,
                preferences: shownPreferences,
                offline: offlineOrUnreachable,
                downloadFailed: downloadFailed,
                header: header,
                bottomPadding: addsTasks ? _fabRoom : 0,
              );
            case ProjectViewKind.list || ProjectViewKind.kanban || null:
              break;
          }
          final model = buildProjectListModel(
            list,
            kind: shownKind,
            preferences: shownPreferences,
            leaving: leaving,
          );
          // Before its first download the view's order is made up.
          final reorderView =
              loadedAt != null &&
                  listIsReorderable(
                    projectId: widget.projectId,
                    view: shownView,
                    sort: shownPreferences.sort,
                    archived: archived,
                    writable: access.canReorderOrBoard,
                  )
              ? shownView
              : null;
          return ProjectListBody(
            projectId: widget.projectId,
            projectsById: projectsById,
            model: model,
            source: list,
            kind: shownKind,
            view: shownView,
            preferences: shownPreferences,
            offline: offlineOrUnreachable,
            downloadFailed: downloadFailed,
            header: header,
            now: now,
            minimumPriority: minimumPriority,
            pendingIds: pendingIds,
            onDoneChanged: (task, {required done}) =>
                unawaited(setTaskDone(task, done: done)),
            onFavoriteChanged: (task, {required favorite}) =>
                unawaited(setTaskFavorite(task, favorite: favorite)),
            leavingIds: leaving.keys.toSet(),
            onReorder: reorderView == null || repository == null
                ? null
                : (positions) => unawaited(() async {
                    for (final MapEntry(key: taskId, value: position)
                        in positions.entries) {
                      await repository.positionTask(
                        taskId,
                        viewId: reorderView.id,
                        position: position,
                      );
                    }
                  }()),
          );
        },
      ),
    );
  }

  void _onAction(_Action action, {required Project? project}) {
    if (action == _Action.refresh) {
      unawaited(refresh());
      return;
    }
    if (action == _Action.follow) {
      unawaited(_toggleFollow());
      return;
    }
    if (project == null) return;
    switch (action) {
      case _Action.edit:
        editProject(project);
      case _Action.views:
        openProjectViews(project);
      case _Action.share:
        openProjectShare(project);
      case _Action.duplicate:
        unawaited(duplicateProject(project));
      case _Action.archive:
        unawaited(setProjectArchived(project, archived: true));
      case _Action.unarchive:
        unawaited(setProjectArchived(project, archived: false));
      case _Action.newSubproject:
        unawaited(createSubproject(project));
      case _Action.favourite:
        unawaited(toggleProjectFavourite(project));
      case _Action.delete:
        unawaited(deleteProject(project));
      case _Action.refresh || _Action.follow:
        break;
    }
  }

  /// The web's project menu, for what the app offers, Follow among them,
  /// in groups, without what [access] does not allow; an archived project
  /// only offers to unarchive it, which waits for its archived parent.
  /// Like the web, the user's default project cannot be archived and offers
  /// no Delete. A [guest] gets none of them: the project is its owner's.
  List<PopupMenuEntry<_Action>> _projectItems(
    BuildContext context, {
    required Project? project,
    required ProjectAccess access,
    required bool guest,
    required bool archived,
    required bool parentArchived,
    required bool isDefault,
  }) {
    if (!_followable) return const [];
    final l10n = context.l10n;
    if (project == null) return [if (!guest) _followItem(l10n)];
    if (archived) {
      return [
        if (access.canArchive && !guest)
          projectMenuItem(
            _Action.unarchive,
            icon: Icons.unarchive_outlined,
            label: l10n.projectUnarchive,
            enabled: !parentArchived,
            hint: parentArchived ? l10n.projectUnarchiveParentFirst : null,
          ),
        if (!guest) _followItem(l10n),
      ];
    }
    final groups = <List<PopupMenuEntry<_Action>>>[
      [
        if (access.canEdit && !guest)
          projectMenuItem(
            _Action.edit,
            icon: Icons.edit_outlined,
            label: l10n.projectEdit,
          ),
        if (access.canManageViews && !guest)
          projectMenuItem(
            _Action.views,
            icon: Icons.view_agenda_outlined,
            label: l10n.projectViews,
          ),
        if (!guest)
          projectMenuItem(
            _Action.share,
            icon: Icons.share_outlined,
            label: l10n.shareMenuItem,
          ),
        // The server takes a favourite as a change of the project.
        if (access.canEdit && !guest)
          projectMenuItem(
            _Action.favourite,
            icon: project.isFavorite ? Icons.star : Icons.star_outline,
            label: project.isFavorite
                ? l10n.projectRemoveFromFavourites
                : l10n.projectAddToFavourites,
          ),
        if (!guest) _followItem(l10n),
      ],
      [
        if (access.canCreateChild && !guest)
          projectMenuItem(
            _Action.newSubproject,
            icon: Icons.create_new_folder_outlined,
            label: l10n.projectNewSubproject,
          ),
        if (access.canDuplicate && !guest)
          projectMenuItem(
            _Action.duplicate,
            icon: Icons.content_copy_outlined,
            label: l10n.projectDuplicate,
          ),
      ],
      [
        if (access.canArchive && !guest)
          projectMenuItem(
            _Action.archive,
            icon: Icons.archive_outlined,
            label: l10n.projectArchive,
            enabled: !isDefault,
            hint: isDefault ? l10n.projectArchiveDefaultHint : null,
          ),
        if (!isDefault && access.canDelete && !guest)
          projectMenuItem(
            _Action.delete,
            icon: Icons.delete_outline,
            label: l10n.projectDelete,
            color: Theme.of(context).colorScheme.error,
          ),
      ],
    ];
    return [
      for (final (index, group)
          in groups.where((g) => g.isNotEmpty).indexed) ...[
        if (index > 0) PopupMenuDivider(key: ValueKey(index)),
        ...group,
      ],
    ];
  }

  /// Labelled by the state the menu opens with: disabled while it is read
  /// or written, as a tap would do nothing; while it is unknown the tap
  /// explains why and loads it again.
  PopupMenuItem<_Action> _followItem(AppLocalizations l10n) {
    final state = _follow.value;
    final following = state is FollowKnown && state.following;
    return PopupMenuItem(
      value: _Action.follow,
      enabled: switch (state) {
        FollowUnknown(:final loading) => !loading,
        FollowKnown(:final saving) => !saving,
      },
      child: Row(
        children: [
          ProjectMenuIcon(
            following
                ? Icons.notifications_off_outlined
                : Icons.notifications_outlined,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(switch (state) {
              FollowUnknown(loading: true) => l10n.followChecking,
              _ when following => l10n.unfollowProject,
              _ => l10n.followProject,
            }),
          ),
        ],
      ),
    );
  }
}

/// A kanban view's body: the board as of its last download, or why there
/// is none yet in the words of a list view never downloaded.
class _BoardBody extends StatelessWidget {
  const new({
    required this.projectId,
    required this.view,
    required this.source,
    required this.archived,
    required this.writable,
    required this.canChangeView,
    required this.offline,
    required this.downloadFailed,
    required this.notes,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.bottomPadding,
  });

  final int projectId;
  final ProjectView view;
  final BoardSource source;
  final bool archived;

  /// The user may change the board: move cards, manage columns.
  final bool writable;

  /// The user may also choose the done and the default column.
  final bool canChangeView;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The board's download failed for a reason other than the connection.
  final bool downloadFailed;
  final List<Widget> notes;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final downloaded = source.loadedAt != null;
    final header = stackedNotes([
      ...notes,
      if (downloaded &&
          view.bucketConfigurationMode == BucketConfigurationMode.filter)
        ListNote(
          icon: Icons.filter_alt_outlined,
          text: l10n.boardFilterColumnsNote,
        ),
    ]);
    if (!downloaded) {
      return CenteredScrollView(
        header: header,
        child: switch ((offline, downloadFailed)) {
          (true, _) => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewNotLoadedTitle,
            body: l10n.boardNotLoadedBody,
          ),
          (_, true) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.projectViewDownloadFailedTitle,
            body: l10n.boardDownloadFailedBody,
          ),
          _ => EmptyState(
            icon: Icons.cloud_download_outlined,
            title: l10n.projectViewDownloadingTitle,
            body: l10n.boardDownloadingBody,
          ),
        },
      );
    }
    if (source.buckets.isEmpty) {
      return CenteredScrollView(
        header: header,
        child: EmptyState(
          icon: Icons.view_kanban_outlined,
          title: l10n.boardNoColumnsTitle,
          body: l10n.boardNoColumnsBody,
        ),
      );
    }
    return ProjectBoard(
      key: ValueKey(view.id),
      projectId: projectId,
      view: view,
      source: source,
      readOnly: boardIsReadOnly(view, archived: archived, writable: writable),
      canChangeView: canChangeView,
      offline: offline,
      now: now,
      minimumPriority: minimumPriority,
      pendingIds: pendingIds,
      header: header,
      bottomPadding: bottomPadding,
    );
  }
}
