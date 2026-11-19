import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

enum TaskDetailMenuAction { moveToColumn, copyLink, share, duplicate, delete }

/// The detail's More menu: Move to column… with [moves], Copy link and
/// Share with [links], then with [changes] Duplicate, disabled while
/// [duplicating], and Delete. [buttonKey] is its button's, whose place
/// the share sheet starts from on an iPad.
class TaskDetailMenu extends StatelessWidget {
  const new({
    required this.moves,
    required this.links,
    required this.changes,
    required this.duplicating,
    required this.inPane,
    required this.taskTitle,
    required this.onSelected,
    this.buttonKey,
    super.key,
  });

  final bool moves;
  final bool links;
  final bool changes;
  final bool duplicating;
  final bool inPane;
  final String taskTitle;
  final ValueChanged<TaskDetailMenuAction> onSelected;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    PopupMenuItem<TaskDetailMenuAction> menuItem(
      TaskDetailMenuAction action,
      IconData icon,
      String text, {
      bool enabled = true,
      Color? color,
    }) => PopupMenuItem(
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
    final menuItems = <PopupMenuEntry<TaskDetailMenuAction>>[
      if (moves)
        menuItem(
          TaskDetailMenuAction.moveToColumn,
          Icons.view_kanban_outlined,
          l10n.taskMoveToColumn,
        ),
      if (links) ...[
        menuItem(TaskDetailMenuAction.copyLink, Icons.link, l10n.taskCopyLink),
        menuItem(
          TaskDetailMenuAction.share,
          Icons.share_outlined,
          l10n.taskShareLink,
        ),
      ],
      if (changes) ...[
        if (moves || links) const PopupMenuDivider(),
        menuItem(
          TaskDetailMenuAction.duplicate,
          Icons.content_copy_outlined,
          l10n.taskDuplicate,
          enabled: !duplicating,
        ),
        const PopupMenuDivider(),
        menuItem(
          TaskDetailMenuAction.delete,
          Icons.delete_outline,
          l10n.taskDelete,
          color: colors.error,
        ),
      ],
    ];
    return PopupMenuButton<TaskDetailMenuAction>(
      key: buttonKey,
      // Beside the screen's own More in the pane.
      tooltip: inPane ? l10n.taskDetailPaneMore(taskTitle) : l10n.moreActions,
      onSelected: onSelected,
      itemBuilder: (context) => menuItems,
    );
  }
}
