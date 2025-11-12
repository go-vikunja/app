import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

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

  @override
  Widget build(BuildContext context) {
    var subtitle = _buildTaskSubtitle(widget.task, context);

    return Stack(
      fit: StackFit.loose,
      children: [
        ListTile(
          onTap: () {
            widget.onTap();
          },
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
          trailing: IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => widget.onEdit(),
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
