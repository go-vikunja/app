import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/picker_localizations.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/cupertino_picker_sheet.dart';

/// A day without a time: the Material date picker, its weeks starting on
/// [firstDayOfWeekIndex] (null: the locale's first day), or a Cupertino
/// date wheel on iOS. Only days from [first] to [last] can be picked.
/// Returns a local midnight, or null when the user backed out.
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required DateTime now,
  int? firstDayOfWeekIndex,
  String? title,
}) async {
  final firstDay = _day(first);
  final lastDay = _day(last);
  final start = _day(initial).isBefore(firstDay)
      ? firstDay
      : _day(initial).isAfter(lastDay)
      ? lastDay
      : _day(initial);
  final picked = await switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => showCupertinoPickerSheet(
      context,
      mode: CupertinoDatePickerMode.date,
      initial: start,
      use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      title: title,
      minimum: firstDay,
      maximum: lastDay,
    ),
    _ => showDatePicker(
      context: context,
      initialDate: start,
      firstDate: firstDay,
      lastDate: lastDay,
      currentDate: now,
      helpText: title,
      builder: pickerFormatsBuilder(firstDayOfWeekIndex: firstDayOfWeekIndex),
    ),
  };
  return picked == null ? null : _day(picked);
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
