import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';

/// A project in the Projects tab; in the tree with its depth, its children
/// count and expand control, and [actions] for screen readers.
class ProjectRow extends StatelessWidget {
  const new({
    required this.project,
    required this.onTap,
    this.depth = 0,
    this.childCount = 0,
    this.expanded = false,
    this.onToggleExpanded,
    this.actions = const {},
    super.key,
  });

  final Project project;
  final VoidCallback onTap;
  final int depth;
  final int childCount;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final Map<CustomSemanticsAction, VoidCallback> actions;

  /// Where a row of [depth] starts its content.
  static double indentOf(int depth) => 16 + depth * 20.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = parseHexColor(project.hexColor);
    final title = project.displayTitle(l10n);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.only(
        start: indentOf(depth),
        end: 8,
      ),
      leading: ExcludeSemantics(
        child: color == null
            ? Icon(Icons.folder_outlined, color: colors.onSurfaceVariant)
            : DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 16),
              ),
      ),
      title: Semantics(
        customSemanticsActions: actions.isEmpty ? null : actions,
        child: Text(title),
      ),
      subtitle: childCount > 0
          ? Text(l10n.projectChildCount(childCount))
          : null,
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
            Icon(
              Icons.star,
              color: colors.tertiary,
              semanticLabel: l10n.favouriteLabel,
            ),
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
    );
  }
}
