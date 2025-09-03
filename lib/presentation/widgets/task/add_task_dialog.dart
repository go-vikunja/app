import 'package:flutter/material.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';

enum NewTaskDue { day, week, month, custom }

// TODO: add to enum above
Map<NewTaskDue, Duration> newTaskDueToDuration = {
  NewTaskDue.day: Duration(days: 1),
  NewTaskDue.week: Duration(days: 7),
  NewTaskDue.month: Duration(days: 30),
};

class AddTaskDialog extends StatefulWidget {
  final void Function(String title, DateTime? dueDate)? onAddTask;
  final InputDecoration? decoration;

  const AddTaskDialog({Key? key, this.decoration, this.onAddTask})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends State<AddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.day;
  DateTime? customDueDate;
  var textController = TextEditingController();

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
            ? VikunjaDateTimeField(
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
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        new TextButton(
          child: const Text('Add'),
          onPressed: () {
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
