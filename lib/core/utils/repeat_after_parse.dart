import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

List<String> getRepeatAfterArray(BuildContext context) {
  var localizations = AppLocalizations.of(context);
  return <String>[
    localizations.repeatUnitHours,
    localizations.repeatUnitDays,
    localizations.repeatUnitWeeks,
    localizations.repeatUnitMonths,
    localizations.repeatUnitYears,
  ];
}

int getRepeatAfterTypeFromDuration(Duration? repeatAfter) {
  if (repeatAfter == null || repeatAfter.inSeconds == 0) {
    return 0;
  }

  // if its dividable by 24, its something with days, otherwise hours
  if (repeatAfter.inHours % 24 == 0) {
    if (repeatAfter.inDays % 365 == 0) {
      return 4; //Years
    } else if (repeatAfter.inDays % 30 == 0) {
      return 3; //Months
    } else if (repeatAfter.inDays % 7 == 0) {
      return 2; //Weeks
    } else {
      return 1; //Days
    }
  }
  return 0; //Hours
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

Duration? getDurationFromType(int val, int type) {
  // Return an empty duration if either of the values is not set
  if (val == '' || type == '') {
    return Duration();
  }

  switch (type) {
    case 0: //Hours
      return Duration(hours: val);
    case 1: //Days
      return Duration(days: val);
    case 2: //Weeks
      return Duration(days: val * 7);
    case 3: //Months
      return Duration(days: val * 30);
    case 4: //Years
      return Duration(days: val * 365);
  }

  return null;
}
