import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/core/utils/misc.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';

import '../manager/project_store.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function onEdit;
  final bool showInfo;
  final ValueSetter<bool>? onMarkedAsDone;

  const TaskTile({
    Key? key,
    required this.task,
    required this.onEdit,
    this.showInfo = false,
    this.onMarkedAsDone,
  }) : super(key: key);

  @override
  TaskTileState createState() => TaskTileState(this.task);
}

Widget? _buildTaskSubtitle(Task? task, bool showInfo, BuildContext context) {
  Duration? durationUntilDue = task?.dueDate?.difference(DateTime.now());

  if (task == null) return null;

  List<TextSpan> texts = [];

  if (showInfo && task.hasDueDate) {
    texts.add(TextSpan(
        text: "Due " + durationToHumanReadable(durationUntilDue!),
        style: durationUntilDue.isNegative
            ? TextStyle(color: Colors.red)
            : Theme.of(context).textTheme.bodyMedium));
  }
  if (task.priority != null && task.priority != 0) {
    texts.add(TextSpan(
        text: " !" + priorityToString(task.priority),
        style: TextStyle(color: Colors.orange)));
  }

  if (texts.isNotEmpty) {
    return RichText(text: TextSpan(children: texts));
  }
  return null;
}

class TaskTileState extends State<TaskTile> with AutomaticKeepAliveClientMixin {
  Task _currentTask;

  TaskTileState(this._currentTask);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_currentTask.loading) {
      return ListTile(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
              height: Checkbox.width,
              width: Checkbox.width,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
              )),
        ),
        title: Text(_currentTask.title),
        subtitle: _currentTask.description.isEmpty
            ? null
            : HtmlWidget(_currentTask.description),
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: () {},
        ),
      );
    }
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        width: 4.0, // Adjust the width of the red line
        color: widget.task.color,
        //margin: EdgeInsets.only(left: 10.0),
      ),
      Flexible(
          child: ListTile(
        onTap: () {
          showModalBottomSheet<void>(
              context: context,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
              ),
              builder: (BuildContext context) {
                return TaskBottomSheet(task: widget.task);
              });
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
                _currentTask.title),
        subtitle: _buildTaskSubtitle(widget.task, widget.showInfo, context),
        leading: Checkbox(
          value: _currentTask.done,
          onChanged: (bool? newValue) {
            _change(newValue);
          },
        ),
        trailing: IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              Navigator.push<Task>(
                context,
                MaterialPageRoute(
                  builder: (buildContext) => TaskEditPage(
                    task: _currentTask,
                  ),
                ),
              )
                  .then((task) => setState(() {
                        if (task != null) _currentTask = task;
                      }))
                  .whenComplete(() => widget.onEdit());
            }),
      ))
    ]));
  }

  void _change(bool? value) async {
    value = value ?? false;
    setState(() {
      this._currentTask.loading = true;
    });
    Task? newTask = await _updateTask(_currentTask, value);
    setState(() {
      if (newTask != null) this._currentTask = newTask;
      this._currentTask.loading = false;
    });
    widget.onEdit();
  }

  Future<Task?> _updateTask(Task task, bool checked) {
    return Provider.of<ProjectProvider>(context, listen: false).updateTask(
      context: context,
      task: task.copyWith(
        done: checked,
      ),
    );
  }

  @override
  bool get wantKeepAlive => _currentTask != widget.task;
}

typedef Future<void> TaskChanged(Task task, bool newValue);
