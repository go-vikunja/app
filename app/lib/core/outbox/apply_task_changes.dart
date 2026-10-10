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
);

Value<DateTime?> _date(DateChange? change) => switch (change) {
  null => const Value.absent(),
  SetDate(:final value) => Value(value.toUtc()),
  ClearDate() => const Value(null),
};
