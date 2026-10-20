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
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_note.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/overview/application/overview_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/search/presentation/search_button.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/tasks/application/minimum_priority_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_list_actions.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

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
    with RefreshableList<OverviewScreen>, TaskListActions<OverviewScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  void onRepositoryReplaced() {
    super.onRepositoryReplaced();
    clearLeavingTasks();
  }

  // One sync run brings the project titles and the filter's tasks along.
  @override
  Future<void>? startRefresh() =>
      ref.read(taskRepositoryProvider)?.refreshOpenTasks();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabOverview),
        actions: [
          const SearchButton(),
          RefreshButton(onPressed: refreshing ? null : refresh),
          const InboxButton(),
          const AccountSwitcherButton(),
        ],
        bottom: const SyncProgressBar(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // A page over the shell (the inbox, the edit page) finds the heroes
        // of every tab's top route; the project screen's button would share
        // the default tag.
        heroTag: null,
        onPressed: () => unawaited(showNewTaskSheet(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTask),
      ),
      body: buildRefreshable(
        overview,
        loadingLabel: l10n.overviewLoading,
        builder: (value, notice) => _TaskSections(
          overview: value,
          sections: groupTasksByDueDate(withLeavingTasks(value.tasks), now),
          projectsById: projectsById,
          pendingIds: pendingIds,
          now: now,
          minimumPriority: minimumPriority,
          offline: offline,
          notice: notice,
          onDoneChanged: (task, {required done}) =>
              unawaited(setTaskDone(task, done: done)),
          onFavoriteChanged: (task, {required favorite}) =>
              unawaited(setTaskFavorite(task, favorite: favorite)),
        ),
      ),
    );
  }
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
    required this.notice,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
  });

  final OverviewTasks overview;
  final List<DueSection> sections;
  final Map<int, Project> projectsById;
  final Set<int> pendingIds;
  final DateTime now;
  final int minimumPriority;
  final bool offline;
  final Widget? notice;
  final void Function(Task task, {required bool done}) onDoneChanged;
  final void Function(Task task, {required bool favorite}) onFavoriteChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = overview.filter;
    final filterTitle = filter == null
        ? ''
        : projectDisplayTitle(l10n, filter.title, projectId: filter.projectId);
    final local = overview.filterEvaluation == FilterEvaluation.local;
    final loadedAt = local ? null : overview.filterLoadedAt;
    final header = stackedNotes([
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
    if (sections.isEmpty) {
      return CenteredScrollView(
        header: header,
        child: switch (filter) {
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
      );
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
              return TaskRow(
                key: ValueKey(task.id),
                task: task,
                now: now,
                minimumPriority: minimumPriority,
                projectTitle: project?.displayTitle(l10n),
                projectColor: parseHexColor(project?.hexColor ?? ''),
                pending: pendingIds.contains(task.id),
                onTap: () => unawaited(showTaskDetail(context, task: task)),
                onDoneChanged: (done) => onDoneChanged(task, done: done),
                onFavoriteChanged: (favorite) =>
                    onFavoriteChanged(task, favorite: favorite),
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

  String _sectionTitle(AppLocalizations l10n, DueGroup group) =>
      switch (group) {
        DueGroup.overdue => l10n.sectionOverdue,
        DueGroup.today => l10n.sectionToday,
        DueGroup.nextSevenDays => l10n.sectionNextSevenDays,
        DueGroup.later => l10n.sectionLater,
        DueGroup.noDueDate => l10n.sectionNoDueDate,
      };
}
