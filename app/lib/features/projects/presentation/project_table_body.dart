import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/centered_scroll_view.dart';
import 'package:vikunja_mobile/features/common/presentation/refreshable_list.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

/// The rows of a project's table view, the web table as a detailed list:
/// one task row per task with the chosen [columns], or the view's empty
/// state. Read-only for order; the checkbox and the star work as in every
/// list.
class ProjectTableBody extends StatelessWidget {
  const new({
    required this.projectId,
    required this.projectsById,
    required this.rows,
    required this.columns,
    required this.source,
    required this.kind,
    required this.view,
    required this.showDone,
    required this.offline,
    required this.downloadFailed,
    required this.header,
    required this.now,
    required this.minimumPriority,
    required this.pendingIds,
    required this.onDoneChanged,
    required this.onFavoriteChanged,
    super.key,
  });

  final int projectId;
  final Map<int, Project> projectsById;

  /// From `buildTableRows`.
  final List<Task> rows;
  final Set<TableColumn> columns;
  final ProjectListSource source;
  final ViewFilterKind kind;
  final ProjectView? view;
  final bool showDone;

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

  static const _divider = Divider(height: 1);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return CenteredScrollView(
        header: header,
        maxWidth: ReadableWidth.list,
        child: ViewEmptyState(
          kind: kind,
          source: source,
          view: view,
          showDone: showDone,
          offline: offline,
          downloadFailed: downloadFailed,
        ),
      );
    }
    return ReadableWidth.builder(
      maxWidth: ReadableWidth.list,
      builder: (context, contentWidth, inset) {
        final identifiersLead =
            columns.contains(TableColumn.taskIndex) &&
            TaskRow.identifiersFitBeforeTitle(
              context,
              rows,
              rowWidth: contentWidth,
            );
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              sliver: SliverMainAxisGroup(
                slivers: [
                  if (header case final header?) NoticeSliver(notice: header),
                  SliverList.builder(
                    itemCount: rows.length,
                    findChildIndexCallback: (key) {
                      if (key case ValueKey<(String, int)>(
                        value: (_, final id),
                      )) {
                        final index = rows.indexWhere((task) => task.id == id);
                        return index < 0 ? null : index;
                      }
                      return null;
                    },
                    // The last row is wrapped too: a row that stops being the
                    // last keeps its key, its place and so its state.
                    itemBuilder: (context, index) => Column(
                      key: ValueKey(('table', rows[index].id)),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _row(
                          context,
                          rows[index],
                          identifierBeforeTitle: identifiersLead,
                        ),
                        if (index < rows.length - 1) _divider,
                      ],
                    ),
                  ),
                  // Room for the floating action button below the last row.
                  const SliverSafeArea(
                    top: false,
                    sliver: SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    Task task, {
    required bool identifierBeforeTitle,
  }) {
    final project = columns.contains(TableColumn.project)
        ? projectsById[task.projectId]
        : null;
    // The server refuses changes to the tasks of an archived project.
    final archived = isArchivedInTree(task.projectId, projectsById);
    return TaskRow(
      key: ValueKey(task.id),
      task: task,
      now: now,
      minimumPriority: minimumPriority,
      identifierBeforeTitle: identifierBeforeTitle,
      columns: columns,
      projectTitle: project?.displayTitle(context.l10n),
      projectColor: parseHexColor(project?.hexColor ?? ''),
      pending: pendingIds.contains(task.id),
      onTap: () => openTaskDetail(context, task: task),
      onDoneChanged: archived
          ? null
          : (done) => onDoneChanged(task, done: done),
      onFavoriteChanged: archived
          ? null
          : (favorite) => onFavoriteChanged(task, favorite: favorite),
    );
  }
}
