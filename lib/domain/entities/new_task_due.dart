enum NewTaskDue {
  none,
  today,
  tomorrow,
  nextMonday,
  weekend,
  laterThisWeek,
  nextWeek,
  custom;

  DateTime? calculateDate(DateTime currentDateTime) {
    int hour = calculateNearestHours(currentDateTime);
    DateTime? calculateDate(DateTime currentDateTime, {int weekStart = 1}) {
      int hour = calculateNearestHours(currentDateTime);
      var newDateTime = currentDateTime.copyWith(
        hour: hour,
        minute: 0,
        second: 0,
      );
      // Normalize weekStart: 1=Monday .. 7=Sunday
      // Calculate the day number (1=Mon..7=Sun) that is the "first day" of the week
      int firstDayOfWeek = weekStart;

      switch (this) {
        case NewTaskDue.none:
          return null;
        case NewTaskDue.today:
          return newDateTime;
        case NewTaskDue.tomorrow:
          return newDateTime.add(Duration(days: 1));
        case NewTaskDue.nextMonday:
          // Days until next occurrence of the week-start day
          int daysUntil = (firstDayOfWeek - currentDateTime.weekday) % 7;
          if (daysUntil == 0) daysUntil = 7;
          return newDateTime.add(Duration(days: daysUntil));
        case NewTaskDue.weekend:
          // Weekend = last 2 days of the week (Sat/Sun if week starts Monday)
          int lastDayOfWeek = (firstDayOfWeek + 5) % 7; // Saturday equivalent
          if (lastDayOfWeek == 0) lastDayOfWeek = 7;
          int secondLastDay = (firstDayOfWeek + 6) % 7; // Sunday equivalent
          if (secondLastDay == 0) secondLastDay = 7;
          if (currentDateTime.weekday == lastDayOfWeek ||
              currentDateTime.weekday == secondLastDay) {
            return newDateTime;
          }
          return newDateTime.add(
            Duration(days: (lastDayOfWeek - currentDateTime.weekday) % 7),
          );
        case NewTaskDue.laterThisWeek:
          // "Later this week" = 2 days from now, unless we're in the last 2 days of the week
          int lastDayOfWeek = (firstDayOfWeek + 5) % 7;
          if (lastDayOfWeek == 0) lastDayOfWeek = 7;
          int secondLastDay = (firstDayOfWeek + 6) % 7;
          if (secondLastDay == 0) secondLastDay = 7;
          bool isEndOfWeek = currentDateTime.weekday == lastDayOfWeek ||
              currentDateTime.weekday == secondLastDay ||
              currentDateTime.weekday == (firstDayOfWeek + 4) % 7 ||
              (firstDayOfWeek + 4) % 7 == 0 && currentDateTime.weekday == 5;
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
