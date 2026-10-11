import 'package:drift/drift.dart' show Value;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';

/// [row] with [changes] applied, as the server would store them: marking
/// done sets `done_at` to [now] unless the row already has one, undoing
/// clears it.
TaskRow applyTaskChanges(
  TaskRow row,
  TaskChanges changes, {
  required DateTime now,
}) => row.copyWith(
  title: changes.title,
  description: changes.description,
  done: changes.done,
  doneAt: switch (changes.done) {
    null => const Value.absent(),
    true => Value(row.doneAt ?? now.toUtc()),
    false => const Value(null),
  },
  isFavorite: changes.isFavorite,
  priority: changes.priority,
  percentDone: changes.percentDone,
  hexColor: changes.hexColor,
  dueDate: _date(changes.dueDate),
  startDate: _date(changes.startDate),
  endDate: _date(changes.endDate),
  repeatAfter: changes.repeatAfter?.inSeconds,
  repeatMode: changes.repeatMode?.value,
  projectId: changes.projectId,
);

/// [task] with [changes] folded into the create, for an edit of a task the
/// server has not been asked for yet. `done`, labels and assignees are not
/// among a new task's fields and are left out; see [changesAfterCreate].
NewTask applyChangesToNewTask(NewTask task, TaskChanges changes) => NewTask(
  projectId: changes.projectId ?? task.projectId,
  title: changes.title ?? task.title,
  description: changes.description ?? task.description,
  dueDate: _newDate(changes.dueDate, task.dueDate),
  startDate: _newDate(changes.startDate, task.startDate),
  endDate: _newDate(changes.endDate, task.endDate),
  priority: switch (changes.priority) {
    final value? => TaskPriority.fromValue(value),
    null => task.priority,
  },
  percentDone: changes.percentDone ?? task.percentDone,
  hexColor: changes.hexColor ?? task.hexColor,
  repeatAfter: changes.repeatAfter ?? task.repeatAfter,
  repeatMode: changes.repeatMode ?? task.repeatMode,
  isFavorite: changes.isFavorite ?? task.isFavorite,
  reminders: changes.reminders ?? task.reminders,
);

/// What of [changes] a create cannot carry: an update queued behind it,
/// sent once the server has named the task. The server ignores labels in
/// a create body, and labels and assignees go through their own endpoints,
/// which need the task's id.
TaskChanges changesAfterCreate(TaskChanges changes) => TaskChanges(
  done: changes.done,
  labels: changes.labels,
  assignees: changes.assignees,
);

/// [changes] without any change to the labels in [labelIds].
TaskChanges withoutLabels(TaskChanges changes, Set<int> labelIds) {
  final labels = switch (changes.labels) {
    IdSetChange(:final added, :final removed) => IdSetChange(
      added: added.difference(labelIds),
      removed: removed.difference(labelIds),
    ),
    null => null,
  };
  return TaskChanges(
    title: changes.title,
    description: changes.description,
    done: changes.done,
    isFavorite: changes.isFavorite,
    priority: changes.priority,
    percentDone: changes.percentDone,
    hexColor: changes.hexColor,
    dueDate: changes.dueDate,
    startDate: changes.startDate,
    endDate: changes.endDate,
    repeatAfter: changes.repeatAfter,
    repeatMode: changes.repeatMode,
    projectId: changes.projectId,
    labels: (labels?.isEmpty ?? true) ? null : labels,
    assignees: changes.assignees,
    reminders: changes.reminders,
  );
}

bool changesDates(TaskChanges changes) =>
    changes.dueDate != null ||
    changes.startDate != null ||
    changes.endDate != null;

/// [reminders] with the instant of every relative one computed from the
/// task's dates as the server computes it: the referenced date plus the
/// period, null while that date is unset. Absolute ones are kept.
List<TaskReminder> withLocalInstants(
  List<TaskReminder> reminders, {
  required DateTime? dueDate,
  required DateTime? startDate,
  required DateTime? endDate,
}) => [
  for (final reminder in reminders)
    switch (reminder.relativeTo) {
      null => reminder,
      final relativeTo => TaskReminder(
        reminder: switch (relativeTo) {
          ReminderRelativeTo.dueDate => dueDate,
          ReminderRelativeTo.startDate => startDate,
          ReminderRelativeTo.endDate => endDate,
        }?.toUtc().add(reminder.relativePeriod),
        relativePeriod: reminder.relativePeriod,
        relativeTo: relativeTo,
      ),
    },
];

DateTime? _newDate(DateChange? change, DateTime? current) => switch (change) {
  null => current,
  SetDate(:final value) => value.toUtc(),
  ClearDate() => null,
};

Value<DateTime?> _date(DateChange? change) => switch (change) {
  null => const Value.absent(),
  SetDate(:final value) => Value(value.toUtc()),
  ClearDate() => const Value(null),
};
