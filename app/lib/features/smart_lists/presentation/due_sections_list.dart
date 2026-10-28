import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/overview/application/due_date_groups.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// A list that is no project, grouped by due date like the Overview, each
/// row with its project; [emptyState] without tasks.
class DueSectionsList extends StatelessWidget {
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
    super.key,
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
      return CenteredScrollView(
        header: header,
        maxWidth: ReadableWidth.list,
        child: emptyState,
      );
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverReadableWidth.group(
          maxWidth: ReadableWidth.list,
          slivers: [
            if (header case final header?) NoticeSliver(notice: header),
            for (final section in sections)
              SliverSectionCard(
                title: dueSectionTitle(l10n, section.group),
                count: section.tasks.length,
                titleColor: section.group == DueGroup.overdue
                    ? Theme.of(context).colorScheme.error
                    : null,
                itemCount: section.tasks.length,
                itemBuilder: (context, index) {
                  final task = section.tasks[index];
                  final project = projectsById[task.projectId];
                  // The server refuses changes to the tasks of an archived
                  // project, which a saved filter can list.
                  final archived = isArchivedInTree(
                    task.projectId,
                    projectsById,
                  );
                  return TaskRow(
                    key: ValueKey(task.id),
                    task: task,
                    now: now,
                    minimumPriority: minimumPriority,
                    projectTitle: project?.displayTitle(l10n),
                    projectColor: parseHexColor(project?.hexColor ?? ''),
                    pending: pendingIds.contains(task.id),
                    onTap: () => openTaskDetail(context, task: task),
                    onDoneChanged: archived
                        ? null
                        : (done) => onDoneChanged(task, done: done),
                    onFavoriteChanged: archived
                        ? null
                        : (favorite) =>
                              onFavoriteChanged(task, favorite: favorite),
                  );
                },
              ),
            // Room for the floating action button below the last row.
            const SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
            ),
          ],
        ),
      ],
    );
  }
}

String dueSectionTitle(AppLocalizations l10n, DueGroup group) =>
    switch (group) {
      DueGroup.overdue => l10n.sectionOverdue,
      DueGroup.today => l10n.sectionToday,
      DueGroup.nextSevenDays => l10n.sectionNextSevenDays,
      DueGroup.later => l10n.sectionLater,
      DueGroup.noDueDate => l10n.sectionNoDueDate,
    };
