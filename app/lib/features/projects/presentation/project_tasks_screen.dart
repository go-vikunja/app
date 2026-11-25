import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/main_action.dart';
import 'package:vikunja_mobile/app/layout/readable_app_bar.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/auth/failed_without_token.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/subscription_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';
import 'package:vikunja_mobile/features/projects/application/project_rows.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_actions.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tree_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_content.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_downloads.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_view_kinds.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/account_context_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/bulk_task_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

enum _Action {
  refresh,
  select,
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

/// What the view was last built from, kept on screen while another view
/// or its preferences load; only for the `repository` it was read from.
typedef _Shown = ({TaskRepository? repository, ProjectViewContent content});

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
  const new({required this.projectId, this.viewId, super.key});

  final int projectId;

  /// The view to open on while the project has it, in place of the one
  /// last left in or the default.
  final int? viewId;

  @override
  ConsumerState<ProjectTasksScreen> createState() => _ProjectTasksScreenState();
}

class _ProjectTasksScreenState extends ConsumerState<ProjectTasksScreen>
    with
        RefreshableList<ProjectTasksScreen>,
        ProjectViewDownloads<ProjectTasksScreen>,
        TaskListActions<ProjectTasksScreen>,
        TaskSelectionActions<ProjectTasksScreen>,
        ProjectManagementActions<ProjectTasksScreen> {
  /// Room after the last item of a board's column, to scroll it clear of
  /// the floating action button.
  static const _fabRoom = 80.0;

  late final _follow = FollowController(
    entity: SubscriptionEntity.project,
    read: (id) => _subscriptions().forProject(id),
    write: (id, {required subscribed}) =>
        _subscriptions().setProjectSubscribed(id, subscribed: subscribed),
    optOuts: () => ref.read(activeServerHasFollowOptOutsProvider),
  );

  final _rows = ProjectRows();

  /// The selectable tasks of the last rows, again only when the rows, the
  /// projects or the copies kept for an Undo changed.
  ({
    Object rows,
    Object? projects,
    Map<int, Task> leaving,
    List<Task> selectable,
  })?
  _selectableFrom;
  var _seen = false;
  late int? _chosenViewId = widget.viewId;
  var _viewId = 0;
  ProjectViewKind _viewKind = ProjectViewKind.list;
  _Shown? _lastShown;

  // The chips move between the list and its loading and failure states,
  // so the tapped one keeps its focus.
  final GlobalKey _controlsKey = GlobalKey();

  /// Ids below zero open the smart list screen, so this only keeps out a
  /// link to project 0, which is no project.
  bool get _followable => widget.projectId > 0;

  @override
  int get projectId => widget.projectId;

  @override
  int get currentViewId => _viewId;

  @override
  bool get currentViewIsBoard => _viewKind == ProjectViewKind.kanban;

  @override
  ProjectViewContent? get lastShownContent => _lastShown?.content;

  @override
  void initState() {
    super.initState();
    if (_followable && !ref.read(activeAccountIsGuestProvider)) {
      unawaited(_follow.load(widget.projectId));
    }
  }

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

  SubscriptionRepository _subscriptions() =>
      ref.read(subscriptionRepositoryProvider) ??
      (throw StateError('No account is signed in'));

  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    endSelection();
    _lastShown = null;
  }

  void _selectView(int viewId) {
    if (viewId == _viewId) return;
    unawaited(
      ref.read(listPreferencesProvider)?.saveLastView(widget.projectId, viewId),
    );
    endSelection();
    setState(() {
      _chosenViewId = viewId;
      clearRefreshFailure();
      clearLeavingTasks();
    });
  }

  /// The tasks a list or table view shows that may be changed, for the
  /// selection; none in a board or a timeline.
  List<Task> _selectableIn(
    ProjectViewContent? content, {
    required Set<TableColumn> columns,
    required Map<int, Project> projectsById,
    required Object? projects,
  }) {
    final Map<int, Task> leaving;
    final Object rows;
    // A task's copy that stays on screen while its done's Undo is offered
    // is not the task to act on.
    switch (content) {
      case TableViewContent(:final source, :final kind, :final preferences):
        leaving = leavingTasksIn(source.tasksById);
        rows = _rows.tableRows(
          source,
          kind: kind,
          showDone: preferences.showDone,
          sort: preferences.tableSort.forColumns(columns),
          leaving: leaving,
        );
      case ListViewContent(:final source, :final kind, :final preferences):
        leaving = leavingTasksIn(source.tasksById);
        rows = _rows.listModel(
          source,
          kind: kind,
          preferences: preferences,
          leaving: leaving,
        );
      case TimelineViewContent() || BoardViewContent() || null:
        return const [];
    }
    if (_selectableFrom case final last?
        when identical(last.rows, rows) &&
            identical(last.projects, projects) &&
            mapEquals(last.leaving, leaving)) {
      return last.selectable;
    }
    final shown = switch (rows) {
      final ProjectListModel model => () {
        final seen = <int>{};
        return [
          for (final row in [...model.rows, ...?model.doneRows])
            if (seen.add(row.task.id)) row.task,
        ];
      }(),
      final List<Task> tasks => tasks,
      _ => const <Task>[],
    };
    final selectable = [
      for (final task in shown)
        if (!leaving.containsKey(task.id) && taskChangeable(task, projectsById))
          task,
    ];
    _selectableFrom = (
      rows: rows,
      projects: projects,
      leaving: leaving,
      selectable: selectable,
    );
    return selectable;
  }

  void _toggleShowDone(String listKey, ViewPreferences current) {
    unawaited(
      ref
          .read(listPreferencesProvider)
          ?.saveView(listKey, current.copyWith(showDone: !current.showDone)),
    );
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
      if (previous != null && next == null) refreshAfterReconnect();
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
        appBar: ReadableAppBar(
          maxWidth: ReadableWidth.list,
          automaticallyImplyLeading: !ProjectTreeColumnScope.shownOf(context),
          title: ScreenTitle(l10n.projectUnknownTitle),
        ),
        body: CenteredScrollView(
          maxWidth: ReadableWidth.list,
          child: EmptyState(
            icon: Icons.search_off,
            title: l10n.projectGoneTitle,
            body: l10n.projectGoneBody,
          ),
        ),
      );
    }
    final views = shownViewsOf(project);
    final defaultKind = ref.watch(
      userSettingsProvider.select(
        (settings) => settings.value?.defaultViewKind,
      ),
    );
    final lastViewValue = ref.watch(lastViewProvider(widget.projectId));
    bool shown(int? viewId) => views.any((view) => view.id == viewId);
    final chosenViewId = _chosenViewId;
    final lastViewId = lastViewValue.value;
    final viewId = _viewId = shown(chosenViewId)
        ? chosenViewId!
        : shown(lastViewId)
        ? lastViewId!
        : resolveViewId(views, defaultKind: defaultKind);
    final view = views.where((view) => view.id == viewId).firstOrNull;
    final viewKind = _viewKind = view?.kind ?? ProjectViewKind.list;
    final delegate = ProjectViewDelegate.of(viewKind);
    final kind = view == null
        ? ViewFilterKind.openOnly
        : classifyViewFilter(view.filter);
    final listKey = listKeyFor(projectId: widget.projectId, viewId: viewId);
    final preferencesValue = delegate.watchPreferences(ref, listKey);
    final preferences = preferencesValue.value ?? const ViewPreferences();
    final columnsValue = delegate.watchColumns(ref);
    final storedColumns = columnsValue.value ?? TableColumn.defaults;
    // Every row shows its title, whatever the stored choice says.
    final columns = {...storedColumns, TableColumn.title};
    final source = delegate.watchSource(
      ref,
      projectId: widget.projectId,
      viewId: viewId,
      kind: kind,
      preferences: preferences,
      onQueued: (queued) => followQueued(viewId, queued, board: delegate.board),
    );
    final repository = ref.watch(taskRepositoryProvider);
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final offline = ref.watch(offlineProvider) != null;
    final archived = isArchivedInTree(widget.projectId, projectsById);
    final access = ref.watch(projectAccessProvider(widget.projectId));
    // Whatever the share's permission: the server ignores a guest's
    // favourites and refuses it Follow, sharing and new projects, copies
    // included, and the web reaches the project's settings, views and
    // delete only by a typed address, which the app does not offer.
    final guest = ref.watch(activeAccountIsGuestProvider);
    final defaultProjectId = ref.watch(
      userSettingsProvider.select(
        (settings) => settings.value?.defaultProjectId,
      ),
    );
    // Until then the view shown may still change.
    final ready =
        !(projects.isLoading && !projects.hasValue) &&
        !(lastViewValue.isLoading && !lastViewValue.hasValue) &&
        !(preferencesValue.isLoading && !preferencesValue.hasValue) &&
        !(columnsValue.isLoading && !columnsValue.hasValue);
    final lastShown = _lastShown;
    final showing = source.show(
      ready: ready,
      last: lastShown?.content,
      sameRepository: identical(lastShown?.repository, repository),
      view: view,
      kind: kind,
      preferences: preferences,
    );
    if (showing.settled case final content?) {
      _lastShown = (repository: repository, content: content);
      refreshWhenStale(view, content.loadedAt, board: delegate.board);
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
    final controls = delegate.controls(
      context,
      ref,
      key: _controlsKey,
      viewId: viewId,
      listKey: listKey,
      preferences: preferences,
      columns: columns,
      storedColumns: storedColumns,
      onShowDoneChanged: onShowDoneChanged,
    );
    final progress = _followable && ProjectAppBarBottom.showsProgressIn(context)
        ? ref.watch(projectProgressProvider(widget.projectId)).value
        : null;
    final downloadFailure = downloadFailureOf(viewId);
    final unreachable = failedOnTheNetwork(downloadFailure);
    final offlineOrUnreachable = offline || unreachable;
    final downloadFailed = downloadFailure != null && !unreachable;
    final archivedNote = archived
        ? ListNote(icon: Icons.archive_outlined, text: l10n.projectArchivedNote)
        : access.isReadOnly && _followable
        ? ListNote(
            icon: Icons.visibility_outlined,
            text: l10n.shareReadOnlyProjectNote,
          )
        : null;
    final addsTasks = !archived && access.canAddTasks;
    final selects = delegate.selects;
    final selectable = selecting
        ? _selectableIn(
            showing.content,
            columns: columns,
            projectsById: projectsById,
            projects: projects.value,
          )
        : const <Task>[];
    final selectableIds = {for (final task in selectable) task.id};

    final newTask = !addsTasks || selecting
        ? null
        : MainAction(
            icon: Icons.add,
            label: l10n.newTask,
            onPressed: () => unawaited(
              showNewTaskSheet(context, projectId: widget.projectId),
            ),
          );
    return selectionBackHandler(
      child: MainActionClaim(
        action: newTask,
        child: Scaffold(
          appBar: selecting
              ? selectionBar(
                  selectable,
                  bottom: ProjectAppBarBottom(
                    progress: progress,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                )
              : ReadableAppBar(
                  maxWidth: ReadableWidth.list,
                  // The tree beside it is where to go next; back still goes
                  // back.
                  automaticallyImplyLeading: !ProjectTreeColumnScope.shownOf(
                    context,
                  ),
                  title: ScreenTitle(
                    project?.displayTitle(l10n) ?? l10n.projectUnknownTitle,
                  ),
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
                        onSelected: (action) =>
                            _onAction(action, project: project),
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
                                isArchivedInTree(
                                  project.parentProjectId,
                                  projectsById,
                                ),
                            isDefault: project?.id == defaultProjectId,
                          );
                          return [
                            // For whoever cannot pull the list, a screen
                            // reader among them.
                            projectMenuItem(
                              _Action.refresh,
                              icon: Icons.refresh,
                              label: l10n.refresh,
                              enabled: !refreshing,
                            ),
                            if (selects && !archived && access.canChangeTasks)
                              projectMenuItem(
                                _Action.select,
                                icon: Icons.checklist,
                                label: l10n.selectTasks,
                              ),
                            if (projectItems.isNotEmpty)
                              const PopupMenuDivider(),
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
          bottomNavigationBar: selecting
              ? selectionActionBar(selectable)
              : null,
          floatingActionButton: MainActionButton.unlessBesideRail(
            context,
            newTask,
          ),
          body: buildRefreshable(
            showing.data,
            loadingLabel: l10n.projectTasksLoading,
            header: controls,
            // Under the tabs in every view; the board and the timeline
            // themselves use the whole width.
            maxWidth: ReadableWidth.list,
            notificationPredicate: delegate.notificationPredicate,
            builder: (content, notice) => projectViewBody(
              context,
              content,
              ProjectViewFrame(
                projectId: widget.projectId,
                projectsById: projectsById,
                archived: archived,
                access: access,
                repository: repository,
                offline: offlineOrUnreachable,
                downloadFailed: downloadFailed,
                notice: notice,
                archivedNote: archivedNote,
                controls: controls,
                columns: columns,
                now: now,
                minimumPriority: minimumPriority,
                pendingIds: pendingIds,
                bottomPadding: addsTasks ? _fabRoom : 0,
                leavingIn: leavingTasksIn,
                rows: _rows,
                onDoneChanged: (task, {required done}) =>
                    unawaited(setTaskDone(task, done: done)),
                onFavoriteChanged: (task, {required favorite}) =>
                    unawaited(setTaskFavorite(task, favorite: favorite)),
                onDueDate: (task) => unawaited(changeTaskDueDate(task)),
                onSelect: startSelection,
                selection: selecting
                    ? (task) => rowSelection(
                        task,
                        changeable: selectableIds.contains(task.id),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onAction(_Action action, {required Project? project}) {
    if (action == _Action.refresh) {
      unawaited(refresh());
      return;
    }
    if (action == _Action.select) {
      startSelection();
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
      case _Action.refresh || _Action.follow || _Action.select:
        break;
    }
  }

  /// The web's project menu, for what the app offers, Follow among them,
  /// in groups, without what [access] does not allow; an archived project
  /// only offers to unarchive it, which waits for its archived parent.
  /// Like the web, the user's default project cannot be archived and offers
  /// no Delete. A [guest] gets none of them, as the web offers a link share
  /// no project menu and the server refuses it the rest.
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
  /// or written, as a tap would do nothing; while it is unknown, or a
  /// follow through the parent that the server cannot stop for this project
  /// alone, the tap explains why.
  PopupMenuItem<_Action> _followItem(AppLocalizations l10n) {
    final state = _follow.value;
    final following = state is FollowKnown && state.following;
    final fixed = _follow.fixed;
    return PopupMenuItem(
      value: _Action.follow,
      enabled: switch (state) {
        FollowUnknown(:final loading) => !loading,
        FollowKnown(:final saving) => !saving,
      },
      child: Row(
        children: [
          ProjectMenuIcon(switch ((fixed, following)) {
            (true, _) => Icons.notifications_active_outlined,
            (_, true) => Icons.notifications_off_outlined,
            _ => Icons.notifications_outlined,
          }),
          const SizedBox(width: 12),
          Flexible(
            child: Text(switch (state) {
              FollowUnknown(loading: true) => l10n.followChecking,
              _ when fixed => l10n.followingViaSomeProject,
              _ when following => l10n.unfollowProject,
              _ => l10n.followProject,
            }),
          ),
        ],
      ),
    );
  }
}
