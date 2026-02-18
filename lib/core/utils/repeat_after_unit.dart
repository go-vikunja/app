import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

enum RepeatAfterUnit {
  HOURS,
  DAYS,
  WEEKS,
  MONTHS,
  YEARS;

  String toLocalizedString(BuildContext context) {
    var localizations = AppLocalizations.of(context);
    switch (this) {
      case HOURS:
        return localizations.repeatUnitHours;
      case DAYS:
        return localizations.repeatUnitDays;
      case WEEKS:
        return localizations.repeatUnitWeeks;
      case MONTHS:
        return localizations.repeatUnitMonths;
      case YEARS:
        return localizations.repeatUnitYears;
    }
  }

  Duration getDuration(int val) {
    switch (this) {
      case RepeatAfterUnit.HOURS:
        return Duration(hours: val);
      case RepeatAfterUnit.DAYS:
        return Duration(days: val);
      case RepeatAfterUnit.WEEKS:
        return Duration(days: val * 7);
      case RepeatAfterUnit.MONTHS:
        return Duration(days: val * 30);
      case RepeatAfterUnit.YEARS:
        return Duration(days: val * 365);
    }
  }
}
