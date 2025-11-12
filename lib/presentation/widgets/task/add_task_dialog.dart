import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class AddTaskDialog extends StatefulWidget {
  final void Function(String title, DateTime? dueDate) onAddTask;
  final String? title;

  const AddTaskDialog({super.key, required this.onAddTask, this.title = null});

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends State<AddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.day;
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
    if (newTaskDue != NewTaskDue.custom) {
      customDueDate = DateTime.now().add(newTaskDue.newTaskDueToDuration());
    }

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
                    labelText: AppLocalizations.of(context).newTaskName,
                    hintText: AppLocalizations.of(context).newTaskExample,
                  ),
                  controller: textController,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8),
            child: Text(AppLocalizations.of(context).dueDate),
          ),
          taskDueList(AppLocalizations.of(context).dueInOneDay, NewTaskDue.day),
          taskDueList(
            AppLocalizations.of(context).dueInOneWeek,
            NewTaskDue.week,
          ),
          taskDueList(
            AppLocalizations.of(context).dueInOneMonth,
            NewTaskDue.month,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: VikunjaDateTimeField(
              label: AppLocalizations.of(context).enterExactTime,
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
          child: Text(AppLocalizations.of(context).cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(AppLocalizations.of(context).add),
          onPressed: () {
            if (textController.text.isNotEmpty) {
              widget.onAddTask(textController.text, customDueDate);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    return Row(
      children: [
        Checkbox(
          value: newTaskDue == thisNewTaskDue,
          onChanged: (value) {
            newTaskDue = thisNewTaskDue;
            setState(
              () => customDueDate = DateTime.now().add(
                thisNewTaskDue.newTaskDueToDuration(),
              ),
            );
          },
          shape: CircleBorder(),
        ),
        Text(name),
      ],
    );
  }
}
