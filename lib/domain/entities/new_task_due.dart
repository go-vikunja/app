enum NewTaskDue {
  none,
  day,
  week,
  month,
  custom;

  Duration newTaskDueToDuration() {
    switch (this) {
      case NewTaskDue.none:
        return Duration();
      case NewTaskDue.day:
        return Duration(days: 1);
      case NewTaskDue.week:
        return Duration(days: 7);
      case NewTaskDue.month:
        return Duration(days: 30);
      case NewTaskDue.custom:
        return Duration();
    }
  }
}
