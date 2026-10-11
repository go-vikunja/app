import 'package:meta/meta.dart';

enum ReminderRelativeTo {
  dueDate('due_date'),
  startDate('start_date'),
  endDate('end_date');

  new(this.wireName);

  final String wireName;

  static ReminderRelativeTo? fromWire(String? name) =>
      values.where((r) => r.wireName == name).firstOrNull;
}

@immutable
final class TaskReminder {
  const new({
    this.reminder,
    this.relativePeriod = Duration.zero,
    this.relativeTo,
  });

  /// The absolute instant; for relative reminders the server computes it
  /// from the referenced date, null when that date is unset.
  final DateTime? reminder;

  /// Negative means before the referenced date.
  final Duration relativePeriod;
  final ReminderRelativeTo? relativeTo;

  bool get isRelative => relativeTo != null;

  @override
  bool operator ==(Object other) =>
      other is TaskReminder &&
      other.reminder == reminder &&
      other.relativePeriod == relativePeriod &&
      other.relativeTo == relativeTo;

  @override
  int get hashCode => Object.hash(reminder, relativePeriod, relativeTo);
}

/// The same reminder for the user: a relative one by its date and period
/// (the stored instant is derived), an absolute one by its instant.
bool sameReminder(TaskReminder a, TaskReminder b) {
  if (a.relativeTo != b.relativeTo) return false;
  if (a.isRelative) return a.relativePeriod == b.relativePeriod;
  return a.reminder?.toUtc() == b.reminder?.toUtc();
}

/// Equal as multisets under [sameReminder]; order does not matter.
bool sameReminders(List<TaskReminder> a, List<TaskReminder> b) {
  if (a.length != b.length) return false;
  final unmatched = [...b];
  for (final reminder in a) {
    final index = unmatched.indexWhere(
      (other) => sameReminder(reminder, other),
    );
    if (index < 0) return false;
    unmatched.removeAt(index);
  }
  return true;
}
