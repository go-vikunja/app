/// The relative days of the web's `calculateDayInterval`, plus
/// [nextWeekend] of its date shortcuts.
enum DayInterval {
  today,
  tomorrow,
  nextMonday,
  thisWeekend,
  laterThisWeek,
  laterNextWeek,
  nextWeek,
  nextWeekend,
}

/// Days from the date of [now] to the day [interval] stands for; 0 is
/// today. `nextMonday` is today on a Monday, as on the web (D38-6).
int calculateDayInterval(DayInterval interval, DateTime now) {
  // The web counts with JS `getDay()`: 0 is Sunday.
  final weekday = now.weekday % DateTime.daysPerWeek;
  final laterThisWeek = weekday >= DateTime.friday || weekday == 0 ? 0 : 2;
  return switch (interval) {
    DayInterval.today => 0,
    DayInterval.tomorrow => 1,
    DayInterval.nextMonday => (8 - weekday) % 7,
    DayInterval.thisWeekend => (6 - weekday) % 6,
    DayInterval.laterThisWeek => laterThisWeek,
    DayInterval.laterNextWeek => laterThisWeek + 7,
    DayInterval.nextWeek => 7,
    // The Saturday after this week's; on Sunday the very next one.
    DayInterval.nextWeekend => weekday == 0 ? 6 : (6 - weekday) % 6 + 7,
  };
}
