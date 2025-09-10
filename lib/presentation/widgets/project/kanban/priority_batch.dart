import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/priority.dart';

class PriorityBatch extends StatelessWidget {
  final int priority;

  const PriorityBatch(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    return Badge(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      label: Text(priorityToString(priority)),
      backgroundColor: getBackgroundColor(priority),
    );
  }

  Color? getBackgroundColor(int priority) {
    switch (priority) {
      case 0:
        return null;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      case 4:
        return Colors.red;
      case 5:
        return Colors.red;
      default:
        return null;
    }
  }
}
