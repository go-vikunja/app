import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskDeleteDialog extends ConsumerWidget {
  final int taskId;
  final Function onConfirm;
  final Function onCancel;

  const TaskDeleteDialog(
    this.taskId, {
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text('Delete Task'),
      content: Text('Are you sure you want to delete this task?'),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            onCancel();
          },
        ),
        TextButton(
          child: Text('Delete'),
          onPressed: () {
            onConfirm();
          },
        ),
      ],
    );
  }
}
