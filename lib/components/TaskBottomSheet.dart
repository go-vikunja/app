import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../models/task.dart';

class TaskBottomSheet extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final bool loading;
  final ValueSetter<bool>? onMarkedAsDone;

  const TaskBottomSheet({
    Key? key,
    required this.task,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,

          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_currentTask.title),
                BackButton(),
              ],
            ),
            HtmlWidget(_currentTask.description),
          ],
        ),
        )
      ),
    );
  }

}