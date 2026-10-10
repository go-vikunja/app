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
