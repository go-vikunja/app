import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/utils/priority.dart';

import '../models/label.dart';
import '../models/task.dart';
import '../pages/list/task_edit.dart';
import '../stores/project_store.dart';
import '../theme/constants.dart';
import 'label.dart';

class TaskBottomSheet extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final bool loading;
  final Function onEdit;
  final ValueSetter<bool>? onMarkedAsDone;
  final ProjectProvider taskState;

  const TaskBottomSheet({
    Key? key,
    required this.task,
    required this.onEdit,
    required this.taskState,
    this.loading = false,
    this.showInfo = false,
    this.onMarkedAsDone,
  }) : super(key: key);
/*
  @override
  TaskTileState createState() {
    return new TaskTileState(this.task, this.loading);
  }

 */
  @override
  TaskBottomSheetState createState() => TaskBottomSheetState(this.task);
}

class TaskBottomSheetState extends State<TaskBottomSheet> {
  Task _currentTask;

  TaskBottomSheetState(this._currentTask);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      child:  Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 10, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,

          children: <Widget>[
            Row(
              // Title and edit button
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_currentTask.title, style: theme.textTheme.headlineLarge),
                IconButton(onPressed: () {
                  Navigator.push<Task>(
                    context,
                    MaterialPageRoute(
                      builder: (buildContext) => TaskEditPage(
                        task: _currentTask,
                        taskState: widget.taskState,
                      ),
                    ),
                  )
                      .then((task) => setState(() {
                    if (task != null) _currentTask = task;
                  }))
                      .whenComplete(() => widget.onEdit());
                }, icon: Icon(Icons.edit)),
              ],
            ),
            Wrap(
                spacing: 10,
                children: _currentTask.labels.map((Label label) {
                  return LabelComponent(
                    label: label,
                  );
                }).toList()),

            // description with html rendering
            Text("Description", style: theme.textTheme.headlineSmall),
            Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
              child: HtmlWidget(_currentTask.description.isNotEmpty ? _currentTask.description : "No description"),
              ),
            // Due date
            Row(
              children: [
                Icon(Icons.access_time),
                Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                Text(_currentTask.dueDate != null ? vDateFormatShort.format(_currentTask.dueDate!.toLocal()) : "No due date"),
              ],
            ),
            // start date
            Row(
              children: [
                Icon(Icons.play_arrow_rounded),
                Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                Text(_currentTask.startDate != null ? vDateFormatShort.format(_currentTask.startDate!.toLocal()) : "No start date"),
              ],
            ),
            // end date
            Row(
              children: [
                Icon(Icons.stop_rounded),
                Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                Text(_currentTask.endDate != null ? vDateFormatShort.format(_currentTask.endDate!.toLocal()) : "No end date"),
              ],
            ),
            // priority
            Row(
              children: [
                Icon(Icons.priority_high),
                Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                Text(_currentTask.priority != null ? priorityToString(_currentTask.priority) : "No priority"),
              ],
            ),
            // progress
            Row(
              children: [
                Icon(Icons.percent),
                Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                Text(_currentTask.percent_done != null ? (_currentTask.percent_done! * 100).toInt().toString() + "%" : "Unset"),
              ],
            ),
          ],
        ),
        )

    );
  }

}