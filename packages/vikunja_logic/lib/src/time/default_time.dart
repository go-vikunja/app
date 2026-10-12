const _breakpointHours = [9, 12, 15, 18, 21];

/// The web's `calculateNearestHours`: the next of 9, 12, 15, 18 and 21, a
/// full hour counting as its own breakpoint; after 21:00 it is 9, on the
/// same day (D38-6).
int nearestBreakpointHour(DateTime now) {
  for (final hour in _breakpointHours) {
    if (now.hour < hour || (now.hour == hour && now.minute == 0)) return hour;
  }
  return _breakpointHours.first;
}

/// The date of [day] at the default time for [now]: the web's
/// `getDateWithTime` without a configured default due time.
DateTime atDefaultTime(DateTime day, {required DateTime now}) =>
    DateTime(day.year, day.month, day.day, nearestBreakpointHour(now));
