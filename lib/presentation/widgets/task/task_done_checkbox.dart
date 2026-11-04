import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task.dart';

class TaskDoneCheckbox extends StatelessWidget {
  final Task task;
  final ValueChanged<bool> onChanged;

  const TaskDoneCheckbox({
    super.key,
    required this.task,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (task.loading) {
      return const SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Center(
          child: SizedBox(
            width: Checkbox.width,
            height: Checkbox.width,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Checkbox(
      value: task.done,
      onChanged: (bool? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }
}
