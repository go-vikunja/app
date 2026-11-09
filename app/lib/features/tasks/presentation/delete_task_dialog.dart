import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';

/// Asks before a task is deleted. With [trash] (a server with the bin) it
/// says the task moves to the bin and can be restored from there; a
/// [guest] is not pointed to the bin page, which only users have. An
/// [unsent] task, created on this device and maybe not on the server yet,
/// does not go to the bin, which the text then says instead.
Future<bool> confirmDeleteTask(
  BuildContext context, {
  required String title,
  bool trash = false,
  bool guest = false,
  bool unsent = false,
}) async {
  final l10n = context.l10n;
  final body = switch ((trash, unsent, guest)) {
    (false, _, _) => l10n.taskDeleteDialogBody(title),
    (true, true, _) => l10n.taskDeleteDialogBodyUnsent(title),
    (true, false, false) => l10n.taskDeleteDialogBodyTrash(title),
    (true, false, true) => l10n.taskDeleteDialogBodyTrashGuest(title),
  };
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.taskDeleteDialogTitle),
      content: Text(body),
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
