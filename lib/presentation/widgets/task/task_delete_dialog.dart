import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

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
      title: Text(AppLocalizations.of(context).deleteTaskTitle),
      content: Text(AppLocalizations.of(context).deleteTaskMessage),
      actions: [
        TextButton(
          child: Text(AppLocalizations.of(context).cancel),
          onPressed: () {
            onCancel();
          },
        ),
        TextButton(
          child: Text(AppLocalizations.of(context).delete),
          onPressed: () {
            onConfirm();
          },
        ),
      ],
    );
  }
}
