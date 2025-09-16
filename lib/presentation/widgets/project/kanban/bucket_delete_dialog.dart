import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskDeleteDialog extends ConsumerWidget {
  final Function onConfirm;
  final Function onCancel;

  const TaskDeleteDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: Text('Delete Bucket'),
      content: Text(
        'Are you sure you want to delete this bucket?'
        'You won't delete any tasks, they will be moved to the default bucket',
      ),
      actions: [
        TextButton(child: Text('Cancel'), onPressed: () => onCancel()),
        TextButton(child: Text('Delete'), onPressed: () => onConfirm()),
      ],
    );
  }
}
