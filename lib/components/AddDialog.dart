import 'package:flutter/material.dart';

import '../models/task.dart';

enum NewTaskDue {day,week, month}
Map<NewTaskDue, Duration> newTaskDueToDuration = {
  NewTaskDue.day: Duration(days: 1),
  NewTaskDue.week: Duration(days: 7),
  NewTaskDue.month: Duration(days: 30),
};

class AddDialog extends StatefulWidget {
  final ValueChanged<String> onAdd;
  final ValueChanged<Task> onAddTask;
  final InputDecoration decoration;
  const AddDialog({Key key, this.onAdd, this.decoration, this.onAddTask}) : super(key: key);

  @override
  State<StatefulWidget> createState() => AddDialogState();

}

class AddDialogState extends State<AddDialog> {
  NewTaskDue newTaskDue = NewTaskDue.day;

  @override
  Widget build(BuildContext context) {
    var textController = TextEditingController();
    return new AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: new Column(
        mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: <Widget>[
          Expanded(
            child: new TextField(
              autofocus: true,
              decoration: widget.decoration,
              controller: textController,
            ),
          ),
        ]),
        widget.onAddTask != null ? taskDueList("1 Day", NewTaskDue.day) : new Container(),
        widget.onAddTask != null ? taskDueList("1 Week", NewTaskDue.week) : new Container(),
        widget.onAddTask != null ? taskDueList("1 Month", NewTaskDue.month) : new Container(),
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
              widget.onAdd(textController.text);
            if(widget.onAddTask != null && textController.text.isNotEmpty)
              widget.onAddTask(Task(id: null, title: textController.text, done: false, owner: null, due: DateTime.now().add(newTaskDueToDuration[newTaskDue])));
            Navigator.pop(context);
          },
        )
      ],
    );
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    // TODO: I know you can do better
    return Row(children: [
      Checkbox(value: newTaskDue == thisNewTaskDue, onChanged: (value) { setState(() => newTaskDue = value ? thisNewTaskDue: newTaskDue);}, shape: CircleBorder(),),
      Text(name),
    ]);
    /*Row(children: [
    Checkbox(value: newTaskDue == NewTaskDue.week, onChanged: (value) { setState(() => newTaskDue = value ? NewTaskDue.week: newTaskDue);}, shape: CircleBorder(),),
    Text("1 Week"),
    ]),
    Row(children: [
    Checkbox(value: newTaskDue == NewTaskDue.month, onChanged: (value) { setState(() => newTaskDue = value ? NewTaskDue.month: newTaskDue);}, shape: CircleBorder(),),
    Text("1 Month"),
    ])
    ];

     */
  }
}
