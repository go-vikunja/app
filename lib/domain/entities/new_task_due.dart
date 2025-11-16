enum NewTaskDue {
  none,
  today,
  tomorrow,
  next_monday,
  weekend,
  later_this_week,
  next_week,
  custom;

  DateTime? calculateDate(DateTime currentDateTime) {
    int hour = calculateNearestHours(currentDateTime);

    var newDateTime = currentDateTime.copyWith(
      hour: hour,
      minute: 0,
      second: 0,
    );

    switch (this) {
      case NewTaskDue.none:
        return null;
      case NewTaskDue.today:
        return newDateTime;
      case NewTaskDue.tomorrow:
        return newDateTime.add(Duration(days: 1));
      case NewTaskDue.next_monday:
        return newDateTime.add(
          Duration(days: (DateTime.monday - currentDateTime.weekday) % 7),
        );
      case NewTaskDue.weekend:
        if (currentDateTime.weekday == DateTime.saturday ||
            currentDateTime.weekday == DateTime.sunday) {
          return newDateTime;
        } else {
          return newDateTime.add(
            Duration(days: (DateTime.saturday - currentDateTime.weekday) % 6),
          );
        }
      case NewTaskDue.later_this_week:
        return newDateTime.add(
          Duration(
            days: currentDateTime.weekday == DateTime.friday ||
                    currentDateTime.weekday == DateTime.saturday ||
                    currentDateTime.weekday == DateTime.sunday
                ? 0
                : 2,
          ),
        );
      case NewTaskDue.next_week:
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
