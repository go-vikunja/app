import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/application/reminder_editing.dart';
import 'package:vikunja_mobile/features/tasks/application/task_providers.dart'
    show taskByIdProvider;
import 'package:vikunja_mobile/features/tasks/presentation/edit/reminders_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/shortcut_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/date_time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/picker_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// The new-task sheet's shortcuts (D75).
const Set<DateShortcut> _dueShortcuts = {
  DateShortcut.today,
  DateShortcut.tomorrow,
  DateShortcut.nextWeek,
};

sealed class _DueChoice {
  const new();
}

final class _DueAt extends _DueChoice {
  const new(this.moment);

  final DateTime moment;
}

final class _PickDue extends _DueChoice {
  const new();
}

final class _ClearDue extends _DueChoice {
  const new();
}

ReminderDates _datesOf(Task task) =>
    (due: task.dueDate, start: task.startDate, end: task.endDate);

/// [moment] without the seconds a due date from the server may have and
/// the shortcuts and the picker never set.
DateTime? _toTheMinute(DateTime? moment) => moment?.subtract(
  Duration(
    seconds: moment.second,
    milliseconds: moment.millisecond,
    microseconds: moment.microsecond,
  ),
);

/// Runs [edit] with a way to read [task]'s row as it is by then: null once
/// it is gone, [task] while it loads. The row stays followed until [edit]
/// is done, also when the screen that opened the picker goes, as the pane
/// does when the window narrows; the choice is still written then.
Future<void> _withLatest(
  BuildContext context,
  Task task,
  Future<void> Function(Task? Function() latest) edit,
) async {
  final row = ProviderScope.containerOf(
    context,
    listen: false,
  ).listen(taskByIdProvider(task.id), (_, _) {});
  try {
    await edit(() {
      final value = row.read();
      return value.hasValue ? value.value : task;
    });
  } finally {
    row.close();
  }
}

/// Sets [task]'s due date from Today, Tomorrow and Next week, each at the
/// time it already has (else the next breakpoint after [now]), from the
/// date picker, or clears it.
Future<void> editDueDate(
  BuildContext context, {
  required TaskRepository repository,
  required Task task,
  required DateTime now,
  required DisplaySettings display,
}) => _withLatest(context, task, (latest) async {
  final l10n = context.l10n;
  final announcer = Announcer.of(context);
  final formatter = MomentFormatter.of(context, display);
  final due = task.dueDate?.toLocal();
  final dueDay = due == null ? null : DateTime(due.year, due.month, due.day);
  final shortcuts = [
    for (final option in buildDateShortcuts(now))
      if (_dueShortcuts.contains(option.shortcut))
        (option, dayWithTime(option.day, current: task.dueDate, now: now)),
  ];
  final picked = await showOptionSheet<_DueChoice>(
    context,
    title: l10n.taskDetailDueDate,
    options: [
      for (final (option, moment) in shortcuts)
        SheetOption(
          value: _DueAt(moment),
          label: shortcutLabel(l10n, option.shortcut),
          subtitle: formatter.absolute(moment),
          subtitleSemanticsLabel: formatter.semanticsLabel(moment),
          selected: option.day == dueDay,
        ),
      SheetOption(value: const _PickDue(), label: l10n.newTaskPickDate),
      if (task.dueDate != null)
        SheetOption(value: const _ClearDue(), label: l10n.taskEditClearDueDate),
    ],
  );
  final DateTime? moment;
  switch (picked) {
    case null:
      return;
    case _DueAt(moment: final at):
      moment = at;
    case _PickDue():
      if (!context.mounted) return;
      final chosen = await pickDateTime(
        context,
        current: task.dueDate,
        now: now,
        display: display,
      );
      if (chosen == null) return;
      moment = chosen;
    case _ClearDue():
      moment = null;
  }
  final row = latest();
  final utc = moment?.toUtc();
  if (row == null || utc == _toTheMinute(row.dueDate)?.toUtc()) return;
  await repository.updateTask(
    row.id,
    TaskChanges(
      dueDate: utc == null ? const DateChange.clear() : DateChange.set(utc),
    ),
  );
  announcer.say(
    moment == null
        ? l10n.taskDetailDueDateRemoved
        : l10n.taskDueSemantics(formatter.spokenAbsolute(moment)),
  );
});

/// Sets [task]'s priority from the six levels, Unset included.
Future<void> editPriority(
  BuildContext context, {
  required TaskRepository repository,
  required Task task,
}) => _withLatest(context, task, (latest) async {
  final l10n = context.l10n;
  final announcer = Announcer.of(context);
  final picked = await showOptionSheet<TaskPriority>(
    context,
    title: l10n.taskDetailPriority,
    options: [
      for (final priority in TaskPriority.values)
        SheetOption(
          value: priority,
          label: priorityLabel(l10n, priority),
          selected: priority == task.priority,
        ),
    ],
  );
  final row = latest();
  if (picked == null || row == null || picked == row.priority) return;
  await repository.updateTask(row.id, TaskChanges(priority: picked.value));
  announcer.say(l10n.prioritySemantics(priorityLabel(l10n, picked)));
});

/// Changes [task]'s labels in the label picker: Done sends the labels
/// added and removed against the ones it opened with.
Future<void> editLabels(
  BuildContext context, {
  required TaskRepository repository,
  required Task task,
}) => _withLatest(context, task, (latest) async {
  final l10n = context.l10n;
  final announcer = Announcer.of(context);
  final before = {for (final label in task.labels) label.id};
  final picked = await pickLabels(context, selected: task.labels);
  final row = latest();
  if (picked == null || row == null) return;
  final after = {for (final label in picked) label.id};
  final change = IdSetChange(
    added: after.difference(before),
    removed: before.difference(after),
  );
  if (change.isEmpty) return;
  await repository.updateTask(row.id, TaskChanges(labels: change));
  announcer.say(l10n.taskDetailLabelsChanged);
});

/// Adds a reminder to [task]'s row as it is once picked; [showMessage] says
/// why one is refused.
Future<void> addReminder(
  BuildContext context, {
  required TaskRepository repository,
  required Task task,
  required DateTime now,
  required ValueChanged<String> showMessage,
}) => _withLatest(context, task, (latest) async {
  final l10n = context.l10n;
  final announcer = Announcer.of(context);
  final picked = await pickReminder(
    context,
    dates: _datesOf(task),
    now: now,
    existing: task.reminders,
  );
  final row = latest();
  if (picked == null || row == null) return;
  final reminders = _remindersWith(
    row.reminders,
    picked,
    dates: _datesOf(row),
    l10n: l10n,
    refuse: (text) {
      if (context.mounted) showMessage(text);
    },
  );
  if (reminders == null) return;
  await repository.updateTask(row.id, TaskChanges(reminders: reminders));
  announcer.say(l10n.taskDetailReminderAdded);
});

/// [reminders] with [picked] added, or in place of the one at [replacing];
/// null after [refuse] said why not: the same reminder twice, or two at
/// one moment with [dates], which the server keeps only one of. Every
/// relative reminder of an unset date falls on the same moment.
List<TaskReminder>? _remindersWith(
  List<TaskReminder> reminders,
  TaskReminder picked, {
  required ReminderDates dates,
  required AppLocalizations l10n,
  required ValueChanged<String> refuse,
  int? replacing,
}) {
  if (replacing == null && reminders.length >= Task.maxReminders) return null;
  final changed = withReminder(reminders, picked, replacing: replacing);
  if (changed == null) {
    refuse(l10n.taskEditReminderDuplicate);
    return null;
  }
  final moment = reminderInstant(picked, dates)?.toUtc();
  for (final (index, other) in reminders.indexed) {
    if (index != replacing &&
        reminderInstant(other, dates)?.toUtc() == moment) {
      refuse(l10n.taskDetailReminderSameMoment);
      return null;
    }
  }
  return changed;
}

/// The reminders of the task [taskId] in a sheet of their own, where each
/// change is saved at once.
Future<void> editReminders(
  BuildContext context, {
  required TaskRepository repository,
  required int taskId,
}) => showPickerSheet<void>(
  context,
  builder: (context, scrollController) => TaskRemindersSheet(
    taskId: taskId,
    repository: repository,
    scrollController: scrollController,
  ),
);

/// The edit page's reminder rows over the task's row: a tap edits one, the
/// cross removes it, and Add reminder adds one. Each change goes out at
/// once, one at a time, from the row as it is by then; a refused one says
/// why under the title. Closes when the row is gone.
class TaskRemindersSheet extends ConsumerStatefulWidget {
  const new({
    required this.taskId,
    required this.repository,
    this.scrollController,
    super.key,
  });

  final int taskId;
  final TaskRepository repository;
  final ScrollController? scrollController;

  @override
  ConsumerState<TaskRemindersSheet> createState() => _TaskRemindersSheetState();
}

class _TaskRemindersSheetState extends ConsumerState<TaskRemindersSheet> {
  String? _refusal;
  bool _busy = false;

  Task? get _latest => ref.read(taskByIdProvider(widget.taskId)).value;

  DateTime get _now => ref.read(clockProvider)();

  Future<void> _oneAtATime(Future<void> Function() change) async {
    if (_busy) return;
    _busy = true;
    try {
      await change();
    } finally {
      _busy = false;
    }
  }

  void _refuse(String text) {
    Announcer.of(context).say(text);
    setState(() => _refusal = text);
  }

  Future<void> _write(
    Task latest,
    List<TaskReminder> reminders, {
    required String said,
  }) async {
    final announcer = Announcer.of(context);
    await widget.repository.updateTask(
      latest.id,
      TaskChanges(reminders: reminders),
    );
    if (!mounted) return;
    setState(() => _refusal = null);
    announcer.say(said);
  }

  Future<void> _edit(TaskReminder tapped) => _oneAtATime(() async {
    final l10n = context.l10n;
    final task = _latest;
    if (task == null) return;
    final picked = await pickReminder(
      context,
      dates: _datesOf(task),
      now: _now,
      editing: tapped,
      existing: task.reminders,
    );
    if (picked == null || !mounted) return;
    final latest = _latest;
    if (latest == null) return;
    final at = latest.reminders.indexWhere(
      (reminder) => sameReminder(reminder, tapped),
    );
    final reminders = _remindersWith(
      latest.reminders,
      picked,
      replacing: at < 0 ? null : at,
      dates: _datesOf(latest),
      l10n: l10n,
      refuse: _refuse,
    );
    if (reminders == null || sameReminders(reminders, latest.reminders)) {
      return;
    }
    await _write(latest, reminders, said: l10n.taskDetailReminderChanged);
  });

  Future<void> _remove(TaskReminder tapped) => _oneAtATime(() async {
    final l10n = context.l10n;
    final latest = _latest;
    if (latest == null) return;
    final at = latest.reminders.indexWhere(
      (reminder) => sameReminder(reminder, tapped),
    );
    if (at < 0) return;
    await _write(latest, [
      for (final (index, reminder) in latest.reminders.indexed)
        if (index != at) reminder,
    ], said: l10n.taskDetailReminderRemoved);
  });

  Future<void> _add() => _oneAtATime(() async {
    final l10n = context.l10n;
    final task = _latest;
    if (task == null) return;
    final picked = await pickReminder(
      context,
      dates: _datesOf(task),
      now: _now,
      existing: task.reminders,
    );
    if (picked == null || !mounted) return;
    final latest = _latest;
    if (latest == null) return;
    final reminders = _remindersWith(
      latest.reminders,
      picked,
      dates: _datesOf(latest),
      l10n: l10n,
      refuse: _refuse,
    );
    if (reminders == null) return;
    await _write(latest, reminders, said: l10n.taskDetailReminderAdded);
  });

  void _closeWhenGone(AsyncValue<Task?>? _, AsyncValue<Task?> next) {
    if (next case AsyncData(value: null)) {
      final route = ModalRoute.of(context);
      if (route == null || !route.isActive) return;
      // A pop would close a picker open over this sheet instead; that one
      // stays until the user closes it, and its choice is dropped.
      if (route.isCurrent) {
        Navigator.of(context).pop();
      } else {
        route.navigator?.removeRoute(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    ref.listen(taskByIdProvider(widget.taskId), _closeWhenGone);
    final task = ref.watch(taskByIdProvider(widget.taskId)).value;
    final refusal = _refusal;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerHeader(
            title: l10n.taskDetailReminders,
            actionLabel: l10n.pickerDone,
            onAction: () => Navigator.of(context).pop(),
          ),
          if (refusal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(refusal, style: TextStyle(color: colors.error)),
            ),
          if (task != null)
            RemindersSection(
              reminders: task.reminders,
              dates: _datesOf(task),
              onEdit: (index) => unawaited(_edit(task.reminders[index])),
              onRemove: (index) => unawaited(_remove(task.reminders[index])),
              onAdd: () => unawaited(_add()),
            ),
        ],
      ),
    );
  }
}

/// The last line of the task sheet's property card: a plus for each
/// property that is not set and may be, which sets it. Wraps when the
/// buttons do not fit on one line; empty without any.
class AddAttributeLine extends StatelessWidget {
  const new({
    this.onDueDate,
    this.onPriority,
    this.onReminder,
    this.onLabel,
    super.key,
  });

  final VoidCallback? onDueDate;
  final VoidCallback? onPriority;
  final VoidCallback? onReminder;
  final VoidCallback? onLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget button(VoidCallback onPressed, String shown, String spoken) =>
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(shown, semanticsLabel: spoken),
        );
    final buttons = [
      if (onDueDate case final onPressed?)
        button(onPressed, l10n.taskDetailDueDate, l10n.taskDetailAddDueDate),
      if (onPriority case final onPressed?)
        button(onPressed, l10n.taskDetailPriority, l10n.taskDetailAddPriority),
      if (onReminder case final onPressed?)
        button(
          onPressed,
          l10n.taskDetailAddLineReminder,
          l10n.taskEditAddReminder,
        ),
      if (onLabel case final onPressed?)
        button(onPressed, l10n.taskDetailAddLineLabel, l10n.taskEditAddLabel),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    // The buttons' own padding lines the first plus up with the card's
    // icons, as Add description does in its card.
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ),
    );
  }
}
