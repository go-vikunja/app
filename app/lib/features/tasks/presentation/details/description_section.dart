import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

/// The description's rows for the sheet's list: the heading with the
/// checklist's progress and, once there is a description, Edit; then the
/// card with the description, or Add description. [onEdit] opens the
/// editor; null where the description may not be changed.
List<Widget> descriptionSection({
  required Task task,
  required ValueChanged<String> onLink,
  required ValueChanged<int> onTaskLink,
  required VoidCallback? onEdit,
  required void Function(String html, RichTaskItem item)? onToggleTaskItem,
}) => [
  _DescriptionHeader(task: task, onEdit: onEdit),
  SectionCard(
    children: [
      _Description(
        task: task,
        onLink: onLink,
        onTaskLink: onTaskLink,
        onAdd: onEdit,
        onToggleTaskItem: onToggleTaskItem,
      ),
    ],
  ),
];

class _DescriptionHeader extends StatelessWidget {
  const new({required this.task, required this.onEdit});

  final Task task;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checklist = checklistStatistics(task.description);
    final onEdit = this.onEdit;
    return DetailSectionHeader(
      title: l10n.taskDetailDescription,
      trailing: checklist.total > 0
          ? ChecklistSummary(statistics: checklist, style: null)
          : null,
      actions: [
        if (onEdit != null && hasDescription(task))
          IconButton(
            onPressed: onEdit,
            tooltip: l10n.taskDetailEditDescription,
            icon: const Icon(Icons.edit_note),
          ),
      ],
    );
  }
}

/// Selectable rich text whose checkboxes take taps when [onToggleTaskItem]
/// is set; without visible content "Add description" when [onAdd] is set,
/// else "No description".
class _Description extends StatelessWidget {
  const new({
    required this.task,
    required this.onLink,
    required this.onTaskLink,
    required this.onAdd,
    required this.onToggleTaskItem,
  });

  final Task task;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final VoidCallback? onAdd;
  final void Function(String html, RichTaskItem item)? onToggleTaskItem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final onAdd = this.onAdd;
    final empty = onAdd == null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.taskDetailNoDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        // The button's own padding lines its icon up with the card's text.
        : Padding(
            padding: const EdgeInsets.all(4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.taskDetailAddDescription),
              ),
            ),
          );
    if (!hasDescription(task)) return empty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        child: RichHtml(
          html: task.description,
          onLink: onLink,
          onTaskLink: onTaskLink,
          onToggleTaskItem: onToggleTaskItem,
          style: theme.textTheme.bodyLarge,
          projectId: task.projectId,
          empty: empty,
        ),
      ),
    );
  }
}
