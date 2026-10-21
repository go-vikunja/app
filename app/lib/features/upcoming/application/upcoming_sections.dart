import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

sealed class UpcomingSection {
  const new(this.tasks);

  final List<Task> tasks;
}

final class OverdueSection extends UpcomingSection {
  const new(super.tasks);
}

/// The tasks due on one local calendar day.
final class DaySection extends UpcomingSection {
  const new(this.day, super.tasks);

  /// Local midnight.
  final DateTime day;
}

final class WithoutDueDateSection extends UpcomingSection {
  const new(super.tasks);
}

/// Upcoming's sections in screen order, empty ones left out: the pinned
/// overdue part, one per day in the device's zone, then the tasks without
/// a due date. Tasks keep the selection's order.
List<UpcomingSection> upcomingSections(UpcomingSelection selection) {
  final days = <DateTime, List<Task>>{};
  for (final task in selection.inRange) {
    final due = task.dueDate!.toLocal();
    (days[DateTime(due.year, due.month, due.day)] ??= []).add(task);
  }
  return [
    if (selection.overdue.isNotEmpty) OverdueSection(selection.overdue),
    for (final MapEntry(key: day, value: tasks) in days.entries)
      DaySection(day, tasks),
    if (selection.withoutDueDate.isNotEmpty)
      WithoutDueDateSection(selection.withoutDueDate),
  ];
}

/// The last day a range covers: its end is exclusive, so a range ending at
/// midnight ends the day before.
DateTime _lastDayOf(DateRange range) {
  final end = range.to.toLocal().subtract(const Duration(microseconds: 1));
  return DateTime(end.year, end.month, end.day);
}

/// The first and last calendar day of [range], for its label.
(DateTime, DateTime) daysOf(DateRange range) {
  final from = range.from.toLocal();
  final last = _lastDayOf(range);
  final first = DateTime(from.year, from.month, from.day);
  return (first, last.isBefore(first) ? first : last);
}

/// The calendar days of [range] for the day strip; null for a range of
/// more than [maxDays] days, whose strip would be too long to find a day
/// in.
List<DateTime>? stripDaysOf(DateRange range, {int maxDays = 31}) {
  final (first, last) = daysOf(range);
  final days = <DateTime>[];
  for (
    var day = first;
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (days.length == maxDays) return null;
    days.add(day);
  }
  return days;
}

/// The selection's dated tasks by the local day they are due, the overdue
/// ones before the rest: what a day in the strip counts and shows once
/// picked.
Map<DateTime, List<Task>> tasksByDay(UpcomingSelection selection) {
  final days = <DateTime, List<Task>>{};
  for (final task in [...selection.overdue, ...selection.inRange]) {
    final due = task.dueDate!.toLocal();
    (days[DateTime(due.year, due.month, due.day)] ??= []).add(task);
  }
  return days;
}
