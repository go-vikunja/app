import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/components/datetimePicker.dart';
import 'package:vikunja_app/global.dart';
import 'dart:developer';
import '../models/task.dart';

enum NewTaskDue { day, week, month, custom }

// TODO: add to enum above
Map<NewTaskDue, Duration> newTaskDueToDuration = {
  NewTaskDue.day: Duration(days: 1),
  NewTaskDue.week: Duration(days: 7),
  NewTaskDue.month: Duration(days: 30),
};

class AddDialog extends StatefulWidget {
  final ValueChanged<String>? onAdd;
  final void Function(String title, DateTime? dueDate)? onAddTask;
  final InputDecoration? decoration;
  final String? prefilledTitle;
  const AddDialog(
      {Key? key,
      this.onAdd,
      this.decoration,
      this.onAddTask,
      this.prefilledTitle})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AddDialogState();
}

class AddDialogState extends State<AddDialog> with AfterLayoutMixin<AddDialog> {
  NewTaskDue newTaskDue = NewTaskDue.day;
  DateTime? customDueDate;
  var textController = TextEditingController();

  @override
  void afterFirstLayout(BuildContext context) {
    setState(() {
      textController.text = widget.prefilledTitle ?? "";
    });
    super.activate();
  }

  @override
  Widget build(BuildContext context) {
    if (newTaskDue != NewTaskDue.custom)
      customDueDate = DateTime.now().add(newTaskDueToDuration[newTaskDue]!);
    return new AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: new Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: <Widget>[
          Expanded(
            child: new TextField(
              autofocus: true,
              decoration: widget.decoration,
              controller: textController,
            ),
          ),
        ]),
        widget.onAddTask != null
            ? taskDueList("1 Day", NewTaskDue.day)
            : new Container(),
        widget.onAddTask != null
            ? taskDueList("1 Week", NewTaskDue.week)
            : new Container(),
        widget.onAddTask != null
            ? taskDueList("1 Month", NewTaskDue.month)
            : new Container(),
        widget.onAddTask != null
            ? VikunjaDateTimePicker(
                label: "Enter exact time",
                onChanged: (value) {
                  setState(() => newTaskDue = NewTaskDue.custom);
                  customDueDate = value;
                },
              )
            : new Container(),
        //],)
      ]),
      actions: <Widget>[
        new TextButton(
          child: const Text('CANCEL'),
          onPressed: () => Navigator.pop(context),
        ),
        new TextButton(
          child: const Text('ADD'),
          onPressed: () {
            if (widget.onAdd != null && textController.text.isNotEmpty)
              widget.onAdd!(textController.text);
            if (widget.onAddTask != null && textController.text.isNotEmpty) {
              widget.onAddTask!(textController.text, customDueDate);
            }
            Navigator.pop(context);
          },
        )
      ],
    );
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    return Row(children: [
      Checkbox(
        value: newTaskDue == thisNewTaskDue,
        onChanged: (value) {
          newTaskDue = thisNewTaskDue;
          setState(() => customDueDate =
              DateTime.now().add(newTaskDueToDuration[thisNewTaskDue]!));
        },
        shape: CircleBorder(),
      ),
      Text(name),
    ]);
  }
}
