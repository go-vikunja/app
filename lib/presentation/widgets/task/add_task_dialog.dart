import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class AddTaskDialog extends StatefulWidget {
  final void Function(String title, DateTime? dueDate) onAddTask;
  final String? title;
  final int weekStart;
  const AddTaskDialog({
    super.key,
    required this.onAddTask,
    this.title,
    this.weekStart = 0,
  });

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

/// Maps API weekStart (0=Sun..6=Sat) to a display name
String _dayName(int apiWeekStart) {
  const days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  return days[apiWeekStart.clamp(0, 6)];
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
    final l10n = AppLocalizations.of(context);
    final firstDayName = _dayName(widget.weekStart);

    // Compute the "end of week" day for weekend visibility check
    // API: 0=Sun, end of week = Fri(5)+Sat(6) relative to start
    // Dart weekday: Mon=1..Sun=7
    int firstDayDart = widget.weekStart == 0 ? 7 : widget.weekStart;
    int lastDay = (firstDayDart + 5) % 7;
    if (lastDay == 0) lastDay = 7;

    return AlertDialog(
      scrollable: true,
      contentPadding: const EdgeInsets.all(16.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            keyboardType: TextInputType.multiline,
            maxLines: null,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.newTaskName,
              hintText: l10n.newTaskExample,
            ),
            controller: textController,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(l10n.dueDate),
          ),
          Wrap(
            spacing: 8,
            children: [
              taskDueList(l10n.dueOptionNone, NewTaskDue.none),
              if (dateTime.hour < 21)
                taskDueList(l10n.dueOptionToday, NewTaskDue.today),
              taskDueList(l10n.dueOptionTomorrow, NewTaskDue.tomorrow),
              // Dynamic label: "Next Sunday" / "Next Monday" etc
              taskDueList('Next $firstDayName', NewTaskDue.nextMonday),
              if (dateTime.weekday != lastDay || dateTime.hour < 21)
                taskDueList(l10n.dueOptionThisWeekend, NewTaskDue.weekend),
              taskDueList(
                l10n.dueOptionLaterThisWeek,
                NewTaskDue.laterThisWeek,
              ),
              taskDueList(l10n.dueInOneWeek, NewTaskDue.nextWeek),
              taskDueList(l10n.dueOptionCustom, NewTaskDue.custom),
            ],
          ),
          if (newTaskDue == NewTaskDue.custom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: VikunjaDateTimeField(
                label: l10n.enterExactTime,
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
                      dueDate!.formatShort(),
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
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(l10n.add),
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
            dueDate = newTaskDue.calculateDate(
              DateTime.now(),
              weekStart: widget.weekStart,
            );
          }
        });
      },
    );
  }
}
