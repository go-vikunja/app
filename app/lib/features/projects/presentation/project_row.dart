import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/selected_task_highlight.dart';

/// A project in the Projects tab with its open tasks; in the tree with its
/// depth, its children count and expand control, and [actions] for screen
/// readers. [selected] marks the project open beside the tree's column, as
/// the task open in the pane is marked, in the colours of any other row.
class ProjectRow extends StatelessWidget {
  const new({
    required this.project,
    required this.onTap,
    this.openTaskCount = 0,
    this.depth = 0,
    this.childCount = 0,
    this.expanded = false,
    this.onToggleExpanded,
    this.actions = const {},
    this.selected = false,
    super.key,
  });

  final Project project;
  final VoidCallback onTap;

  /// The project's own, not its subprojects'.
  final int openTaskCount;
  final int depth;
  final int childCount;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final Map<CustomSemanticsAction, VoidCallback> actions;
  final bool selected;

  /// Where a row of [depth] starts its content.
  static double indentOf(int depth) => 16 + depth * 20.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = project.displayTitle(l10n);
    final details = [
      if (openTaskCount > 0) l10n.smartListOpenTaskCount(openTaskCount),
      if (childCount > 0) l10n.projectChildCount(childCount),
    ];
    return SelectedTaskHighlight(
      selected: selected,
      child: ListTile(
        onTap: onTap,
        selected: selected,
        // Selected paints the texts and icons in the primary colour, and a
        // text colour paints the subtitle too.
        textColor: WidgetStateColor.resolveWith((_) => colors.onSurface),
        iconColor: WidgetStateColor.resolveWith((_) => colors.onSurfaceVariant),
        contentPadding: EdgeInsetsDirectional.only(
          start: indentOf(depth),
          end: 8,
        ),
        leading: ProjectIcon(hexColor: project.hexColor),
        title: Semantics(
          customSemanticsActions: actions.isEmpty ? null : actions,
          child: Text(title),
        ),
        subtitle: details.isEmpty
            ? null
            : Text(
                details.join(' · '),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.isArchived)
              Icon(
                Icons.archive_outlined,
                color: colors.onSurfaceVariant,
                semanticLabel: l10n.projectArchived,
              ),
            if (project.isFavorite)
              Semantics(label: l10n.favouriteLabel, child: const FilledStar()),
            if (onToggleExpanded case final onToggle? when childCount > 0)
              IconButton(
                onPressed: onToggle,
                tooltip: expanded
                    ? l10n.projectCollapse(title)
                    : l10n.projectExpand(title),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
          ],
        ),
      ),
    );
  }
}
