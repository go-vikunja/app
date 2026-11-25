import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/tasks/application/task_row_content.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_rows.dart';
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
  required List<TaskAttachment>? attachments,
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
        attachments: attachments,
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
/// else "No description". With [onAdd] a tap on its text opens the editor
/// too, unless it lands on a link or a checkbox, while a long press still
/// selects.
class _Description extends StatefulWidget {
  const new({
    required this.task,
    required this.onLink,
    required this.onTaskLink,
    required this.onAdd,
    required this.onToggleTaskItem,
    required this.attachments,
  });

  final Task task;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final VoidCallback? onAdd;
  final void Function(String html, RichTaskItem item)? onToggleTaskItem;
  final List<TaskAttachment>? attachments;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  final _selectionArea = GlobalKey<SelectionAreaState>();
  var _selecting = false;

  /// Ends a selection, as the area's own tap would; else edits.
  void _tapped() {
    if (_selecting) {
      _selectionArea.currentState?.selectableRegion
        ?..hideToolbar()
        ..clearSelection();
      return;
    }
    widget.onAdd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final task = widget.task;
    final onAdd = widget.onAdd;
    final empty = onAdd == null
        ? DetailEmptyLine(text: l10n.taskDetailNoDescription)
        : DetailAddRow(label: l10n.taskDetailAddDescription, onPressed: onAdd);
    if (!hasDescription(task)) return empty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectionArea(
        key: _selectionArea,
        onSelectionChanged: (content) =>
            _selecting = content?.plainText.isNotEmpty ?? false,
        // Inside the area, so that its taps come first; links and
        // checkboxes lie deeper still and keep theirs.
        child: GestureDetector(
          onTap: onAdd == null ? null : _tapped,
          // Screen readers have Edit description in the heading.
          excludeFromSemantics: true,
          child: RichHtml(
            html: task.description,
            onLink: widget.onLink,
            onTaskLink: widget.onTaskLink,
            onToggleTaskItem: widget.onToggleTaskItem,
            style: theme.textTheme.bodyLarge,
            projectId: task.projectId,
            attachments: widget.attachments,
            empty: empty,
          ),
        ),
      ),
    );
  }
}
