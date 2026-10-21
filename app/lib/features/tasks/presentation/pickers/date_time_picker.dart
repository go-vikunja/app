import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/picker_localizations.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';

/// A date with a time: the Material date picker followed by the time
/// picker, or one Cupertino wheel. Starts from [current], else today at the
/// breakpoint time for [now]; a cancelled time picker keeps that time.
/// The calendar starts the week and the clock counts the hours as
/// [display] says. Returns a local instant, or null when the user backed
/// out.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime? current,
  required DateTime now,
  required DisplaySettings display,
}) {
  final initial =
      current?.toLocal() ?? dayWithTime(now, current: null, now: now);
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => showCupertinoPickerSheet(
      context,
      mode: CupertinoDatePickerMode.dateAndTime,
      initial: initial,
      use24Hour:
          display.use24HourFormat ??
          MediaQuery.alwaysUse24HourFormatOf(context),
    ),
    _ => _pickWithMaterialDialogs(
      context,
      initial: initial,
      now: now,
      display: display,
    ),
  };
}

Future<DateTime?> _pickWithMaterialDialogs(
  BuildContext context, {
  required DateTime initial,
  required DateTime now,
  required DisplaySettings display,
}) async {
  final formats = pickerFormatsBuilder(
    firstDayOfWeekIndex: display.firstDayOfWeekIndex,
    use24HourFormat: display.use24HourFormat,
  );
  final day = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 50, 12, 31),
    currentDate: now,
    builder: formats,
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: formats,
  );
  return DateTime(
    day.year,
    day.month,
    day.day,
    time?.hour ?? initial.hour,
    time?.minute ?? initial.minute,
  );
}
