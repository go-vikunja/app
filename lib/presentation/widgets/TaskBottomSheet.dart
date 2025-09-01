import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';

import '../../../core/utils/constants.dart';
import '../manager/project_store.dart';
import '../pages/task/task_edit.dart';
import 'label.dart';

class TaskBottomSheet extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final bool loading;
  final ValueSetter<bool>? onMarkedAsDone;
  final ProjectProvider taskState;

  const TaskBottomSheet({
    Key? key,
    required this.task,
    required this.taskState,
    this.loading = false,
    this.showInfo = false,
    this.onMarkedAsDone,
  }) : super(key: key);

  @override
  TaskBottomSheetState createState() => TaskBottomSheetState(this.task);
}

class TaskBottomSheetState extends State<TaskBottomSheet> {
  Task _currentTask;
  final double propertyPadding = 10.0;

  TaskBottomSheetState(this._currentTask);

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        child: SingleChildScrollView(
            child: Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 10, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                // Title and edit button
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: Text(_currentTask.title,
                        style: theme.textTheme.headlineLarge),
                  ),
                  IconButton(
                      onPressed: () {
                        Navigator.push<Task>(
                          context,
                          MaterialPageRoute(
                            builder: (buildContext) => TaskEditPage(
                              task: _currentTask,
                              taskState: widget.taskState,
                            ),
                          ),
                        ).then((task) => setState(() {
                              if (task != null) _currentTask = task;
                            }));
                      },
                      icon: Icon(Icons.edit)),
                ],
              ),
              SizedBox(height: propertyPadding),
              Wrap(
                  spacing: 10,
                  children: _currentTask.labels.map((Label label) {
                    return LabelComponent(
                      label: label,
                    );
                  }).toList()),

              // description with html rendering
              Text("Description", style: theme.textTheme.headlineSmall),
              SizedBox(height: propertyPadding),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
                child: HtmlWidget(_currentTask.description.isNotEmpty
                    ? _currentTask.description
                    : "No description"),
              ),
              SizedBox(height: propertyPadding),
              // Due date
              Row(
                children: [
                  Icon(Icons.access_time),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(_currentTask.hasDueDate
                      ? vDateFormatShort.format(_currentTask.dueDate!.toLocal())
                      : "No due date"),
                ],
              ),
              SizedBox(height: propertyPadding),
              // start date
              Row(
                children: [
                  Icon(Icons.play_arrow_rounded),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(_currentTask.hasStartDate
                      ? vDateFormatShort
                          .format(_currentTask.startDate!.toLocal())
                      : "No start date"),
                ],
              ),
              SizedBox(height: propertyPadding),
              // end date
              Row(
                children: [
                  Icon(Icons.stop_rounded),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(_currentTask.hasEndDate
                      ? vDateFormatShort.format(_currentTask.endDate!.toLocal())
                      : "No end date"),
                ],
              ),
              SizedBox(height: propertyPadding),
              // priority
              Row(
                children: [
                  Icon(Icons.priority_high),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(_currentTask.priority != null
                      ? priorityToString(_currentTask.priority)
                      : "No priority"),
                ],
              ),
              SizedBox(height: propertyPadding),
              // progress
              Row(
                children: [
                  Icon(Icons.percent),
                  Padding(padding: EdgeInsets.fromLTRB(10, 0, 0, 0)),
                  Text(_currentTask.percent_done != null
                      ? (_currentTask.percent_done! * 100).toInt().toString() +
                          "%"
                      : "Unset"),
                ],
              ),
            ],
          ),
        )));
  }
}
