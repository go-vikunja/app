import 'package:flutter/foundation.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

export 'package:vikunja_logic/vikunja_logic.dart' show nearestBreakpointHour;

/// The web's `buildDateShortcuts` keys, in its order.
enum DateShortcut {
  today,
  tomorrow,
  nextMonday,
  thisWeekend,
  laterThisWeek,
  nextWeek,
  nextWeekend,
  endOfMonth,
  inAMonth,
}

/// A shortcut and the start of the day it stands for, in local time.
@immutable
final class DateShortcutOption {
  const new(this.shortcut, this.day);

  final DateShortcut shortcut;
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      other is DateShortcutOption &&
      other.shortcut == shortcut &&
      other.day == day;

  @override
  int get hashCode => Object.hash(shortcut, day);

  @override
  String toString() => 'DateShortcutOption(${shortcut.name}, $day)';
}

DateTime _startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// The web's rules: from 21:00 `today` is hidden (another shortcut landing
/// on today still shows, as on the web); `thisWeekend` is hidden on
/// Sunday; `inAMonth` is clamped to the month's last day; of two shortcuts
/// on the same day the later one is dropped.
List<DateShortcutOption> buildDateShortcuts(DateTime now) {
  final today = _startOfDay(now);
  final weekday = now.weekday % 7;
  final lateInTheDay = now.hour >= 21;
  final seen = <DateTime>{};
  final options = <DateShortcutOption>[];
  DateTime after(DayInterval interval) =>
      _addDays(today, calculateDayInterval(interval, now));
  for (final shortcut in DateShortcut.values) {
    if (shortcut == DateShortcut.today && lateInTheDay) continue;
    if (shortcut == DateShortcut.thisWeekend && weekday == 0) continue;
    final day = switch (shortcut) {
      DateShortcut.endOfMonth => DateTime(
        today.year,
        today.month,
        _lastDayOfMonth(today.year, today.month),
      ),
      DateShortcut.inAMonth => DateTime(
        today.year,
        today.month + 1,
        today.day.clamp(1, _lastDayOfMonth(today.year, today.month + 1)),
      ),
      DateShortcut.today => after(DayInterval.today),
      DateShortcut.tomorrow => after(DayInterval.tomorrow),
      DateShortcut.nextMonday => after(DayInterval.nextMonday),
      DateShortcut.thisWeekend => after(DayInterval.thisWeekend),
      DateShortcut.laterThisWeek => after(DayInterval.laterThisWeek),
      DateShortcut.nextWeek => after(DayInterval.nextWeek),
      DateShortcut.nextWeekend => after(DayInterval.nextWeekend),
    };
    if (seen.add(day)) options.add(DateShortcutOption(shortcut, day));
  }
  return options;
}

/// [day] at a time of day: the one [current] already has, else the
/// breakpoint for [now] (local time, seconds dropped).
DateTime dayWithTime(
  DateTime day, {
  required DateTime? current,
  required DateTime now,
}) {
  final local = current?.toLocal();
  return DateTime(
    day.year,
    day.month,
    day.day,
    local?.hour ?? nearestBreakpointHour(now),
    local?.minute ?? 0,
  );
}
