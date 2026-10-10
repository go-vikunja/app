import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/application/date_shortcuts.dart';

/// A date with a time: the Material date picker followed by the time
/// picker, or one Cupertino wheel. Starts from [current], else today at the
/// breakpoint time for [now]; a cancelled time picker keeps that time.
/// Returns a local instant, or null when the user backed out.
Future<DateTime?> pickDateTime(
  BuildContext context, {
  required DateTime? current,
  required DateTime now,
}) {
  final initial =
      current?.toLocal() ?? dayWithTime(now, current: null, now: now);
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => showCupertinoModalPopup(
      context: context,
      builder: (context) => _CupertinoDateTimeSheet(
        initial: initial,
        use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    ),
    _ => _pickWithMaterialDialogs(context, initial: initial, now: now),
  };
}

Future<DateTime?> _pickWithMaterialDialogs(
  BuildContext context, {
  required DateTime initial,
  required DateTime now,
}) async {
  final day = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 50, 12, 31),
    currentDate: now,
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return DateTime(
    day.year,
    day.month,
    day.day,
    time?.hour ?? initial.hour,
    time?.minute ?? initial.minute,
  );
}

class _CupertinoDateTimeSheet extends StatefulWidget {
  const new({required this.initial, required this.use24Hour});

  final DateTime initial;
  final bool use24Hour;

  @override
  State<_CupertinoDateTimeSheet> createState() =>
      _CupertinoDateTimeSheetState();
}

class _CupertinoDateTimeSheetState extends State<_CupertinoDateTimeSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final background = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.pickerCancel),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(_value),
                  child: Text(l10n.pickerDone),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                initialDateTime: widget.initial,
                use24hFormat: widget.use24Hour,
                onDateTimeChanged: (value) => _value = value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
