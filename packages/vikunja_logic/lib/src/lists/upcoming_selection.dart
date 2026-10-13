import 'package:meta/meta.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/src/lists/task_order.dart';
import 'package:vikunja_logic/src/time/date_range_preset.dart';

/// What Upcoming shows, each part ordered like the web's request (due date
/// ascending, then newest first, a temporary id before every server id).
@immutable
final class UpcomingSelection {
  const new({
    this.overdue = const [],
    this.inRange = const [],
    this.withoutDueDate = const [],
  });

  /// Open tasks due at or before now; empty unless asked for. A task here
  /// is never repeated in [inRange].
  final List<Task> overdue;

  /// Open tasks due strictly inside the range.
  final List<Task> inRange;

  /// Open tasks without a due date; empty unless asked for.
  final List<Task> withoutDueDate;
}

/// The web's Upcoming filter (`done = false && due_date < to && due_date >
/// from`, include-nulls for tasks without a date) evaluated on [tasks],
/// with one difference: with [showOverdue] every overdue open task goes to
/// the pinned overdue part instead of the web's dropped lower bound. Done
/// tasks are ignored; [tasks] may hold them.
UpcomingSelection selectUpcoming(
  Iterable<Task> tasks, {
  required DateRange range,
  required DateTime now,
  required bool showOverdue,
  required bool showWithoutDueDate,
}) {
  final overdue = <Task>[];
  final inRange = <Task>[];
  final withoutDueDate = <Task>[];
  for (final task in tasks) {
    if (task.done) continue;
    switch (task.dueDate) {
      case null:
        if (showWithoutDueDate) withoutDueDate.add(task);
      case _ when showOverdue && task.isOverdue(now):
        overdue.add(task);
      case final DateTime due
          when due.isAfter(range.from) && due.isBefore(range.to):
        inRange.add(task);
    }
  }
  List<Task> sorted(List<Task> part) =>
      List.unmodifiable(part..sort(compareByDueDate));
  return UpcomingSelection(
    overdue: sorted(overdue),
    inRange: sorted(inRange),
    withoutDueDate: sorted(withoutDueDate),
  );
}
