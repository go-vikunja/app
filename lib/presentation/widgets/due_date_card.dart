import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/misc.dart';

class DueDateCard extends StatelessWidget {
  final DateTime dueDate;

  const DueDateCard(this.dueDate, {super.key});

  @override
  Widget build(BuildContext context) {
    var difference = dueDate.difference(DateTime.now());
    var textStyle = _getTextStyle(context, difference);
    var bgColor = _getBackgroundColor(difference, context);

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2),
        child: Text(
          durationToHumanReadable(difference),
          style: textStyle,
        ),
      ),
    );
  }

  Color? _getBackgroundColor(Duration difference, BuildContext context) {
    return difference.isNegative
        ? Theme.of(context).colorScheme.errorContainer
        : null;
  }

  TextStyle? _getTextStyle(BuildContext context, Duration difference) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
        color:
            difference.isNegative ? Theme.of(context).colorScheme.error : null);
  }
}
