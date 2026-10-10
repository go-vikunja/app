import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/empty_state.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/overview/application/open_tasks_provider.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// The open tasks across all projects, grouped by due date.
class OverviewScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen>
    with RefreshableList<OverviewScreen> {
  @override
  ProviderListenable<Object?> get repositoryProvider => taskRepositoryProvider;

  @override
  Future<void>? startRefresh() {
    final tasks = ref.read(taskRepositoryProvider);
    if (tasks == null) return null;
    // Project titles come along; their failure is not this screen's story.
    unawaited(
      ref
          .read(projectRepositoryProvider)
          ?.refresh()
          .then<void>((_) {}, onError: (Object _) {}),
    );
    return tasks.refreshOpenTasks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = ref.watch(openTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final projectsById = {for (final project in projects) project.id: project};
    final now = ref.watch(clockTickProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabOverview),
        actions: [RefreshButton(onPressed: refreshing ? null : refresh)],
      ),
      body: buildRefreshable(
        tasks,
        loadingLabel: l10n.overviewLoading,
        builder: (value, notice) => _TaskSections(
          sections: groupTasksByDueDate(value, now),
          projectsById: projectsById,
          now: now,
          notice: notice,
        ),
      ),
    );
  }
}

class _TaskSections extends StatelessWidget {
  const new({
    required this.sections,
    required this.projectsById,
    required this.now,
    required this.notice,
  });

  final List<DueSection> sections;
  final Map<int, Project> projectsById;
  final DateTime now;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (sections.isEmpty) {
      return CenteredScrollView(
        header: notice,
        child: EmptyState(
          icon: Icons.task_alt,
          title: l10n.overviewEmptyTitle,
          body: l10n.overviewEmptyBody,
        ),
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (notice case final notice?) NoticeSliver(notice: notice),
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
                task: task,
                now: now,
                projectTitle: project?.title,
                onTap: () => unawaited(
                  showTaskDetail(context, task: task, project: project),
                ),
              );
            },
          ),
        ],
        const SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(child: SizedBox(height: 16)),
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
