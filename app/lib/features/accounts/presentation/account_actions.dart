import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/accounts/presentation/remove_account_dialog.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_texts.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

final _log = Logger('AccountActions');

// The screen a flow starts from belongs to the previous account and is gone
// once the registry changes, so everything needed afterwards is read first.

/// The shell closes the previous account's screens.
Future<void> switchToAccount(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.accountSwitchedTo(accountTitle(entry.account));
  if (!await ref.read(accountSwitcherProvider).switchTo(entry.id)) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Over the shell, so that closing it returns there.
void addAccount(BuildContext context) =>
    unawaited(GoRouter.of(context).push(AppRoutes.addAccount));

/// Signs out of [entry] after asking. Removing the active account switches
/// to the most recently active other one; removing the last one returns to
/// the connect screen, without the snackbars shown or queued before.
Future<void> removeAccount(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry, {
  required int pendingChanges,
  bool fromAccountsList = false,
}) async {
  final accounts = ref.read(accountsProvider).value;
  final others = [
    for (final other
        in accounts?.accountsByRecency ?? const <RegisteredAccount>[])
      if (other.id != entry.id) other,
  ];
  final l10n = context.l10n;
  final storedSettings = await _connectionSettingsOnlyFor(
    ref,
    entry,
    accounts: accounts?.accounts ?? const [],
    l10n: l10n,
  );
  if (!context.mounted) return;
  final (:confirmed, :forgetConnectionSettings) = await confirmRemoveAccount(
    context,
    entry: entry,
    pendingChanges: pendingChanges,
    nextAccount: accounts?.activeAccountId == entry.id
        ? others.firstOrNull
        : null,
    fromAccountsList: fromAccountsList,
    connectionSettings: storedSettings,
  );
  if (!confirmed || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final name = accountTitle(entry.account);
  final message = entry.account.isLinkShare
      ? l10n.guestRemoved(name)
      : l10n.accountSignedOutOf(name);
  await ref
      .read(signOutControllerProvider.notifier)
      .signOut(entry.id, forgetConnectionSettings: forgetConnectionSettings);
  if (others.isEmpty) {
    // What is still up or queued, like the Undo of a delete, would act on
    // the account just signed out of.
    messenger.clearSnackBars();
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// What is stored for [entry]'s server when no other account (user or
/// guest) uses it, for the offer to forget it with the account.
Future<String?> _connectionSettingsOnlyFor(
  WidgetRef ref,
  RegisteredAccount entry, {
  required List<RegisteredAccount> accounts,
  required AppLocalizations l10n,
}) async {
  final origin = OriginKey.tryOf(entry.connection.rootUri);
  if (origin == null) return null;
  final shared = accounts.any(
    (other) =>
        other.id != entry.id &&
        OriginKey.tryOf(other.connection.rootUri) == origin,
  );
  if (shared) return null;
  try {
    final profile = await ref.read(networkProfilesProvider).metadataFor(origin);
    return connectionSummary(l10n, profile);
  } on Object catch (error) {
    _log.info('Connection settings not readable: ${error.runtimeType}');
    return null;
  }
}
