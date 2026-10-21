import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/hex_color.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';

/// The account's default project: 0 for none, null when dismissed. Archived
/// projects are left out, as the server refuses them.
Future<int?> pickDefaultProject(
  BuildContext context, {
  required List<Project> projects,
  required int? selectedId,
}) => showPickerSheet<int>(
  context,
  heightFactor: 0.7,
  builder: (context, scrollController) => _DefaultProjectList(
    rows: selectableProjects(projects),
    selectedId: selectedId ?? 0,
    scrollController: scrollController,
  ),
);

/// What the default project row shows for [projectId].
String defaultProjectLabel(
  AppLocalizations l10n,
  int? projectId,
  List<Project> projects,
) {
  if (projectId == null || projectId == 0) {
    return l10n.accountSettingsDefaultProjectNone;
  }
  for (final project in projects) {
    if (project.id == projectId) return project.displayTitle(l10n);
  }
  return l10n.accountSettingsDefaultProjectUnknown;
}

class _DefaultProjectList extends StatelessWidget {
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
        PickerHeader(title: l10n.accountSettingsDefaultProject),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              row(
                id: 0,
                title: l10n.accountSettingsDefaultProjectNone,
                leading: Icon(Icons.block, color: colors.onSurfaceVariant),
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
