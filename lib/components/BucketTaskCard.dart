import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/utils/misc.dart';
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
    // default chip height: 32
    const double chipHeight = 28;
    final chipConstraints = BoxConstraints(maxHeight: chipHeight);

    final numRow = Row(
      children: <Widget>[
        Text(
          '#${_currentTask.id}',
          style: TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
    if (_currentTask.done) {
      numRow.children.insert(0, Container(
        constraints: chipConstraints,
        padding: EdgeInsets.only(right: 4),
        child: FittedBox(
          child: Chip(
            label: Text('Done'),
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black : Colors.white,
            ),
            backgroundColor: vGreen,
          ),
        ),
      ));
    }

    final titleRow = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _currentTask.title,
            style: TextStyle(
              fontSize: 16,
              color: _currentTask.textColor,
            ),
          ),
        ),
      ],
    );
    final duration = _currentTask.dueDate.difference(DateTime.now());
    if (_currentTask.dueDate.year > 2) {
      titleRow.children.add(Container(
        constraints: chipConstraints,
        padding: EdgeInsets.only(left: 4),
        child: FittedBox(
          child: Chip(
            avatar: Icon(
              Icons.calendar_month,
              color: duration.isNegative ? Colors.red : null,
            ),
            label: Text(durationToHumanReadable(duration)),
            labelStyle: duration.isNegative ? TextStyle(color: Colors.red) : null,
            backgroundColor: duration.isNegative ? Colors.red.withAlpha(20) : null,
          ),
        ),
      ));
    }

    final labelRow = Wrap(
      children: <Widget>[],
      spacing: 4,
      runSpacing: 4,
    );
    _currentTask.labels?.sort((a, b) => a.title.compareTo(b.title));
    _currentTask.labels?.asMap()?.forEach((i, label) {
      labelRow.children.add(Chip(
        label: Text(label.title),
        labelStyle: TextStyle(color: label.textColor),
        backgroundColor: label.color,
      ));
    });
    if (_currentTask.description.isNotEmpty) {
      final uncompletedTaskCount = '* [ ]'.allMatches(_currentTask.description).length;
      final completedTaskCount = '* [x]'.allMatches(_currentTask.description).length;
      final taskCount = uncompletedTaskCount + completedTaskCount;
      if (taskCount > 0) {
        labelRow.children.add(Chip(
          avatar: Container(
            constraints: BoxConstraints(maxHeight: 16, maxWidth: 16),
            child: CircularProgressIndicator(
              value: uncompletedTaskCount == 0
                  ? 1 : uncompletedTaskCount.toDouble() / taskCount.toDouble(),
              backgroundColor: Colors.grey,
            )  ,
          ),
          label: Text(
              (uncompletedTaskCount == 0 ? '' : '$completedTaskCount of ')
                  + '$taskCount tasks'
          ),
        ));
      }
    }
    if (_currentTask.attachments != null && _currentTask.attachments.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Transform.rotate(
          angle: -pi / 4.0,
          child: Icon(Icons.attachment),
        ),
      ));
    }
    if (_currentTask.description.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Icon(Icons.notes),
      ));
    }

    final rowConstraints = BoxConstraints(minHeight: chipHeight);
    return Card(
      color: _currentTask.color,
      child: InkWell(
        child: Theme(
          data: Theme.of(context).copyWith(
            // Remove enforced margins
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  constraints: rowConstraints,
                  child: numRow,
                ),
                Container(
                  constraints: rowConstraints,
                  child: titleRow,
                ),
                Padding(
                  padding: labelRow.children.isNotEmpty
                      ? EdgeInsets.only(top: 8) : EdgeInsets.zero,
                  child: labelRow,
                ),
              ],
            ),
          ),
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
