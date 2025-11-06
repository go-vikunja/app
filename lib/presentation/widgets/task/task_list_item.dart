import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

class TaskListItem extends StatefulWidget {
  final Task task;
  final Function onTap;
  final Function onEdit;
  final Function(bool value) onCheckedChanged;

  const TaskListItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onEdit,
    required this.onCheckedChanged,
  });

  @override
  TaskListItemState createState() => TaskListItemState();
}

class TaskListItemState extends State<TaskListItem> {
  TaskListItemState();

  @override
  Widget build(BuildContext context) {
    var isThreeLine =
        widget.task.hasDueDate ||
        widget.task.priority != null && widget.task.priority != 0;

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
          subtitle: _buildTaskSubtitle(widget.task, context),
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
          height: isThreeLine ? 86.0 : 72.0,
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

    var project = task.project;

    if (texts.isEmpty) {
      if (project != null) {
        return Text(project.title);
      }

      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (project != null)
            Text(project.title, style: Theme.of(context).textTheme.bodyMedium),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(children: texts),
          ),
        ],
      ),
    );
  }
}
