import 'package:vikunja_app/l10n/gen/app_localizations.dart';

priorityToString(int? priority) {
  switch (priority) {
    case 0:
      return 'Unset';
    case 1:
      return 'Low';
    case 2:
      return 'Medium';
    case 3:
      return 'High';
    case 4:
      return 'Urgent';
    case 5:
      return 'DO NOW';
    default:
      return "";
  }
}

// FIXME: Move the following two functions to an extra class or type.
priorityFromString(String? priority) {
  switch (priority) {
    case 'Low':
      return 1;
    case 'Medium':
      return 2;
    case 'High':
      return 3;
    case 'Urgent':
      return 4;
    case 'DO NOW':
      return 5;
    default:
      // unset
      return 0;
  }
}

// Localized variants
String priorityToStringL10n(AppLocalizations l10n, int? priority) {
  switch (priority) {
    case 0:
      return l10n.priorityUnset;
    case 1:
      return l10n.priorityLow;
    case 2:
      return l10n.priorityMedium;
    case 3:
      return l10n.priorityHigh;
    case 4:
      return l10n.priorityUrgent;
    case 5:
      return l10n.priorityDoNow;
    default:
      return '';
  }
}

int? priorityFromStringL10n(AppLocalizations l10n, String? priority) {
  if (priority == l10n.priorityLow) return 1;
  if (priority == l10n.priorityMedium) return 2;
  if (priority == l10n.priorityHigh) return 3;
  if (priority == l10n.priorityUrgent) return 4;
  if (priority == l10n.priorityDoNow) return 5;
  if (priority == l10n.priorityUnset) return 0;
  return 0;
}
