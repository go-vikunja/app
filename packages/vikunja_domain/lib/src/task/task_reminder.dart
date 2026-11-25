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

  /// Ten thousand years either way. A server writes dates up to the year
  /// 9999, and any of them moved by this much is still a date.
  static const maxRelativePeriod = Duration(days: 3652425);

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

/// [seconds] as a relative period, cut to [TaskReminder.maxRelativePeriod]
/// either way.
Duration reminderPeriodOf(int seconds) {
  final max = TaskReminder.maxRelativePeriod.inSeconds;
  return Duration(seconds: seconds.clamp(-max, max));
}

// A DateTime holds 100,000,000 days either side of 1970.
const int _dateTimeLimit = 100000000 * Duration.microsecondsPerDay;

/// [date] plus [period], when a relative reminder fires; null without a
/// date or when no date can hold the sum, which only an impossible date or
/// period from a server reaches.
DateTime? relativeReminderInstant(DateTime? date, Duration period) {
  if (date == null) return null;
  final from = date.microsecondsSinceEpoch;
  final by = period.inMicroseconds;
  // Compared without adding: an uncut period would overflow the sum.
  final fits = by >= 0
      ? from <= _dateTimeLimit - by
      : from >= -_dateTimeLimit - by;
  return fits ? date.add(period) : null;
}
