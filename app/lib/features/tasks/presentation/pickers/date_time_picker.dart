import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show withDefaultTime;
import 'package:vikunja_mobile/app/l10n/picker_localizations.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';

/// A date with a time: the Material date picker followed by the time
/// picker, or one Cupertino wheel. Starts from [current], else today at the
/// user's default due time or the breakpoint time for [now]. The calendar
/// starts the week and the clock counts the hours as [display] says.
/// Returns a local instant, or null when the user backed out of the date.
/// Backing out of the time keeps the picked day as a date-only pick
/// ([dayWithTime]): at the time the clock started from, except a time on
/// today that has passed, which becomes 23:59 (QA-8).
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime? current,
  required DateTime now,
  required DisplaySettings display,
}) {
  // The default time even when it has passed today: the user picks the
  // day first, and the time next.
  final initial =
      current?.toLocal() ??
      withDefaultTime(now, now: now, defaultTime: display.defaultDueTime);
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
      current: current,
      initial: initial,
      now: now,
      display: display,
    ),
  };
}

Future<DateTime?> _pickWithMaterialDialogs(
  BuildContext context, {
  required DateTime? current,
  required DateTime initial,
  required DateTime now,
  required DisplaySettings display,
}) async {
  final formats = pickerFormatsBuilder(
    firstDayOfWeekIndex: display.firstDayOfWeekIndex,
    use24HourFormat: display.use24HourFormat,
  );
  // A stored date outside the usual range widens it: clamping would change
  // the date on a plain OK.
  final initialDay = DateUtils.dateOnly(initial);
  final usualFirst = DateTime(2000);
  final usualLast = DateTime(now.year + 50, 12, 31);
  final day = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: initialDay.isBefore(usualFirst) ? initialDay : usualFirst,
    lastDate: initialDay.isAfter(usualLast) ? initialDay : usualLast,
    currentDate: now,
    builder: formats,
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: formats,
  );
  if (time == null) {
    return dayWithTime(
      day,
      current: current,
      now: now,
      defaultTime: display.defaultDueTime,
    );
  }
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}
