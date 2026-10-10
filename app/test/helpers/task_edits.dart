import 'package:vikunja_domain/vikunja_domain.dart';

const _unset = Object();

/// [task] with the given fields replaced; a nullable field passed as null
/// is cleared, one left out stays. Dates are stored in UTC, like the rows.
Task copyTask(
  Task task, {
  String? title,
  String? description,
  bool? done,
  Object? doneAt = _unset,
  Object? dueDate = _unset,
  Object? startDate = _unset,
  Object? endDate = _unset,
  TaskPriority? priority,
  double? percentDone,
  String? hexColor,
  bool? isFavorite,
  Object? updated = _unset,
  List<Label>? labels,
  List<User>? assignees,
  List<TaskReminder>? reminders,
}) => task.copyWith(
  title: title,
  description: description,
  done: done,
  doneAt: _date(doneAt, task.doneAt),
  dueDate: _date(dueDate, task.dueDate),
  startDate: _date(startDate, task.startDate),
  endDate: _date(endDate, task.endDate),
  priority: priority,
  percentDone: percentDone,
  hexColor: hexColor,
  isFavorite: isFavorite,
  labels: labels,
  assignees: assignees,
  reminders: reminders,
  updated: _date(updated, task.updated),
);

/// [changes] applied as the server stores them.
Task applyChangesToTask(
  Task task,
  TaskChanges changes, {
  required DateTime now,
}) => copyTask(
  task,
  title: changes.title,
  description: changes.description,
  done: changes.done,
  doneAt: switch (changes.done) {
    null => _unset,
    true => task.doneAt ?? now,
    false => null,
  },
  dueDate: _changed(changes.dueDate),
  startDate: _changed(changes.startDate),
  endDate: _changed(changes.endDate),
  priority: switch (changes.priority) {
    final value? => TaskPriority.fromValue(value),
    null => null,
  },
  percentDone: changes.percentDone,
  hexColor: changes.hexColor,
  isFavorite: changes.isFavorite,
  updated: now,
);

/// What the server does to a repeating task marked done: open again with
/// the dates moved on, `done_at` set to now.
Task reopenRepeating(Task task, {required DateTime now}) {
  DateTime? shifted(DateTime? date) {
    if (date == null) return null;
    return switch (task.repeatMode) {
      RepeatMode.afterAmount => date.add(task.repeatAfter),
      RepeatMode.monthly => DateTime.utc(
        date.year,
        date.month + 1,
        date.day,
        date.hour,
        date.minute,
        date.second,
      ),
      RepeatMode.fromCurrentDate => now.add(task.repeatAfter),
    };
  }

  return copyTask(
    task,
    done: false,
    doneAt: now,
    dueDate: shifted(task.dueDate),
    startDate: shifted(task.startDate),
    endDate: shifted(task.endDate),
    updated: now,
  );
}

DateTime? _date(Object? value, DateTime? current) => switch (value) {
  _unset => current,
  final DateTime date => date.toUtc(),
  _ => null,
};

Object? _changed(DateChange? change) => switch (change) {
  null => _unset,
  SetDate(:final value) => value,
  ClearDate() => null,
};
