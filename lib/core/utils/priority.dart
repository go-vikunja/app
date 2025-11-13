import 'package:vikunja_app/l10n/gen/app_localizations.dart';

/// Returns the localized label for the given priority value.
/// 0 -> Unset, 1 -> Low, 2 -> Medium, 3 -> High, 4 -> Urgent, 5 -> DO NOW
String priorityToString(AppLocalizations loc, int? priority) {
  switch (priority) {
    case 0:
      return loc.priorityUnset;
    case 1:
      return loc.priorityLow;
    case 2:
      return loc.priorityMedium;
    case 3:
      return loc.priorityHigh;
    case 4:
      return loc.priorityUrgent;
    case 5:
      return loc.priorityDoNow;
    default:
      return '';
  }
}

/// Parses a localized priority label back into its numeric value.
/// Returns 0 (unset) for unknown strings.
int priorityFromString(AppLocalizations loc, String? priority) {
  if (priority == loc.priorityLow) return 1;
  if (priority == loc.priorityMedium) return 2;
  if (priority == loc.priorityHigh) return 3;
  if (priority == loc.priorityUrgent) return 4;
  if (priority == loc.priorityDoNow) return 5;
  if (priority == loc.priorityUnset) return 0;
  return 0;
}
