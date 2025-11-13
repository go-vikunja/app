enum NewTaskDue {
  none,
  today,
  tomorrow,
  next_monday,
  weekend,
  later_this_week,
  next_week,
  custom;

  DateTime? calculateDate() {
    int hour = calculateNearestHours();

    var dateTime = DateTime.now();
    switch (this) {
      case NewTaskDue.none:
        return null;
      case NewTaskDue.today:
        return dateTime.copyWith(hour: hour, minute: 0, second: 0);
      case NewTaskDue.tomorrow:
        return dateTime
            .copyWith(hour: hour, minute: 0, second: 0)
            .add(Duration(days: 1));
      case NewTaskDue.next_monday:
        return dateTime
            .copyWith(hour: hour, minute: 0, second: 0)
            .add(Duration(days: (DateTime.monday - dateTime.weekday) % 7));
      case NewTaskDue.weekend:
        return dateTime
            .copyWith(hour: hour, minute: 0, second: 0)
            .add(Duration(days: (DateTime.saturday - dateTime.weekday) % 6));
      case NewTaskDue.later_this_week:
        return dateTime
            .copyWith(hour: hour, minute: 0, second: 0)
            .add(
              Duration(
                days:
                    dateTime.day == DateTime.friday ||
                        dateTime.day == DateTime.saturday ||
                        dateTime.day == DateTime.sunday
                    ? 0
                    : 2,
              ),
            );
      case NewTaskDue.next_week:
        return dateTime.copyWith(hour: hour).add(Duration(days: 7));
      case NewTaskDue.custom:
        return DateTime.now();
    }
  }

  int calculateNearestHours() {
    DateTime currentDate = DateTime.now();

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
