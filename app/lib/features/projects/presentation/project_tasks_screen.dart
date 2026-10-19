import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
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
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_labels.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

enum _Action { toggleShowDone, follow }

/// What the list was last built from, kept on screen while another view or
/// its preferences load.
typedef _Shown = ({
  Object? repository,
  ProjectListSource source,
  ViewFilterKind kind,
  ProjectView? view,
  ViewPreferences preferences,
});

/// A project's list views from the local database: the web's subtask
/// nesting and sort, the view's own filter where the device can evaluate
/// it and the server's last answer where it cannot. An archived project
/// says so and offers no new task, as the server refuses changes to it.
class ProjectTasksScreen extends ConsumerStatefulWidget {
  const new({required this.projectId, super.key});

  final int projectId;

  @override
  ConsumerState<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends ConsumerState<ProjectTasksScreen>
    with
        RefreshableList<ProjectTasksScreen>,
        TaskListActions<ProjectTasksScreen> {
  /// A view's tasks and positions older than this download again when the
  /// view opens.
  static const _staleAfter = Duration(minutes: 5);

  late final _follow = FollowController(
    entity: SubscriptionEntity.project,
    read: (id) => _subscriptions().forProject(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setProjectSubscribed(id, subscribed: subscribed),
  );

  var _rememberedLoaded = false;
  int? _rememberedViewId;
  int? _chosenViewId;
  var _viewId = 0;
  final _quietlyRefreshed = <int>{};
  final _quietlyRefreshing = <int>{};
  final _quietFailures = <int, Object>{};
  _Shown? _lastShown;

  // The chips survive the loading and failure states of a view switch, so
  // the tapped one keeps its focus.
  final GlobalKey _switcherKey = GlobalKey();

  /// Saved filters show as projects with ids below zero; nobody follows
  /// them.
  bool get _followable => widget.projectId > 0;

  @override
  void initState() {
    super.initState();
    if (_followable) unawaited(_follow.load(widget.projectId));
    unawaited(_loadRememberedView());
  }

  @override
  void dispose() {
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
  Future<void>? startRefresh() => ref
      .read(taskRepositoryProvider)
      ?.refreshProjectList(widget.projectId, viewId: _viewId);

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    _quietFailures.clear();
    _lastShown = null;
  }

  bool _isStale(ListSnapshot snapshot) {
    final loadedAt = snapshot.loadedAt;
    return loadedAt == null ||
        ref.read(clockProvider)().difference(loadedAt) >= _staleAfter;
  }

  void _refreshWhenStale(int viewId, ListSnapshot snapshot) {
    if (viewId == 0 || !_quietlyRefreshed.add(viewId)) return;
    if (!_isStale(snapshot)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshQuietly(viewId));
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
        _isStale(shown.source.snapshot);
    if (!stale && !_quietFailures.containsKey(viewId)) return;
    setState(() {
      _quietFailures.remove(viewId);
      if (refreshFailure is NetworkFailure) clearRefreshFailure();
    });
    unawaited(_refreshQuietly(viewId));
  }

  /// Offline the list shows the local data with the offline notice; a
  /// failure here is not the user's to handle, it only picks the words of
  /// a view never downloaded.
  Future<void> _refreshQuietly(int viewId) async {
    _quietlyRefreshing.add(viewId);
    try {
      await ref
          .read(taskRepositoryProvider)
          ?.refreshProjectList(widget.projectId, viewId: viewId);
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
    final views = listViewsOf(project);
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
    final kind = view == null
        ? ViewFilterKind.openOnly
        : classifyViewFilter(view.filter);
    final listKey = listKeyFor(projectId: widget.projectId, viewId: viewId);
    final preferencesValue = ref.watch(viewPreferencesProvider(listKey));
    final preferences = preferencesValue.value ?? const ViewPreferences();
    final source = ref.watch(
      projectListSourceProvider(
        widget.projectId,
        viewId: viewId,
        includeDone: showsDoneTasks(kind, preferences),
      ),
    );
    final repository = ref.watch(taskRepositoryProvider);
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final offline = ref.watch(offlineProvider) != null;
    final archived = project?.isArchived ?? false;
    // Until then the view shown may still change.
    final ready =
        _rememberedLoaded &&
        !(projects.isLoading && !projects.hasValue) &&
        !(preferencesValue.isLoading && !preferencesValue.hasValue);
    final current = ready ? source : const AsyncLoading<ProjectListSource>();
    final lastShown = _lastShown;
    final AsyncValue<ProjectListSource> shownData;
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
        _refreshWhenStale(viewId, value.snapshot);
        shownData = current;
      default:
        shownData = current;
    }
    final switcher = views.length > 1
        ? _ViewSwitcher(
            key: _switcherKey,
            views: views,
            selectedId: viewId,
            onSelected: _selectView,
          )
        : null;
    final downloadFailure = refreshFailure ?? _quietFailures[viewId];

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.displayTitle(l10n) ?? l10n.projectUnknownTitle),
        actions: [
          RefreshButton(onPressed: refreshing ? null : refresh),
          IconButton(
            onPressed: () => unawaited(_chooseSort(listKey, preferences)),
            tooltip: l10n.projectSortCurrent(sortLabel(l10n, preferences.sort)),
            icon: const Icon(Icons.sort),
          ),
          PopupMenuButton<_Action>(
            tooltip: l10n.moreActions,
            onSelected: (action) => switch (action) {
              _Action.toggleShowDone => _toggleShowDone(listKey, preferences),
              _Action.follow => unawaited(_toggleFollow()),
            },
            itemBuilder: (context) => [
              if (kind == ViewFilterKind.openOnly)
                CheckedPopupMenuItem(
                  value: _Action.toggleShowDone,
                  checked: preferences.showDone,
                  child: Text(l10n.projectTasksShowDone),
                ),
              if (_followable) _followItem(l10n),
            ],
          ),
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: archived
          ? null
          : FloatingActionButton(
              onPressed: () => unawaited(
                showNewTaskSheet(context, projectId: widget.projectId),
              ),
              tooltip: l10n.newTask,
              child: const Icon(Icons.add),
            ),
      body: buildRefreshable(
        shownData,
        loadingLabel: l10n.projectTasksLoading,
        header: switcher,
        builder: (value, notice) {
          final shown = _lastShown;
          final shownKind = shown?.kind ?? kind;
          final shownView = shown == null ? view : shown.view;
          final shownPreferences = shown?.preferences ?? preferences;
          final model = buildProjectListModel(
            value,
            kind: shownKind,
            preferences: shownPreferences,
            leaving: leavingTasksIn(value.tasksById),
          );
          final loadedAt = value.snapshot.loadedAt;
          return _ProjectList(
            projectId: widget.projectId,
            project: project,
            projectsById: projectsById,
            model: model,
            source: value,
            kind: shownKind,
            view: shownView,
            preferences: shownPreferences,
            offline: offline || downloadFailure is NetworkFailure,
            downloadFailed:
                downloadFailure != null && downloadFailure is! NetworkFailure,
            header: stackedNotes([
              ?switcher,
              ?notice,
              if (archived)
                ListNote(
                  icon: Icons.archive_outlined,
                  text: l10n.projectArchivedNote,
                ),
              if (shownKind == ViewFilterKind.other && loadedAt != null)
                ListNote(
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
                ),
            ]),
            now: now,
            minimumPriority: minimumPriority,
            pendingIds: pendingIds,
            onDoneChanged: (task, {required done}) =>
                unawaited(setTaskDone(task, done: done)),
            onFavoriteChanged: (task, {required favorite}) =>
                unawaited(setTaskFavorite(task, favorite: favorite)),
          );
        },
      ),
    );
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
          Icon(
            following ? Icons.notifications_off_outlined : Icons.notifications,
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

/// One chip per list view, when the project has more than one.
class _ViewSwitcher extends StatelessWidget {
  const new({
    required this.views,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<ProjectView> views;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.projectViewSwitch,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final view in views)
            ChoiceChip(
              label: Text(viewTitle(l10n, view)),
              selected: view.id == selectedId,
              onSelected: (_) => onSelected(view.id),
            ),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const new({
    required this.projectId,
    required this.project,
    required this.projectsById,
    required this.model,
    required this.source,
    required this.kind,
    required this.view,
    required this.preferences,
    required this.offline,
    required this.downloadFailed,
    required this.header,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final int projectId;
  final Project? project;
  final Map<int, Project> projectsById;
  final ProjectListModel model;
  final ProjectListSource source;
  final ViewFilterKind kind;
  final ProjectView? view;
  final ViewPreferences preferences;

  /// The device is offline, as far as the last sync or download knows.
  final bool offline;

  /// The view's download failed for a reason other than the connection.
  final bool downloadFailed;
  final Widget? header;
  final DateTime now;
  final int minimumPriority;
  final Set<int> pendingIds;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (model.isEmpty) {
      return CenteredScrollView(header: header, child: _emptyState(l10n));
    }
    final doneRows = model.doneRows ?? const [];
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header case final header?) NoticeSliver(notice: header),
        _rows(model.rows),
        if (doneRows.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: ListSectionHeader(
              title: l10n.projectTasksDoneSection,
              count: doneRows.where((row) => row.depth == 0).length,
            ),
          ),
          _rows(doneRows),
        ],
        // Room for the floating action button below the last row.
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
        ),
      ],
    );
  }

  Widget _rows(List<ProjectListRow> rows) {
    // A subtask with two parents in the list is in it twice.
    final occurrences = <int, int>{};
    final keys = [
      for (final row in rows)
        ValueKey((
          row.task.id,
          occurrences.update(
            row.task.id,
            (count) => count + 1,
            ifAbsent: () => 0,
          ),
        )),
    ];
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final task = row.task;
        final elsewhere = task.projectId == projectId
            ? null
            : projectsById[task.projectId];
        // The server refuses changes to the tasks of an archived project.
        final archived = projectsById[task.projectId]?.isArchived ?? false;
        return TaskRow(
          key: keys[index],
          task: task,
          now: now,
          minimumPriority: minimumPriority,
          depth: row.depth,
          parentTitle: row.parent?.title,
          projectTitle: elsewhere?.displayTitle(context.l10n),
          projectColor: parseHexColor(elsewhere?.hexColor ?? ''),
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
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    final filter = describeViewFilter(view?.filter);
    return switch (kind) {
      ViewFilterKind.other when source.snapshot.loadedAt == null && offline =>
        EmptyState(
          icon: Icons.cloud_download_outlined,
          title: l10n.projectViewNotLoadedTitle,
          body: l10n.projectViewNotLoadedBody(filter),
        ),
      ViewFilterKind.other
          when source.snapshot.loadedAt == null && downloadFailed =>
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.projectViewDownloadFailedTitle,
          body: l10n.projectViewDownloadFailedBody(filter),
        ),
      ViewFilterKind.other when source.snapshot.loadedAt == null => EmptyState(
        icon: Icons.cloud_download_outlined,
        title: l10n.projectViewDownloadingTitle,
        body: l10n.projectViewDownloadingBody(filter),
      ),
      ViewFilterKind.other => EmptyState(
        icon: Icons.filter_alt_outlined,
        title: l10n.projectViewEmptyTitle,
        body: l10n.projectViewEmptyBody,
      ),
      ViewFilterKind.doneOnly => EmptyState(
        icon: Icons.task_alt,
        title: l10n.projectTasksEmptyDoneTitle,
        body: l10n.projectTasksEmptyDoneBody,
      ),
      ViewFilterKind.openOnly
          when !preferences.showDone &&
              (source.projectTasks.isNotEmpty || source.omitsDoneTasks) =>
        EmptyState(
          icon: Icons.task_alt,
          title: l10n.projectTasksEmptyTitle,
          body: l10n.projectTasksEmptyBody,
        ),
      _ => EmptyState(
        icon: Icons.task_alt,
        title: l10n.projectTasksEmptyAllTitle,
        body: l10n.projectTasksEmptyAllBody,
      ),
    };
  }
}
