import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';

/// True when the user chooses to drop the unsaved edits.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final l10n = context.l10n;
  final discard = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.taskEditDiscardTitle),
      content: Text(l10n.taskEditDiscardBody),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.taskEditKeepEditing),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.taskEditDiscard),
        ),
      ],
    ),
  );
  return discard ?? false;
}
