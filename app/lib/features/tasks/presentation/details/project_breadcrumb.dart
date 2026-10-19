import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';

/// [project] and its ancestors from the root, as far up as [projects] has
/// them: the web stops at the first parent the user cannot see.
List<Project> projectPath(Project project, List<Project> projects) {
  final byId = {for (final each in projects) each.id: each};
  final path = [project];
  final seen = {project.id};
  var parentId = project.parentProjectId;
  while (parentId != 0 && seen.add(parentId)) {
    final parent = byId[parentId];
    if (parent == null) break;
    path.add(parent);
    parentId = parent.parentProjectId;
  }
  return path.reversed.toList();
}

/// "Work › Clients › Acme": each project a link that leaves the sheet for
/// that project's screen.
class ProjectBreadcrumb extends StatelessWidget {
  const new({required this.path, required this.onOpen, super.key});

  final List<Project> path;
  final ValueChanged<Project> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < path.length; i++) ...[
          if (i > 0) ExcludeSemantics(child: Text(' › ', style: style)),
          Semantics(
            link: true,
            hint: l10n.taskDetailOpenProjectHint,
            child: InkWell(
              onTap: () => onOpen(path[i]),
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Align(
                    widthFactor: 1,
                    child: Text(path[i].displayTitle(l10n), style: style),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
