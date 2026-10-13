import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// A range of whole days: the Material date picker for the first day and
/// again for the last, or on iOS one Cupertino date wheel for either end.
/// Returns local midnights, the first day not after the last; null when
/// the user backed out. Not the Material date range picker: its header row
/// overflows a small phone even at the normal text size in German.
Future<(DateTime, DateTime)?> pickDayRange(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  required DateTime now,
}) {
  final firstDate = DateTime(2000);
  final lastDate = DateTime(now.year + 50, 12, 31);
  DateTime clamp(DateTime day) => day.isBefore(firstDate)
      ? firstDate
      : day.isAfter(lastDate)
      ? lastDate
      : day;
  return switch (Theme.of(context).platform) {
    TargetPlatform.iOS ||
    TargetPlatform.macOS => showCupertinoModalPopup<(DateTime, DateTime)>(
      context: context,
      builder: (context) => _CupertinoDayRangeSheet(
        first: clamp(first),
        last: clamp(last),
        minimum: firstDate,
        maximum: lastDate,
        now: now,
      ),
    ),
    _ => _pickWithMaterialDialogs(
      context,
      first: clamp(first),
      last: clamp(last),
      firstDate: firstDate,
      lastDate: lastDate,
      now: now,
    ),
  };
}

Future<(DateTime, DateTime)?> _pickWithMaterialDialogs(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime now,
}) async {
  final l10n = context.l10n;
  final from = await showDatePicker(
    context: context,
    initialDate: first,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: now,
    helpText: l10n.upcomingRangeFrom,
  );
  if (from == null || !context.mounted) return null;
  final to = await showDatePicker(
    context: context,
    initialDate: last.isBefore(from) ? from : last,
    firstDate: from,
    lastDate: lastDate,
    currentDate: now,
    helpText: l10n.upcomingRangeTo,
  );
  if (to == null) return null;
  return (_day(from), _day(to));
}

DateTime _day(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

enum _End { first, last }

class _CupertinoDayRangeSheet extends StatefulWidget {
  const new({
    required this.first,
    required this.last,
    required this.minimum,
    required this.maximum,
    required this.now,
  });

  final DateTime first;
  final DateTime last;
  final DateTime minimum;
  final DateTime maximum;
  final DateTime now;

  @override
  State<_CupertinoDayRangeSheet> createState() =>
      _CupertinoDayRangeSheetState();
}

class _CupertinoDayRangeSheetState extends State<_CupertinoDayRangeSheet> {
  late DateTime _first = widget.first;
  late DateTime _last = widget.last;
  _End _editing = _End.first;

  void _done() {
    final (first, last) = _last.isBefore(_first)
        ? (_last, _first)
        : (_first, _last);
    Navigator.of(context).pop((_day(first), _day(last)));
  }

  /// One wheel edits either end, so each segment shows its end's day.
  Widget _segment(String label, DateTime day) {
    final materialL10n = MaterialLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Text(
          day.year == widget.now.year
              ? materialL10n.formatShortMonthDay(day)
              : materialL10n.formatShortDate(day),
          style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
        ),
      ],
    );
  }

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
                CupertinoButton(onPressed: _done, child: Text(l10n.pickerDone)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<_End>(
                groupValue: _editing,
                onValueChanged: (end) {
                  if (end != null) setState(() => _editing = end);
                },
                children: {
                  _End.first: _segment(l10n.upcomingRangeFrom, _first),
                  _End.last: _segment(l10n.upcomingRangeTo, _last),
                },
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                key: ValueKey(_editing),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _editing == _End.first ? _first : _last,
                minimumDate: widget.minimum,
                maximumDate: widget.maximum,
                onDateTimeChanged: (value) => setState(() {
                  if (_editing == _End.first) {
                    _first = value;
                  } else {
                    _last = value;
                  }
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
