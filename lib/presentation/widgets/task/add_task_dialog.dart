import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';

class AddTaskDialog extends StatefulWidget {
  final void Function(String title, DateTime? dueDate) onAddTask;
  final String? title;

  const AddTaskDialog({super.key, required this.onAddTask, this.title = null});

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends State<AddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.none;
  DateTime? customDueDate;
  var textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    var title = widget.title;
    if (title != null) {
      textController.text = title;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(16.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'New Task Name',
                    hintText: 'eg. Milk',
                  ),
                  controller: textController,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8),
            child: Text("Due Date:"),
          ),
          Wrap(
            spacing: 8,
            children: [
              taskDueList("None", NewTaskDue.none),
              taskDueList("1 Day", NewTaskDue.day),
              taskDueList("1 Week", NewTaskDue.week),
              taskDueList("1 Month", NewTaskDue.month),
              taskDueList("Custom", NewTaskDue.custom),
            ],
          ),
          if (newTaskDue == NewTaskDue.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: VikunjaDateTimeField(
                label: "Enter exact time",
                onChanged: (value) {
                  setState(() => newTaskDue = NewTaskDue.custom);
                  customDueDate = value;
                },
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () {
            var dueDate;
            if (newTaskDue == NewTaskDue.custom) {
              dueDate = customDueDate;
            } else if (newTaskDue == NewTaskDue.none) {
              dueDate = null;
            } else {
              dueDate = DateTime.now().add(newTaskDue.newTaskDueToDuration());
            }

            if (textController.text.isNotEmpty) {
              widget.onAddTask(textController.text, dueDate);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    return ChoiceChip(
      label: Text(name),
      selected: newTaskDue == thisNewTaskDue,
      onSelected: (value) {
        newTaskDue = thisNewTaskDue;
        setState(() {
          customDueDate = null;
        });
      },
    );
  }
}
