import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// A Cupertino wheel in a popup with Cancel and Done, and [title] between
/// them; Done gives the value shown, Cancel or a dismissal null.
Future<DateTime?> showCupertinoPickerSheet(
  BuildContext context, {
  required CupertinoDatePickerMode mode,
  required DateTime initial,
  required bool use24Hour,
  String? title,
  DateTime? minimum,
  DateTime? maximum,
}) => showCupertinoModalPopup<DateTime>(
  context: context,
  builder: (context) => _CupertinoPickerSheet(
    mode: mode,
    initial: initial,
    use24Hour: use24Hour,
    title: title,
    minimum: minimum,
    maximum: maximum,
  ),
);

class _CupertinoPickerSheet extends StatefulWidget {
  const new({
    required this.mode,
    required this.initial,
    required this.use24Hour,
    required this.title,
    required this.minimum,
    required this.maximum,
  });

  final CupertinoDatePickerMode mode;
  final DateTime initial;
  final bool use24Hour;
  final String? title;
  final DateTime? minimum;
  final DateTime? maximum;

  @override
  State<_CupertinoPickerSheet> createState() => _CupertinoPickerSheetState();
}

class _CupertinoPickerSheetState extends State<_CupertinoPickerSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = CupertinoTheme.of(context);
    final title = widget.title;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.pickerCancel),
                ),
                Expanded(
                  child: title == null
                      ? const SizedBox.shrink()
                      : Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.navTitleTextStyle,
                          ),
                        ),
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
                mode: widget.mode,
                initialDateTime: widget.initial,
                minimumDate: widget.minimum,
                maximumDate: widget.maximum,
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
