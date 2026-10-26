import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// Names the account and its server; a guest's is worded as removing the
/// guest access. [pendingChanges] is how many queued changes the sign-out
/// would throw away with the local database; the dialog says so while
/// there are any. [nextAccount] is the account the app switches to
/// afterwards. [fromAccountsList] words it as removing one of the other
/// accounts, whose changes only that account's Send now can send, and only
/// once it is signed in again if its session ended.
Future<bool> confirmRemoveAccount(
  BuildContext context, {
  required RegisteredAccount entry,
  int pendingChanges = 0,
  RegisteredAccount? nextAccount,
  bool fromAccountsList = false,
}) async {
  final l10n = context.l10n;
  final account = entry.account;
  final guest = account.isLinkShare;
  final host = displayHost(entry.connection.rootUri);
  final name = account.displayName == account.username
      ? account.username
      : l10n.signOutDialogAccount(account.displayName, account.username);
  final body = [
    if (guest)
      l10n.guestRemoveDialogBody(accountTitle(account), host)
    else
      l10n.signOutDialogBody(name, host),
    if (pendingChanges > 0 && fromAccountsList && account.needsReauth && guest)
      l10n.guestRemoveDialogPendingChangesOpenLinkFirst(pendingChanges)
    else if (pendingChanges > 0 && fromAccountsList && account.needsReauth)
      l10n.removeAccountDialogPendingChangesSignInFirst(pendingChanges)
    else if (pendingChanges > 0 && fromAccountsList)
      l10n.removeAccountDialogPendingChanges(pendingChanges)
    else if (pendingChanges > 0)
      l10n.signOutDialogPendingChanges(pendingChanges),
    if (nextAccount != null)
      l10n.signOutDialogSwitchesTo(accountTitle(nextAccount.account)),
  ].join(' ');
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      scrollable: true,
      title: Text(switch ((guest, fromAccountsList)) {
        (true, _) => l10n.guestRemoveDialogTitle,
        (false, true) => l10n.removeAccountDialogTitle,
        (false, false) => l10n.signOutDialogTitle,
      }),
      content: Text(body),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.signOutDialogCancel),
        ),
        AdaptiveDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructive: true,
          child: Text(
            guest || fromAccountsList
                ? l10n.removeAccountDialogConfirm
                : l10n.signOutDialogConfirm,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
