import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/utils/misc.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/list_store.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function onEdit;
  final bool showInfo;
  final bool loading;
  final ValueSetter<bool> onMarkedAsDone;

  const TaskTile(
      {Key key, @required this.task, this.onEdit, this.loading = false, this.showInfo = false, this.onMarkedAsDone})
      : assert(task != null),
        super(key: key);
/*
  @override
  TaskTileState createState() {
    return new TaskTileState(this.task, this.loading);
  }

 */
@override
  TaskTileState createState() => TaskTileState(this.task);
}

class TaskTileState extends State<TaskTile> with AutomaticKeepAliveClientMixin {
  Task _currentTask;

  TaskTileState(this._currentTask)
      : assert(_currentTask != null);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Duration durationUntilDue = _currentTask.dueDate.difference(DateTime.now());
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
            _currentTask.description == null || _currentTask.description.isEmpty
                ? null
                : Text(_currentTask.description),
        trailing: IconButton(
            icon: Icon(Icons.settings), onPressed: () {  },
            ),
      );
    }
    return CheckboxListTile(
      title: widget.showInfo ?
          RichText(
            text: TextSpan(
              text: null,
              children: <TextSpan> [
                // TODO: get list name of task
                //TextSpan(text: widget.task.list.title+" - ", style: TextStyle(color: Colors.grey)),
                TextSpan(text: widget.task.title),
              ]
            )
          ) : Text(_currentTask.title),
      controlAffinity: ListTileControlAffinity.leading,
      value: _currentTask.done ?? false,
      subtitle: widget.showInfo && _currentTask.dueDate.year > 2 ?
          Text("Due " + durationToHumanReadable(durationUntilDue), style: TextStyle(color: durationUntilDue.isNegative ? Colors.red : null),)
          : _currentTask.description == null || _currentTask.description.isEmpty
              ? null
              : Text(_currentTask.description),
      secondary:
          IconButton(icon: Icon(Icons.settings), onPressed: () {
            Navigator.push<Task>(
              context,
              MaterialPageRoute(
                builder: (buildContext) => TaskEditPage(
                  task: _currentTask,
                  taskState: Provider.of<ListProvider>(context),
                ),
              ),
            ).then((task) => setState(() {
              if (task != null) _currentTask = task;
            })).whenComplete(() => widget.onEdit());
          }),
      onChanged: _change,
    );
  }

  void _change(bool value) async {
    setState(() {
      this._currentTask.loading = true;
    });
    Task newTask = await _updateTask(_currentTask, value);
    setState(() {
      this._currentTask = newTask;
      this._currentTask.loading = false;
    });
    widget.onEdit();
  }

  Future<Task> _updateTask(Task task, bool checked) {
    return Provider.of<ListProvider>(context, listen: false).updateTask(
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
