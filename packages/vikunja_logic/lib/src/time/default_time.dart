import 'package:vikunja_domain/vikunja_domain.dart';

const _breakpointHours = [9, 12, 15, 18, 21];

/// The web's `calculateNearestHours`: the next of 9, 12, 15, 18 and 21, a
/// full hour counting as its own breakpoint; after 21:00 it is 9, which
/// [atDefaultTime] moves to 23:59 on today (D102-9).
int nearestBreakpointHour(DateTime now) {
  for (final hour in _breakpointHours) {
    if (now.hour < hour || (now.hour == hour && now.minute == 0)) return hour;
  }
  return _breakpointHours.first;
}

/// The date of [day] at the web's `getDateWithTime`: the user's
/// `default_due_time` ([defaultTime]), else the breakpoint for [now]; on
/// today never a time that has passed ([notPassedToday]).
DateTime atDefaultTime(
  DateTime day, {
  required DateTime now,
  ClockTime? defaultTime,
}) => notPassedToday(
  withDefaultTime(day, now: now, defaultTime: defaultTime),
  now: now,
);

/// [day] at the user's `default_due_time` ([defaultTime]), else at the
/// breakpoint for [now], as the web's `getDateWithTime`, also when that
/// has passed: where the user picks the time next, as in the time picker.
DateTime withDefaultTime(
  DateTime day, {
  required DateTime now,
  ClockTime? defaultTime,
}) => switch (defaultTime) {
  ClockTime(:final hour, :final minute) => DateTime(
    day.year,
    day.month,
    day.day,
    hour,
    minute,
  ),
  null => DateTime(day.year, day.month, day.day, nearestBreakpointHour(now)),
};

/// [date], or 23:59 of today when [date] is a minute of today that has
/// passed: a date the user gave without a time is never overdue the
/// moment it is set (D102-9; the web keeps the passed time). The minute of
/// [now] itself has not passed, so 12:00 at 12:00:30 stays, as the
/// breakpoints count a full hour as their own.
DateTime notPassedToday(DateTime date, {required DateTime now}) =>
    date.isBefore(
          DateTime(now.year, now.month, now.day, now.hour, now.minute),
        ) &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day
    ? DateTime(now.year, now.month, now.day, 23, 59)
    : date;
