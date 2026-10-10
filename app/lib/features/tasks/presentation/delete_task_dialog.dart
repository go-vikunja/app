import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';

Future<bool> confirmDeleteTask(
  BuildContext context, {
  required String title,
}) async {
  final l10n = context.l10n;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.taskDeleteDialogTitle),
      content: Text(l10n.taskDeleteDialogBody(title)),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.taskDeleteDialogCancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.taskDeleteDialogConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
