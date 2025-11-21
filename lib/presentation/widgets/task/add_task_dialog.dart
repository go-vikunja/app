import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/constants.dart';
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
  NewTaskDue newTaskDue = NewTaskDue.none;
  DateTime? dueDate;
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
    var dateTime = DateTime.now();

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
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(AppLocalizations.of(context).dueDate),
          ),
          Wrap(
            spacing: 8,
            children: [
              taskDueList("None", NewTaskDue.none),
              if (dateTime.hour < 21) taskDueList("Today", NewTaskDue.today),
              taskDueList("Tomorrow", NewTaskDue.tomorrow),
              taskDueList("Next Monday", NewTaskDue.next_monday),
              if (dateTime.weekday != DateTime.sunday || dateTime.hour < 21)
                taskDueList("This Weekend", NewTaskDue.weekend),
              taskDueList("Later this week", NewTaskDue.later_this_week),
              taskDueList(AppLocalizations.of(context).dueInOneWeek, NewTaskDue.next_week),
              taskDueList("Custom", NewTaskDue.custom),
            ],
          ),
          if (newTaskDue == NewTaskDue.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: VikunjaDateTimeField(
                label: AppLocalizations.of(context).enterExactTime,
                onChanged: (value) {
                  setState(() => newTaskDue = NewTaskDue.custom);
                  dueDate = value;
                },
              ),
            ),
          if (newTaskDue != NewTaskDue.custom && dueDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      vDateFormatShort.format(dueDate!),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
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
          if (newTaskDue == NewTaskDue.custom ||
              newTaskDue == NewTaskDue.none) {
            dueDate = null;
          } else {
            dueDate = newTaskDue.calculateDate(DateTime.now());
          }
        });
      },
    );
  }
}
