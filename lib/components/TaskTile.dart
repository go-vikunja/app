import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final VoidCallback onEdit;
  final bool loading;

  const TaskTile({Key key, @required this.task, this.onEdit, this.loading = false})
      : assert(task != null),
        super(key: key);

  @override
  TaskTileState createState() {
    return new TaskTileState(this.task, this.loading);
  }
}

class TaskTileState extends State<TaskTile> {
  bool _loading;
  Task _currentTask;

  TaskTileState(this._currentTask, this._loading)
      : assert(_currentTask != null),
        assert(_loading != null);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
        subtitle: _currentTask.description == null || _currentTask.description.isEmpty
            ? null
            : Text(_currentTask.description),
        trailing: IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {}, // TODO: implement edit task
        ),
      );
    }
    return CheckboxListTile(
      title: Text(_currentTask.title),
      controlAffinity: ListTileControlAffinity.leading,
      value: _currentTask.done ?? false,
      subtitle: _currentTask.description == null || _currentTask.description.isEmpty
          ? null
          : Text(_currentTask.description),
      secondary: IconButton(
          icon: Icon(Icons.settings),
          onPressed: widget.onEdit,
      ),
      onChanged: _change,
    );
  }

  void _change(bool value) async {
    setState(() {
      this._loading = true;
    });
    Task newTask = await _updateTask(_currentTask, value);
    setState(() {
      this._currentTask = newTask;
      this._loading = false;
    });
  }

  Future<Task> _updateTask(Task task, bool checked) {
    // TODO use copyFrom
    return VikunjaGlobal.of(context).taskService.update(
        Task(
          id: task.id,
          done: checked,
          title: task.title,
          description: task.description,
          owner: null,
        )
    );
  }
}

typedef Future<void> TaskChanged(Task task, bool newValue);
