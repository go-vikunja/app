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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4.0, // Adjust the width of the red line
            color: widget.task.color,
          ),
          Flexible(
            child: ListTile(
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
          ),
        ],
      ),
    );
  }

  Widget? _buildTaskSubtitle(Task task, BuildContext context) {
    List<Widget> texts = [];

    if (task.hasDueDate) {
      texts.add(DueDateCard(task.dueDate!));
    }
    if (task.priority != null && task.priority != 0) {
      texts.add(
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: PriorityBatch(task.priority!),
        ),
      );
    }

    if (texts.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(children: texts),
          ),
        ],
      ),
    );
  }
}
