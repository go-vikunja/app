import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';
import 'package:vikunja_app/presentation/pages/task/task_comments_page.dart';

enum _ProjectTaskMenuAction { comments, edit }

class ProjectTaskListItem extends StatefulWidget {
  final Task task;
  final Function onTap;
  final Function onEdit;
  final Function(bool value) onCheckedChanged;

  const ProjectTaskListItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onEdit,
    required this.onCheckedChanged,
  });

  @override
  ProjectTaskListItemState createState() => ProjectTaskListItemState();
}

class ProjectTaskListItemState extends State<ProjectTaskListItem> {
  ProjectTaskListItemState();

  void _handleMenuAction(
    BuildContext context,
    _ProjectTaskMenuAction action,
  ) {
    switch (action) {
      case _ProjectTaskMenuAction.comments:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskCommentsPage(
              taskId: widget.task.id,
              taskTitle: widget.task.title,
            ),
          ),
        );
        break;
      case _ProjectTaskMenuAction.edit:
        widget.onEdit();
        break;
    }
  }

  List<PopupMenuEntry<_ProjectTaskMenuAction>> _menuItems(
    BuildContext context,
  ) {
    final localizations = AppLocalizations.of(context);
    return [
      PopupMenuItem(
        value: _ProjectTaskMenuAction.comments,
        child: Text(localizations.comments),
      ),
      PopupMenuItem(
        value: _ProjectTaskMenuAction.edit,
        child: Text(localizations.edit),
      ),
    ];
  }

  void _openTaskMenuAt(BuildContext context, Offset globalPosition) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );

    showMenu<_ProjectTaskMenuAction>(
      context: context,
      position: position,
      items: _menuItems(context),
    ).then((action) {
      if (action != null) {
        _handleMenuAction(context, action);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var subtitle = _buildTaskSubtitle(widget.task, context);

    return Stack(
      fit: StackFit.loose,
      children: [
        GestureDetector(
          onLongPressStart: (details) =>
              _openTaskMenuAt(context, details.globalPosition),
          child: ListTile(
            onTap: () {
              widget.onTap();
            },
            contentPadding: const EdgeInsetsDirectional.only(
              start: 16.0,
              end: 8.0,
            ),
            title: Text(
              widget.task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitle,
            leading: Checkbox(
              value: widget.task.done,
              onChanged: (bool? newValue) {
                if (newValue != null) {
                  widget.onCheckedChanged(newValue);
                }
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_ProjectTaskMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _handleMenuAction(context, action),
                  itemBuilder: _menuItems,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 4.0,
          height: subtitle != null ? 68.0 : 56.0,
          color: widget.task.color,
        ),
      ],
    );
  }

  Widget? _buildTaskSubtitle(Task task, BuildContext context) {
    List<Widget> texts = [];

    if (task.hasDueDate) {
      texts.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DueDateCard(task.dueDate!),
        ),
      );
    }
    if (task.priority != null && task.priority != 0) {
      texts.add(PriorityBatch(task.priority!));
    }

    if (texts.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: Row(children: texts),
    );
  }
}
