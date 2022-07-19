import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/theme/constants.dart';

class BucketTaskCard extends StatefulWidget {
  final Task task;

  const BucketTaskCard({Key key, @required this.task})
      : assert(task != null),
        super(key: key);

  @override
  State<BucketTaskCard> createState() => _BucketTaskCardState(this.task);
}

class _BucketTaskCardState extends State<BucketTaskCard> {
  Task _currentTask;

  _BucketTaskCardState(this._currentTask)
      : assert(_currentTask != null);

  @override
  Widget build(BuildContext context) {
    final numRow = Row(
      children: <Widget>[
        Text('#${_currentTask.id}'),
      ],
    );
    if (_currentTask.done) {
      numRow.children.insert(0, Chip(
        label: Text('Done'),
        labelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme
              .of(context)
              .brightness == Brightness.dark
              ? Colors.black : Colors.white,
        ),
        backgroundColor: vGreen,
      ));
    }

    final titleRow = Row(
      children: <Widget>[
        Text(_currentTask.title),
      ],
    );
    // TODO: add due date

    final labelRow = Row();
    // TODO: add labels, checklist completion, attachment icon, description icon

    return Card(
      child: InkWell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[numRow, titleRow, labelRow],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskEditPage(
            task: _currentTask,
          )),
        ),
      ),
    );
  }
}
