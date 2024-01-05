import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/utils/misc.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/utils/priority.dart';

import '../stores/project_store.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function onEdit;
  final bool showInfo;
  final bool loading;
  final ValueSetter<bool>? onMarkedAsDone;

  const TaskTile({
    Key? key,
    required this.task,
    required this.onEdit,
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
  TaskTileState createState() => TaskTileState(this.task);
}

Widget? _buildTaskSubtitle(Task? task, bool showInfo) {
  Duration? durationUntilDue = task?.dueDate?.difference(DateTime.now());

  if(task == null)
    return null;

  List<TextSpan> texts = [];
  
  if(showInfo && task.hasDueDate) {
    texts.add(TextSpan(text: "Due " + durationToHumanReadable(durationUntilDue!), style: durationUntilDue.isNegative ? TextStyle(color: Colors.red) : null));
  }
  if(task.priority != null && task.priority != 0) {
    texts.add(TextSpan(text: " !" + priorityToString(task.priority), style: TextStyle(color: Colors.orange)));
  }

  if(texts.isEmpty && task.description.isNotEmpty) {
    return HtmlWidget(task.description);
  }

  if(texts.isNotEmpty) {
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
    final taskState = Provider.of<ProjectProvider>(context);
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
        subtitle:
            _currentTask.description.isEmpty
                ? null
                : HtmlWidget(_currentTask.description),
        trailing: IconButton(
            icon: Icon(Icons.settings), onPressed: () {  },
            ),
      );
    }
    return
    IntrinsicHeight(child:
      Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4.0, // Adjust the width of the red line
            color: widget.task.color,
            //margin: EdgeInsets.only(left: 10.0),
          ),
          Flexible(child: CheckboxListTile(
      title: widget.showInfo ?
          RichText(
            text: TextSpan(
              text: null,
              children: <TextSpan> [
                // TODO: get list name of task
                //TextSpan(text: widget.task.list.title+" - ", style: TextStyle(color: Colors.grey)),
                TextSpan(text: widget.task.title),
              ],
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            )
          ) : Text(_currentTask.title),
      controlAffinity: ListTileControlAffinity.leading,
      value: _currentTask.done,
      subtitle: _buildTaskSubtitle(widget.task, widget.showInfo),
      secondary:
          IconButton(icon: Icon(Icons.settings), onPressed: () {
            Navigator.push<Task>(
              context,
              MaterialPageRoute(
                builder: (buildContext) => TaskEditPage(
                  task: _currentTask,
                  taskState: taskState,
                ),
              ),
            ).then((task) => setState(() {
              if (task != null) _currentTask = task;
            })).whenComplete(() => widget.onEdit());
          }),
      onChanged: _change,
    ))]));
  }

  void _change(bool? value) async {
    value = value ?? false;
    setState(() {
      this._currentTask.loading = true;
    });
    Task? newTask = await _updateTask(_currentTask, value);
    setState(() {
      if(newTask != null)
        this._currentTask = newTask;
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
