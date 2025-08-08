String? getRepeatAfterTypeFromDuration(Duration? repeatAfter) {
  if (repeatAfter == null || repeatAfter.inSeconds == 0) {
    return null;
  }

  // if its dividable by 24, its something with days, otherwise hours
  if (repeatAfter.inHours % 24 == 0) {
    if (repeatAfter.inDays % 7 == 0) {
      return 'Weeks';
    } else if (repeatAfter.inDays % 365 == 0) {
      return 'Years';
    } else if (repeatAfter.inDays % 30 == 0) {
      return 'Months';
    } else {
      return 'Days';
    }
  }
  return 'Hours';
}

int? getRepeatAfterValueFromDuration(Duration? repeatAfter) {
  if (repeatAfter == null || repeatAfter.inSeconds == 0) {
    return null;
  }

  // if its dividable by 24, its something with days, otherwise hours
  if (repeatAfter.inHours % 24 == 0) {
    if (repeatAfter.inDays % 7 == 0) {
      // Weeks
      return (repeatAfter.inDays / 7).round();
    } else if (repeatAfter.inDays % 365 == 0) {
      // Years
      return (repeatAfter.inDays / 365).round();
    } else if (repeatAfter.inDays % 30 == 0) {
      // Months
      return (repeatAfter.inDays / 30).round();
    } else {
      return repeatAfter.inDays; // Days
    }
  }

  // Otherwise Hours
  return repeatAfter.inHours;
}

Duration? getDurationFromType(String? value, String? type) {
  // Return an empty duration if either of the values is not set
  if (value == null || value == '' || type == null || type == '') {
    return Duration();
  }

  int? val = int.tryParse(value);
  if (val == null) {
    return null;
  }

  switch (type) {
    case 'Hours':
      return Duration(hours: val);
    case 'Days':
      return Duration(days: val);
    case 'Weeks':
      return Duration(days: val * 7);
    case 'Months':
      return Duration(days: val * 30);
    case 'Years':
      return Duration(days: val * 365);
  }

  return null;
}
