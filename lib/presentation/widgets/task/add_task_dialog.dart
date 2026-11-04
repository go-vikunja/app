import 'package:flutter/material.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';

class AddTaskDialog extends StatefulWidget {
  final void Function(
    String title,
    DateTime? dueDate,
    int? projectId,
    int priority,
  )
  onAddTask;
  final String? title;
  final List<Project> projects;
  final int? initialProjectId;

  const AddTaskDialog({
    super.key,
    required this.onAddTask,
    this.title,
    this.projects = const [],
    this.initialProjectId,
  });

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends State<AddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.none;
  DateTime? dueDate;
  var textController = TextEditingController();
  int? selectedProjectId;
  int priority = 0;

  @override
  void initState() {
    super.initState();

    var title = widget.title;
    if (title != null) {
      textController.text = _capitalizeFirst(title);
    }
    textController.addListener(_onTitleChanged);
    selectedProjectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    textController.removeListener(_onTitleChanged);
    textController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var dateTime = DateTime.now();
    final l10n = AppLocalizations.of(context);

    final remainingHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        MediaQuery.paddingOf(context).vertical;
    final maxContentHeight = (remainingHeight - 96).clamp(
      120.0,
      remainingHeight * 0.75,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLines: 1,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.newTaskName,
                  hintText: l10n.newTaskExample,
                ),
                controller: textController,
              ),
              if (widget.projects.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: DropdownButtonFormField<int>(
                    value: selectedProjectId,
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      icon: const Icon(Icons.inbox_outlined),
                      labelText: l10n.project,
                      border: InputBorder.none,
                    ),
                    items: widget.projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text(
                              project.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProjectId = value;
                      });
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
                child: Text(l10n.dueDate),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  taskDueList(l10n.dueOptionNone, NewTaskDue.none),
                  if (dateTime.hour < 21)
                    taskDueList(l10n.dueOptionToday, NewTaskDue.today),
                  taskDueList(l10n.dueOptionTomorrow, NewTaskDue.tomorrow),
                  taskDueList(l10n.dueOptionNextMonday, NewTaskDue.nextMonday),
                  if (dateTime.weekday != DateTime.sunday || dateTime.hour < 21)
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
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          dueDate!.formatShort(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: DropdownButtonFormField<int>(
                  value: priority,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    isDense: true,
                    icon: Icon(
                      key: ValueKey('priority-icon-$priority'),
                      priority == 0 ? Icons.flag_outlined : Icons.flag,
                      color: _priorityColor(context, priority),
                    ),
                    labelText: l10n.priority,
                    border: InputBorder.none,
                  ),
                  selectedItemBuilder: (context) => List.generate(
                    6,
                    (value) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        priorityToString(l10n, value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  items: List.generate(
                    6,
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Row(
                        children: [
                          Icon(
                            value == 0 ? Icons.flag_outlined : Icons.flag,
                            size: 20,
                            color: _priorityColor(context, value),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(priorityToString(l10n, value))),
                        ],
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      priority = value ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          onPressed: _normalizedTitle.isEmpty
              ? null
              : () {
                  widget.onAddTask(
                    _normalizedTitle,
                    dueDate,
                    selectedProjectId,
                    priority,
                  );
                  Navigator.pop(context);
                },
          child: Text(l10n.add),
        ),
      ],
    );
  }

  String get _normalizedTitle {
    return _capitalizeFirst(textController.text.trim());
  }

  String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.zero,
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

  Color _priorityColor(BuildContext context, int value) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>();
    final warning = appColors?.warning ?? Colors.orange;
    final danger = appColors?.danger ?? Colors.red;

    return switch (value) {
      1 => appColors?.success ?? Colors.green,
      2 => warning,
      3 => danger,
      4 => danger,
      5 => danger,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }
}
