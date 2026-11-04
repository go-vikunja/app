import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class TaskDeleteDialog extends StatefulWidget {
  final int taskId;
  final Future<void> Function() onConfirm;
  final VoidCallback onCancel;

  const TaskDeleteDialog(
    this.taskId, {
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<TaskDeleteDialog> createState() => _TaskDeleteDialogState();
}

class _TaskDeleteDialogState extends State<TaskDeleteDialog> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: Text(AppLocalizations.of(context).deleteTaskTitle),
        content: Text(AppLocalizations.of(context).deleteTaskMessage),
        actions: [
          TextButton(
            onPressed: _deleting ? null : widget.onCancel,
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: _deleting ? null : _confirm,
            child: _deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _deleting = true;
    });

    await widget.onConfirm();

    if (mounted) {
      setState(() {
        _deleting = false;
      });
    }
  }
}
