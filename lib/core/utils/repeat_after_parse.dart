import 'package:vikunja_app/core/utils/repeat_after_unit.dart';

RepeatAfterUnit getRepeatAfterTypeFromDuration(Duration? repeatAfter) {
  if (repeatAfter == null || repeatAfter.inSeconds == 0) {
    return RepeatAfterUnit.hours;
  }

  // if its dividable by 24, its something with days, otherwise hours
  if (repeatAfter.inHours % 24 == 0) {
    if (repeatAfter.inDays % 365 == 0) {
      return RepeatAfterUnit.years;
    } else if (repeatAfter.inDays % 30 == 0) {
      return RepeatAfterUnit.months;
    } else if (repeatAfter.inDays % 7 == 0) {
      return RepeatAfterUnit.weeks;
    } else {
      return RepeatAfterUnit.days;
    }
  }
  return RepeatAfterUnit.hours;
}

int getRepeatAfterValueFromDuration(Duration? repeatAfter) {
  if (repeatAfter == null || repeatAfter.inSeconds == 0) {
    return 0;
  }

  // if its dividable by 24, its something with days, otherwise hours
  if (repeatAfter.inHours % 24 == 0) {
    if (repeatAfter.inDays % 365 == 0) {
      return (repeatAfter.inDays / 365).round(); // Years
    } else if (repeatAfter.inDays % 30 == 0) {
      return (repeatAfter.inDays / 30).round(); // Months
    } else if (repeatAfter.inDays % 7 == 0) {
      return (repeatAfter.inDays / 7).round(); // Weeks
    } else {
      return repeatAfter.inDays; // Days
    }
  }

  // Otherwise Hours
  return repeatAfter.inHours;
}
