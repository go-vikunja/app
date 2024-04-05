import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/components/TaskBottomSheet.dart';
import 'package:vikunja_app/models/project.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/project_store.dart';
import 'package:vikunja_app/utils/misc.dart';
import 'package:vikunja_app/utils/priority.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function onEdit;
  final bool showInfo;
  final bool loading;
  final ValueSetter<bool>? onMarkedAsDone;
  final Map<int, Project>? projectsMap;

  const TaskTile({
    Key? key,
    required this.task,
    required this.onEdit,
    this.projectsMap,
    this.loading = false,
    this.showInfo = false,
    this.onMarkedAsDone,
  }) : super(key: key);

  @override
  _TaskTileState createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final taskState = Provider.of<ProjectProvider>(context);
    return ListTile(
      onTap: () {
        _showBottomSheet(context, taskState);
      },
      leading: _buildLeading(),
      title: _buildTitle(),
      subtitle: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSubtitle(context),
          SizedBox(height: 8),
          buildChip() ?? Container(),
        ],
      ),
      trailing: _buildTrailing(context),
    );
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

  Widget _buildLeading() {
    return Checkbox(
      value: _currentTask.done,
      onChanged: (bool? newValue) {
        _change(newValue);
      },
    );
  }

  Widget _buildTitle() {
    return widget.showInfo
        ? RichText(
            text: TextSpan(
              text: null,
              children: <TextSpan>[
                TextSpan(
                  text: widget.task.title,
                  style: TextStyle(
                    decoration:
                        _currentTask.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          )
        : Text(
            _currentTask.title,
            style: TextStyle(
              decoration: _currentTask.done ? TextDecoration.lineThrough : null,
            ),
          );
  }

  Widget _buildSubtitle(BuildContext context) {
    final durationUntilDue = _currentTask.dueDate?.difference(DateTime.now());
    if (widget.loading) {
      return CircularProgressIndicator(
        strokeWidth: 2.0,
      );
    } else if (widget.showInfo && _currentTask.hasDueDate) {
      return Text(
        "Due " + durationToHumanReadable(durationUntilDue!),
        style: TextStyle(
          color: durationUntilDue.isNegative ? Colors.red : null,
        ),
      );
    } else if (_currentTask.priority != null && _currentTask.priority != 0) {
      return Text(
        " !" + priorityToString(_currentTask.priority),
        style: TextStyle(color: Colors.orange),
      );
    } else if (_currentTask.description.isNotEmpty) {
      return HtmlWidget(_currentTask.description);
    } else {
      return Container();
    }
  }

  Widget _buildTrailing(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.edit),
      onPressed: () {
        Navigator.push<Task>(
          context,
          MaterialPageRoute(
            builder: (buildContext) => TaskEditPage(
              task: _currentTask,
              taskState: Provider.of<ProjectProvider>(context, listen: false),
            ),
          ),
        ).then((task) {
          if (task != null) {
            setState(() {
              _currentTask = task;
            });
          }
          widget.onEdit();
        });
      },
    );
  }

  void _showBottomSheet(BuildContext context, ProjectProvider taskState) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return TaskBottomSheet(
          task: widget.task,
          onEdit: widget.onEdit,
          taskState: taskState,
        );
      },
    );
  }

  Widget? buildChip() {
    if (_currentTask.projectId == null || widget.projectsMap == null) {
      return null;
    }
    Project? p = widget.projectsMap![_currentTask.projectId!];
    if (p != null) {
      return Transform(
        transform: new Matrix4.identity()..scale(0.8),
        child: Chip(
          label: Text(p.title),
          backgroundColor: p.color,
          labelStyle: TextStyle(color: Colors.white),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity(horizontal: 0.0, vertical: -4),
        ),
      );
    }
    return null;
  }
}
