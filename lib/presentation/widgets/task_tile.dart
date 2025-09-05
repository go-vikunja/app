import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/misc.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final Function onTap;
  final Function onEdit;
  final Function(bool value) onCheckedChanged;

  const TaskTile({
    super.key,
    this.showInfo = false,
    required this.task,
    required this.onTap,
    required this.onEdit,
    required this.onCheckedChanged,
  });

  @override
  TaskTileState createState() => TaskTileState();
}

class TaskTileState extends State<TaskTile> {
  TaskTileState();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 4.0, // Adjust the width of the red line
        color: widget.task.color,
      ),
      Flexible(
        child: ListTile(
          onTap: () {
            widget.onTap();
          },
          title: widget.showInfo
              ? RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: null,
                    children: <TextSpan>[
                      // TODO: get list name of task
                      TextSpan(text: widget.task.title),
                    ],
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ))
              : Text(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  widget.task.title,
                ),
          subtitle: _buildTaskSubtitle(widget.task, widget.showInfo, context),
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
      )
    ]));
  }

  Widget? _buildTaskSubtitle(Task task, bool showInfo, BuildContext context) {
    Duration? durationUntilDue = task.dueDate?.difference(DateTime.now());

    List<Widget> texts = [];

    if (showInfo && task.hasDueDate) {
      texts.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text("Due ${durationToHumanReadable(durationUntilDue!)}",
              style: durationUntilDue.isNegative
                  ? TextStyle(color: Colors.red)
                  : Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    if (task.priority != null && task.priority != 0) {
      texts.add(
        Text(
          "!${priorityToString(task.priority)}",
          style: TextStyle(color: Colors.orange),
        ),
      );
    }

    return Row(children: texts);
  }
}
