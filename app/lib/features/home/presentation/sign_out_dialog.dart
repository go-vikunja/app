import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// [pendingChanges] is how many queued changes the sign-out would throw
/// away with the local database; the dialog says so while there are any.
Future<bool> confirmSignOut(
  BuildContext context, {
  required Uri serverRoot,
  int pendingChanges = 0,
}) async {
  final l10n = context.l10n;
  final body = [
    l10n.signOutDialogBody(displayHost(serverRoot)),
    if (pendingChanges > 0) l10n.signOutDialogPendingChanges(pendingChanges),
  ].join(' ');
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(l10n.signOutDialogTitle),
      content: Text(body),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.signOutDialogCancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(l10n.signOutDialogConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
