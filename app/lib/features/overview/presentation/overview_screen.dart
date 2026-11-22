import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/main_action.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/overview/application/overview_tasks_provider.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_header.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/due_sections_list.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/bulk_task_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart'
    show TaskRowSelection;
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

/// The open tasks across all projects, or those of the saved filter picked
/// for the Overview on the web, grouped by due date. The filter is
/// evaluated here from its stored definition; where the device cannot, the
/// sync's last download of its tasks shows, saying when it ran.
class OverviewScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen>
    with
        RefreshableList<OverviewScreen>,
        TaskListActions<OverviewScreen>,
        TaskSelectionActions<OverviewScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
    endSelection();
  }

  // One sync run brings the project titles and the filter's tasks along.
  @override
  Future<void>? startRefresh() =>
      ref.read(taskRepositoryProvider)?.refreshOpenTasks();

  // Keeps the header, and the focus in it, between the loading and the
  // list states.
  final GlobalKey _headerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(overviewTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectsById = {for (final project in projects) project.id: project};
    final now = ref.watch(clockTickProvider);
    final minimumPriority = ref.watch(minimumPriorityProvider);
    final pendingIds =
        ref.watch(pendingTaskIdsProvider).unwrapPrevious().value ?? const {};
    final offline = ref.watch(offlineProvider) != null;
    Widget header({int? tasksLeft}) => OverviewHeader(
      key: _headerKey,
      now: now,
      tasksLeft: tasksLeft,
      onRefresh: refreshing ? null : () => unawaited(refresh()),
    );

    final shownTasks = overview.value?.tasks ?? const <Task>[];
    final selectable = [
      for (final task in shownTasks)
        if (taskChangeable(task, projectsById)) task,
    ];
    final selectableIds = {for (final task in selectable) task.id};

    final newTask = selecting
        ? null
        : MainAction(
            icon: Icons.add,
            label: l10n.newTask,
            onPressed: () => unawaited(showNewTaskSheet(context)),
          );
    return selectionBackHandler(
      child: MainActionClaim(
        action: newTask,
        child: Scaffold(
          appBar: selecting ? selectionBar(selectable) : null,
          bottomNavigationBar: selecting
              ? selectionActionBar(selectable)
              : null,
          floatingActionButton: MainActionButton.unlessBesideRail(
            context,
            newTask,
          ),
          body: SafeArea(
            top: !selecting,
            bottom: false,
            child: Column(
              children: [
                const SyncProgressBar(),
                Expanded(
                  child: buildRefreshable(
                    overview,
                    loadingLabel: l10n.overviewLoading,
                    header: header(),
                    maxWidth: ReadableWidth.list,
                    builder: (value, notice) {
                      final sections = groupTasksByDueDate(
                        withLeavingTasks(value.tasks),
                        now,
                      );
                      return _TaskSections(
                        overview: value,
                        sections: sections,
                        projectsById: projectsById,
                        pendingIds: pendingIds,
                        now: now,
                        minimumPriority: minimumPriority,
                        offline: offline,
                        header: header(tasksLeft: _tasksLeftToday(sections)),
                        notice: notice,
                        onDoneChanged: (task, {required done}) =>
                            unawaited(setTaskDone(task, done: done)),
                        onFavoriteChanged: (task, {required favorite}) =>
                            unawaited(
                              setTaskFavorite(task, favorite: favorite),
                            ),
                        onDueDate: (task) => unawaited(changeTaskDueDate(task)),
                        onSelect: startSelection,
                        selection: (task) => rowSelection(
                          task,
                          changeable: selectableIds.contains(task.id),
                        ),
                        onReschedule: selecting
                            ? null
                            : (tasks) => unawaited(
                                rescheduleTasks(
                                  context,
                                  ref,
                                  tasks,
                                  title: l10n.overdueRescheduleTitle(
                                    tasks.length,
                                  ),
                                ),
                              ),
                        changeable: (task) =>
                            taskChangeable(task, projectsById),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _tasksLeftToday(List<DueSection> sections) => [
    for (final section in sections)
      if (section.group == DueGroup.overdue || section.group == DueGroup.today)
        for (final task in section.tasks)
          if (!task.done) task,
  ].length;
}

class _TaskSections extends StatelessWidget {
  const new({
    required this.overview,
    required this.sections,
    required this.projectsById,
    required this.pendingIds,
    required this.now,
    required this.minimumPriority,
    required this.offline,
    required this.header,
    required this.notice,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
    required this.onDueDate,
    required this.onSelect,
    required this.selection,
    required this.onReschedule,
    required this.changeable,
  });

  final OverviewTasks overview;
  final List<DueSection> sections;
  final Map<int, Project> projectsById;
  final Set<int> pendingIds;
  final DateTime now;
  final int minimumPriority;
  final bool offline;

  /// The search bar and the greeting, above the notes.
  final Widget header;
  final Widget? notice;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;
  final void Function(Task task) onDueDate;
  final void Function(Task task) onSelect;
  final TaskRowSelection? Function(Task task) selection;
  final void Function(List<Task> overdue)? onReschedule;
  final bool Function(Task task) changeable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = overview.filter;
    final filterTitle = filter == null
        ? ''
        : projectDisplayTitle(l10n, filter.title, projectId: filter.projectId);
    final local = overview.filterEvaluation == FilterEvaluation.local;
    final loadedAt = local ? null : overview.filterLoadedAt;
    final notes = stackedNotes([
      ?notice,
      if (filter != null)
        ListNote(
          icon: Icons.filter_list,
          text: loadedAt == null
              ? l10n.overviewFilterSubtitle(filterTitle)
              : l10n.overviewFilterNotice(
                  filterTitle,
                  formatRelativeTime(
                    l10n,
                    // The tick may lag behind a download just finished.
                    loadedAt.isAfter(now) ? now : loadedAt,
                    now: now,
                  ),
                ),
        ),
    ]);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        this.header,
        if (notes != null) ...[const SizedBox(height: 16), notes],
      ],
    );
    return DueSectionsList(
      sections: sections,
      projectsById: projectsById,
      pendingIds: pendingIds,
      now: now,
      minimumPriority: minimumPriority,
      header: header,
      emptyState: switch (filter) {
        _? when !local && loadedAt == null => EmptyState(
          icon: Icons.cloud_download_outlined,
          title: offline
              ? l10n.overviewFilterNotLoadedTitle
              : l10n.overviewFilterNotDownloadedTitle,
          body: l10n.overviewFilterNotLoadedBody(filterTitle),
        ),
        _? => EmptyState(
          icon: Icons.task_alt,
          title: l10n.overviewEmptyTitle,
          body: l10n.overviewFilterEmptyBody(filterTitle),
        ),
        null => EmptyState(
          icon: Icons.task_alt,
          title: l10n.overviewEmptyTitle,
          body: l10n.overviewEmptyBody,
        ),
      },
      onDoneChanged: onDoneChanged,
      onFavoriteChanged: onFavoriteChanged,
      onDueDate: onDueDate,
      onSelect: onSelect,
      selection: selection,
      onReschedule: onReschedule,
      changeable: changeable,
    );
  }
}
