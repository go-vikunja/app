import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteBucketTitle),
      content: Text(l10n.deleteBucketMessage),
      actions: [
        TextButton(child: Text(l10n.cancel), onPressed: () => onCancel()),
        TextButton(child: Text(l10n.delete), onPressed: () => onConfirm()),
      ],
    );
  }
}
