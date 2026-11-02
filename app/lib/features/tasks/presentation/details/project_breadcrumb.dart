import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';

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

/// "Work › Clients › (Acme)": the task's project as an outlined chip with
/// its coloured folder, after its ancestors; each one a link that leaves the
/// sheet for that project's screen.
class ProjectBreadcrumb extends StatelessWidget {
  const new({required this.path, required this.onOpen, super.key});

  final List<Project> path;
  final ValueChanged<Project> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final project = path.last;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final ancestor in path.take(path.length - 1)) ...[
          Semantics(
            link: true,
            hint: l10n.taskDetailOpenProjectHint,
            child: InkWell(
              onTap: () => onOpen(ancestor),
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Align(
                    widthFactor: 1,
                    child: Text(ancestor.displayTitle(l10n), style: style),
                  ),
                ),
              ),
            ),
          ),
          ExcludeSemantics(child: Text(' › ', style: style)),
        ],
        // One node: the chip's button and the link's hint.
        MergeSemantics(
          child: Semantics(
            link: true,
            hint: l10n.taskDetailOpenProjectHint,
            child: ActionChip(
              avatar: ProjectIcon(hexColor: project.hexColor),
              label: Text(project.displayTitle(l10n)),
              labelStyle: theme.textTheme.labelMedium,
              visualDensity: VisualDensity.compact,
              onPressed: () => onOpen(project),
            ),
          ),
        ),
      ],
    );
  }
}
