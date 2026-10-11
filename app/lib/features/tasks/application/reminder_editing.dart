import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The dates a relative reminder can refer to, as the draft has them.
typedef ReminderDates = ({DateTime? due, DateTime? start, DateTime? end});

/// The units of the web's relative reminder form.
enum ReminderUnit {
  minutes(Duration(minutes: 1)),
  hours(Duration(hours: 1)),
  days(Duration(days: 1)),
  weeks(Duration(days: 7));

  new(this.length);

  final Duration length;
}

enum ReminderDirection { before, after }

/// A relative period as the custom form shows it: a whole amount of one
/// unit, before or after the date.
@immutable
final class ReminderPeriodParts {
  const new({
    required this.amount,
    required this.unit,
    required this.direction,
  });

  /// The largest unit that divides [period] evenly and the period's own
  /// sign; the web always shows "before" here (quirk 9). A period that is
  /// no whole minute, which only another client can store, is rounded to
  /// the nearest minute.
  factory fromPeriod(Duration period) {
    final direction = period > Duration.zero
        ? ReminderDirection.after
        : ReminderDirection.before;
    final seconds = period.abs().inSeconds;
    if (seconds == 0) {
      return ReminderPeriodParts(
        amount: 0,
        unit: ReminderUnit.days,
        direction: direction,
      );
    }
    for (final unit in ReminderUnit.values.reversed) {
      final length = unit.length.inSeconds;
      if (seconds % length == 0) {
        return ReminderPeriodParts(
          amount: seconds ~/ length,
          unit: unit,
          direction: direction,
        );
      }
    }
    return ReminderPeriodParts(
      amount: (seconds / Duration.secondsPerMinute).round(),
      unit: ReminderUnit.minutes,
      direction: direction,
    );
  }

  final int amount;
  final ReminderUnit unit;
  final ReminderDirection direction;

  Duration get period =>
      unit.length * amount * (direction == ReminderDirection.before ? -1 : 1);

  ReminderPeriodParts copyWith({
    int? amount,
    ReminderUnit? unit,
    ReminderDirection? direction,
  }) => ReminderPeriodParts(
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    direction: direction ?? this.direction,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderPeriodParts &&
      other.amount == amount &&
      other.unit == unit &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(amount, unit, direction);

  @override
  String toString() =>
      'ReminderPeriodParts($amount ${unit.name} ${direction.name})';
}

/// The web's presets: on the date, 2 hours, 1, 3, 7 and 30 days before.
const List<Duration> reminderPresetPeriods = [
  Duration.zero,
  Duration(hours: -2),
  Duration(days: -1),
  Duration(days: -3),
  Duration(days: -7),
  Duration(days: -30),
];

List<TaskReminder> reminderPresets(ReminderRelativeTo relativeTo) => [
  for (final period in reminderPresetPeriods)
    TaskReminder(relativePeriod: period, relativeTo: relativeTo),
];

DateTime? referenceDate(ReminderRelativeTo relativeTo, ReminderDates dates) =>
    switch (relativeTo) {
      ReminderRelativeTo.dueDate => dates.due,
      ReminderRelativeTo.startDate => dates.start,
      ReminderRelativeTo.endDate => dates.end,
    };

/// The web's `defaultRelativeTo`: the due date, else the start date, else
/// the end date; null when none is set.
ReminderRelativeTo? defaultReminderReference(ReminderDates dates) {
  if (dates.due != null) return ReminderRelativeTo.dueDate;
  if (dates.start != null) return ReminderRelativeTo.startDate;
  if (dates.end != null) return ReminderRelativeTo.endDate;
  return null;
}

/// When [reminder] fires with [dates]; null for a relative reminder whose
/// date is unset. Recomputed from the draft, because the stored instant of
/// a relative reminder is the server's answer to the dates it had.
DateTime? reminderInstant(TaskReminder reminder, ReminderDates dates) {
  final relativeTo = reminder.relativeTo;
  if (relativeTo == null) return reminder.reminder;
  return referenceDate(relativeTo, dates)?.add(reminder.relativePeriod);
}

/// Whether two of [reminders] fire at the same moment with [dates]. The
/// server keeps only one reminder per instant, and every relative reminder
/// whose date is unset shares the zero instant.
bool remindersCoincide(List<TaskReminder> reminders, ReminderDates dates) {
  final instants = <int?>{};
  for (final reminder in reminders) {
    final instant = reminderInstant(reminder, dates);
    if (!instants.add(instant?.microsecondsSinceEpoch)) return true;
  }
  return false;
}

/// [reminders] with [reminder] added, or with it in place of the one at
/// [replacing]; null when another entry already is the same reminder.
List<TaskReminder>? withReminder(
  List<TaskReminder> reminders,
  TaskReminder reminder, {
  int? replacing,
}) {
  for (var i = 0; i < reminders.length; i++) {
    if (i != replacing && sameReminder(reminders[i], reminder)) return null;
  }
  return [
    for (var i = 0; i < reminders.length; i++)
      if (i == replacing) reminder else reminders[i],
    if (replacing == null) reminder,
  ];
}
