enum NewTaskDue {
  none,
  today,
  tomorrow,
  nextMonday,
  weekend,
  laterThisWeek,
  nextWeek,
  custom;

  /// Calculates the due date.
  /// [weekStart] uses API convention: 0=Sunday, 1=Monday, ... 6=Saturday
  DateTime? calculateDate(DateTime currentDateTime, {int weekStart = 0}) {
    int hour = calculateNearestHours(currentDateTime);

    var newDateTime = currentDateTime.copyWith(
      hour: hour,
      minute: 0,
      second: 0,
    );

    // Convert API weekStart (0=Sun..6=Sat) to Dart weekday (1=Mon..7=Sun)
    // firstDay: API 0=Sun -> Dart 7, API 1=Mon -> Dart 1, API 6=Sat -> Dart 6
    int firstDayDart = weekStart == 0 ? 7 : weekStart;

    switch (this) {
      case NewTaskDue.none:
        return null;
      case NewTaskDue.today:
        return newDateTime;
      case NewTaskDue.tomorrow:
        return newDateTime.add(Duration(days: 1));
      case NewTaskDue.nextMonday:
        // Days until next occurrence of the week-start day
        int daysUntil = (firstDayDart - currentDateTime.weekday) % 7;
        if (daysUntil == 0) daysUntil = 7;
        return newDateTime.add(Duration(days: daysUntil));
      case NewTaskDue.weekend:
        // Weekend = last 2 days of the week
        // If week starts Monday (1): weekend = Sat(6) + Sun(7)
        // If week starts Sunday (7): weekend = Fri(5) + Sat(6)
        int lastDay = (firstDayDart + 5) % 7;
        if (lastDay == 0) lastDay = 7;
        int secondLast = (firstDayDart + 6) % 7;
        if (secondLast == 0) secondLast = 7;
        if (currentDateTime.weekday == lastDay ||
            currentDateTime.weekday == secondLast) {
          return newDateTime;
        }
        return newDateTime.add(
          Duration(days: (lastDay - currentDateTime.weekday) % 7),
        );
      case NewTaskDue.laterThisWeek:
        // "Later this week" = 2 days from now, unless in last 3 days of week
        int lastDay = (firstDayDart + 5) % 7;
        if (lastDay == 0) lastDay = 7;
        int secondLast = (firstDayDart + 6) % 7;
        if (secondLast == 0) secondLast = 7;
        int thirdLast = (firstDayDart + 4) % 7;
        if (thirdLast == 0) thirdLast = 7;
        bool isEndOfWeek =
            currentDateTime.weekday == lastDay ||
            currentDateTime.weekday == secondLast ||
            currentDateTime.weekday == thirdLast;
        return newDateTime.add(Duration(days: isEndOfWeek ? 0 : 2));
      case NewTaskDue.nextWeek:
        return newDateTime.add(Duration(days: 7));
      case NewTaskDue.custom:
        return currentDateTime;
    }
  }

  int calculateNearestHours(DateTime currentDate) {
    if (currentDate.hour <= 9 || currentDate.hour >= 21) {
      return 9;
    } else if (currentDate.hour < 12) {
      return 12;
    } else if (currentDate.hour < 15) {
      return 15;
    } else if (currentDate.hour < 18) {
      return 18;
    } else if (currentDate.hour < 21) {
      return 21;
    }

    return 9;
  }
}
