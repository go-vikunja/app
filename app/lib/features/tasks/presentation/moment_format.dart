import 'package:material_ui/material_ui.dart';

/// An instant as the detail sheet shows it: short date and time of day in
/// device local time.
String formatMoment(BuildContext context, DateTime moment) {
  final materialL10n = MaterialLocalizations.of(context);
  final local = moment.toLocal();
  final time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '${materialL10n.formatShortDate(local)} $time';
}
