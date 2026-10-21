import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/picker_localizations.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';

/// A time of day without a date: the Material time picker, or a Cupertino
/// wheel of hours and minutes. The clock counts the hours as [display]
/// says; null when the user backed out.
Future<TimeOfDay?> pickTimeOfDay(
  BuildContext context, {
  required TimeOfDay initial,
  required DisplaySettings display,
  String? title,
}) => switch (Theme.of(context).platform) {
  TargetPlatform.iOS || TargetPlatform.macOS => showCupertinoPickerSheet(
    context,
    mode: CupertinoDatePickerMode.time,
    // A day without a daylight saving change, so every time exists.
    initial: DateTime(2000, 1, 1, initial.hour, initial.minute),
    use24Hour:
        display.use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context),
    title: title,
  ).then((picked) => picked == null ? null : TimeOfDay.fromDateTime(picked)),
  _ => showTimePicker(
    context: context,
    initialTime: initial,
    helpText: title,
    builder: pickerFormatsBuilder(use24HourFormat: display.use24HourFormat),
  ),
};
