import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

enum RepeatAfterUnit {
  hours,
  days,
  weeks,
  months,
  years;

  String toLocalizedString(BuildContext context) {
    var localizations = AppLocalizations.of(context);
    switch (this) {
      case hours:
        return localizations.repeatUnitHours;
      case days:
        return localizations.repeatUnitDays;
      case weeks:
        return localizations.repeatUnitWeeks;
      case months:
        return localizations.repeatUnitMonths;
      case years:
        return localizations.repeatUnitYears;
    }
  }

  Duration getDuration(int val) {
    switch (this) {
      case RepeatAfterUnit.hours:
        return Duration(hours: val);
      case RepeatAfterUnit.days:
        return Duration(days: val);
      case RepeatAfterUnit.weeks:
        return Duration(days: val * 7);
      case RepeatAfterUnit.months:
        return Duration(days: val * 30);
      case RepeatAfterUnit.years:
        return Duration(days: val * 365);
    }
  }
}
