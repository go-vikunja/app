import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/projects/application/project_management.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// The parent for a new or moved project: 0 for the top level, null when
/// dismissed. Leaves out archived projects and, with [movedProjectId], that
/// project and its subprojects, which the server refuses as parents.
Future<int?> pickParentProject(
  BuildContext context, {
  required List<Project> projects,
  required int selectedId,
  int? movedProjectId,
}) {
  final rows = parentCandidates(projects, movedProjectId: movedProjectId);
  return showPickerSheet<int>(
    context,
    heightFactor: 0.7,
    builder: (context, scrollController) => _ParentList(
      rows: rows,
      selectedId: selectedId,
      scrollController: scrollController,
    ),
  );
}

/// What the parent row of a form shows for [parentId].
String parentProjectLabel(
  AppLocalizations l10n,
  int parentId,
  List<Project> projects,
) {
  if (parentId == 0) return l10n.projectParentTopLevel;
  for (final project in projects) {
    if (project.id == parentId) return project.displayTitle(l10n);
  }
  return l10n.projectUnknownTitle;
}

class _ParentList extends StatelessWidget {
  const new({
    required this.rows,
    required this.selectedId,
    required this.scrollController,
  });

  final List<ProjectTreeRow> rows;
  final int selectedId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    Widget row({
      required int id,
      required String title,
      required Widget leading,
      int depth = 0,
    }) {
      final selected = id == selectedId;
      return ListTile(
        contentPadding: EdgeInsetsDirectional.only(
          start: 16 + 20.0 * depth,
          end: 16,
        ),
        leading: leading,
        title: Text(title),
        selected: selected,
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () => Navigator.of(context).pop(id),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerHeader(title: l10n.projectParentLabel),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              row(
                id: 0,
                title: l10n.projectParentTopLevel,
                leading: Icon(
                  Icons.vertical_align_top,
                  color: colors.onSurfaceVariant,
                ),
              ),
              for (final candidate in rows)
                row(
                  id: candidate.node.project.id,
                  title: candidate.node.project.displayTitle(l10n),
                  depth: candidate.depth,
                  leading: Icon(
                    Icons.folder_outlined,
                    color:
                        parseHexColor(candidate.node.project.hexColor) ??
                        colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
