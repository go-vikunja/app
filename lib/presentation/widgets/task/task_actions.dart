import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_comments_page.dart';

enum TaskActionsVariant { menu, icons }

enum _TaskAction { comments, edit }

class TaskActions extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final TaskActionsVariant variant;
  final VoidCallback? onBeforeAction;

  const TaskActions({
    super.key,
    required this.task,
    required this.onEdit,
    required this.variant,
    this.onBeforeAction,
  });

  void _openComments(BuildContext context) {
    onBeforeAction?.call();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TaskCommentsPage(taskId: task.id, taskTitle: task.title),
      ),
    );
  }

  void _edit() {
    onBeforeAction?.call();
    onEdit();
  }

  void _handleMenuAction(BuildContext context, _TaskAction action) {
    switch (action) {
      case _TaskAction.comments:
        _openComments(context);
        break;
      case _TaskAction.edit:
        _edit();
        break;
    }
  }

  List<PopupMenuEntry<_TaskAction>> _menuItems(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return [
      PopupMenuItem(
        value: _TaskAction.comments,
        child: Text(localizations.comments),
      ),
      PopupMenuItem(value: _TaskAction.edit, child: Text(localizations.edit)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case TaskActionsVariant.menu:
        return PopupMenuButton<_TaskAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) => _handleMenuAction(context, action),
          itemBuilder: _menuItems,
        );
      case TaskActionsVariant.icons:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _openComments(context),
              icon: const Icon(Icons.comment),
              tooltip: AppLocalizations.of(context).comments,
            ),
            IconButton(onPressed: _edit, icon: const Icon(Icons.edit)),
          ],
        );
    }
  }
}
