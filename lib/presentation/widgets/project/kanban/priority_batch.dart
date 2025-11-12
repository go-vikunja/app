import 'package:flutter/material.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/utils/priority.dart';

class PriorityBatch extends StatelessWidget {
  final int priority;

  const PriorityBatch(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    return Badge(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      label: Text(priorityToString(priority)),
      backgroundColor: getBackgroundColor(context, priority),
    );
  }

  Color? getBackgroundColor(BuildContext context, int priority) {
    final appColors = Theme.of(context).extension<AppColors>();
    switch (priority) {
      case 0:
        return null;
      case 1:
        return appColors?.success ?? Colors.green;
      case 2:
        return appColors?.warning ?? Colors.yellow;
      case 3:
      case 4:
      case 5:
        return appColors?.danger ?? Colors.red;
      default:
        return null;
    }
  }

  Color? getTextColor(BuildContext context, int priority) {
    final appColors = Theme.of(context).extension<AppColors>();
    switch (priority) {
      case 0:
        return null;
      case 1:
        return appColors?.onSuccess ?? Colors.green;
      case 2:
        return appColors?.onWarning ?? Colors.yellow;
      case 3:
      case 4:
      case 5:
        return appColors?.onDanger ?? Colors.red;
      default:
        return null;
    }
  }
}
