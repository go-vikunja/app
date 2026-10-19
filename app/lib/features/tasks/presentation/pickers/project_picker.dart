import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';

/// Lets the user pick one of [projects] (the tree without archived and
/// pseudo projects), indented by depth; null when dismissed. A sheet on
/// every platform: an action sheet would centre the titles and lose the
/// tree, and grow with every project.
Future<Project?> pickProject(
  BuildContext context, {
  required List<Project> projects,
  required int? selectedId,
}) {
  final rows = selectableProjects(projects);
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showCupertinoSheet<Project>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: _ProjectList(
              rows: rows,
              selectedId: selectedId,
              scrollController: scrollController,
            ),
          ),
        ),
      );
    case _:
      return showModalBottomSheet<Project>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, scrollController) => _ProjectList(
            rows: rows,
            selectedId: selectedId,
            scrollController: scrollController,
          ),
        ),
      );
  }
}

class _ProjectList extends StatelessWidget {
  const new({
    required this.rows,
    required this.selectedId,
    required this.scrollController,
  });

  final List<ProjectTreeRow> rows;
  final int? selectedId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView.builder(
      controller: scrollController,
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.taskEditProjectPickerTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
          );
        }
        final row = rows[index - 1];
        final project = row.node.project;
        final selected = project.id == selectedId;
        final color = parseHexColor(project.hexColor);
        return ListTile(
          contentPadding: EdgeInsets.only(
            left: 16 + 20.0 * row.depth,
            right: 16,
          ),
          leading: Icon(
            Icons.folder_outlined,
            color: color ?? colors.onSurfaceVariant,
          ),
          title: Text(project.displayTitle(l10n)),
          selected: selected,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(project),
        );
      },
    );
  }
}
