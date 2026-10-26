import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/features/sharing/presentation/share_texts.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

Future<bool> confirmLeaveTeam(
  BuildContext context, {
  required String team,
  required bool cleansUp,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.teamLeaveTitle(team),
    body: accessRemovalBody(
      l10n,
      loss: l10n.teamLeaveBody,
      self: true,
      listsCleanup: cleansUp,
    ),
    confirmLabel: l10n.teamLeaveConfirm,
    destructive: true,
  );
}

Future<bool> confirmRemoveMember(
  BuildContext context, {
  required String name,
  required bool cleansUp,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.teamRemoveTitle(name),
    body: accessRemovalBody(
      l10n,
      loss: l10n.teamRemoveBody(name),
      self: false,
      listsCleanup: cleansUp,
    ),
    confirmLabel: l10n.teamRemoveConfirm,
    destructive: true,
  );
}

Future<bool> confirmDeleteTeam(
  BuildContext context, {
  required String team,
  required bool cleansUp,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.teamDeleteTitle(team),
    body: accessRemovalBody(
      l10n,
      loss: l10n.teamDeleteBody,
      self: false,
      listsCleanup: cleansUp,
    ),
    confirmLabel: l10n.teamDelete,
    destructive: true,
  );
}

/// Leaving as the only admin while others stay would leave a team nobody
/// can change; the server does not prevent it.
Future<void> explainOnlyAdmin(BuildContext context) {
  final l10n = context.l10n;
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.teamOnlyAdminTitle),
      content: Text(l10n.teamOnlyAdminBody),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.teamOk),
        ),
      ],
    ),
  );
}

/// The last member cannot leave; true when the user deletes the team
/// instead (which asks again).
Future<bool> offerDeleteInstead(BuildContext context) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.teamLastMemberTitle,
    body: l10n.teamLastMemberBody,
    confirmLabel: l10n.teamDelete,
    destructive: true,
  );
}
