import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum DueGroup { overdue, today, nextSevenDays, later, noDueDate }

@immutable
final class DueSection {
  const new(this.group, this.tasks);

  final DueGroup group;
  final List<Task> tasks;
}

/// Splits the open tasks into the overview's sections by the device's local
/// calendar at [now]. Only sections with tasks are returned, in [DueGroup]
/// order; tasks keep their order within a section.
List<DueSection> groupTasksByDueDate(List<Task> tasks, DateTime now) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final tomorrow = DateTime(local.year, local.month, local.day + 1);
  final afterSevenDays = DateTime(local.year, local.month, local.day + 8);
  final groups = {for (final group in DueGroup.values) group: <Task>[]};
  for (final task in tasks) {
    groups[_groupOf(task, local, today, tomorrow, afterSevenDays)]!.add(task);
  }
  return [
    for (final group in DueGroup.values)
      if (groups[group]!.isNotEmpty) DueSection(group, groups[group]!),
  ];
}

DueGroup _groupOf(
  Task task,
  DateTime now,
  DateTime today,
  DateTime tomorrow,
  DateTime afterSevenDays,
) {
  final due = task.dueDate?.toLocal();
  if (due == null) return DueGroup.noDueDate;
  if (!task.done && !due.isAfter(now)) return DueGroup.overdue;
  if (due.isBefore(today)) return DueGroup.overdue;
  if (due.isBefore(tomorrow)) return DueGroup.today;
  if (due.isBefore(afterSevenDays)) return DueGroup.nextSevenDays;
  return DueGroup.later;
}
