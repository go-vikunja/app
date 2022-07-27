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

class _BucketTaskCardState extends State<BucketTaskCard> with AutomaticKeepAliveClientMixin {
  Task _currentTask;

  _BucketTaskCardState(this._currentTask)
      : assert(_currentTask != null);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // default chip height: 32
    const double chipHeight = 28;
    final chipConstraints = BoxConstraints(maxHeight: chipHeight);
    final theme = Theme.of(context);

    final numRow = Row(
      children: <Widget>[
        Text(
          '#${_currentTask.id}',
          style: theme.textTheme.subtitle2.copyWith(
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
            labelStyle: theme.textTheme.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.brightness == Brightness.dark
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
            style: theme.textTheme.titleMedium.copyWith(
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
            labelStyle: theme.textTheme.labelLarge.copyWith(
              color: duration.isNegative ? Colors.red : null,
            ),
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
        labelStyle: theme.textTheme.labelLarge.copyWith(
          color: label.textColor,
        ),
        backgroundColor: label.color,
      ));
    });
    if (_currentTask.description.isNotEmpty) {
      final uncompletedTaskCount = '* [ ]'.allMatches(_currentTask.description).length;
      final completedTaskCount = '* [x]'.allMatches(_currentTask.description).length;
      final taskCount = uncompletedTaskCount + completedTaskCount;
      if (taskCount > 0) {
        final iconSize = (theme.textTheme.labelLarge.fontSize ?? 14) + 2;
        labelRow.children.add(Chip(
          avatar: Container(
            constraints: BoxConstraints(maxHeight: iconSize, maxWidth: iconSize),
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
        onTap: () => Navigator.push<Task>(
          context,
          MaterialPageRoute(builder: (context) => TaskEditPage(
            task: _currentTask,
          )),
        ).then((task) => setState(() {
          if (task != null) _currentTask = task;
        })),
      ),
    );
  }

  @override
  bool get wantKeepAlive => _currentTask != widget.task;
}
