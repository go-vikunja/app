import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/outbox/task_deletion.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

/// Asks before a task is deleted. With [trash] (a server with the bin) it
/// says the task moves to the bin and can be restored from there; a
/// [guest] is not pointed to the bin page, which only users have. A task
/// created on this device that the server does not have
/// ([TaskOnServer.no]) does not go to the bin, and one it may have
/// ([TaskOnServer.maybe]) only if it has it, which the text then says.
Future<bool> confirmDeleteTask(
  BuildContext context, {
  required String title,
  bool trash = false,
  bool guest = false,
  TaskOnServer onServer = TaskOnServer.yes,
}) {
  final l10n = context.l10n;
  final body = switch ((trash, onServer, guest)) {
    (false, _, _) => l10n.taskDeleteDialogBody(title),
    (true, TaskOnServer.no, _) => l10n.taskDeleteDialogBodyUnsent(title),
    (true, TaskOnServer.maybe, _) => l10n.taskDeleteDialogBodyUnconfirmed(
      title,
    ),
    (true, TaskOnServer.yes, false) => l10n.taskDeleteDialogBodyTrash(title),
    (true, TaskOnServer.yes, true) => l10n.taskDeleteDialogBodyTrashGuest(
      title,
    ),
  };
  return confirmAdaptive(
    context,
    title: l10n.taskDeleteDialogTitle,
    body: body,
    confirmLabel: l10n.taskDeleteDialogConfirm,
    cancelLabel: l10n.taskDeleteDialogCancel,
    destructive: true,
  );
}
