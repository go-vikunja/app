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
/// server has not been asked for yet. `done` is not among a new task's
/// fields and is left out; see [changesAfterCreate].
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
);

/// What of [changes] a create cannot carry: an update queued behind it,
/// sent once the server has named the task.
TaskChanges changesAfterCreate(TaskChanges changes) =>
    TaskChanges(done: changes.done);

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
