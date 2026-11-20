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
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/application/https_twins.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/accounts/presentation/remove_account_dialog.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_texts.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';

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

/// Signs out of [entry] after asking (see [confirmRemoveAccount]).
/// Removing the active account switches to the most recently active other
/// one; removing the last one returns to the connect screen, without the
/// snackbars shown or queued before. The user's answer; null when the
/// question was never shown.
Future<bool?> removeAccount(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry, {
  required int pendingChanges,
  bool fromAccountsList = false,
  String? title,
  String? reason,
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
  if (!context.mounted) return null;
  final (:confirmed, :forgetConnectionSettings) = await confirmRemoveAccount(
    context,
    entry: entry,
    pendingChanges: pendingChanges,
    nextAccount: accounts?.activeAccountId == entry.id
        ? others.firstOrNull
        : null,
    fromAccountsList: fromAccountsList,
    connectionSettings: storedSettings,
    title: title,
    reason: reason,
  );
  if (!confirmed || !context.mounted) return confirmed;
  final messenger = ScaffoldMessenger.of(context);
  final name = accountTitle(entry.account);
  final message = entry.account.isLinkShare
      ? l10n.guestRemoved(name)
      : l10n.accountSignedOutOf(name);
  try {
    await ref
        .read(signOutControllerProvider.notifier)
        .signOut(entry.id, forgetConnectionSettings: forgetConnectionSettings);
  } on Object catch (error) {
    _log.warning('Could not sign out: ${error.runtimeType}');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            entry.account.isLinkShare
                ? l10n.guestRemoveFailed(name)
                : l10n.accountSignOutFailed(name),
          ),
        ),
      );
    return true;
  }
  if (others.isEmpty) {
    // What is still up or queued, like the Undo of a delete, would act on
    // the account just signed out of.
    messenger.clearSnackBars();
    return true;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  return true;
}

/// When the active account has an http twin (see [httpTwinOf]), offers to
/// remove that one, whose reminders would otherwise come twice. Its unsent
/// changes are counted first, so the question says they would be lost.
/// Once kept, it is asked again only after changes it had unsent then have
/// gone, or after it signed out and in again ([KeptHttpTwins]).
Future<void> offerToRemoveHttpTwin(BuildContext context, WidgetRef ref) async {
  final accounts = ref.read(accountsProvider).value;
  final entry = accounts?.activeAccount;
  if (accounts == null || entry == null) return;
  final twin = httpTwinOf(accounts.accounts, entry);
  if (twin == null) return;
  final kept = KeptHttpTwins(ref.read(preferencesStoreProvider));
  final int unsent;
  final int? unsentWhenKept;
  try {
    unsent = await ref.read(accountOutboxesProvider).queuedOps(twin.id);
    unsentWhenKept = await kept.unsentWhenKept(twin.id);
  } on Object catch (error) {
    _log.warning(
      'Could not count the changes of the http account: '
      '${error.runtimeType}',
    );
    return;
  }
  if (unsentWhenKept != null && (unsentWhenKept == 0 || unsent > 0)) return;
  if (!context.mounted) return;
  final l10n = context.l10n;
  final removed = await removeAccount(
    context,
    ref,
    twin,
    pendingChanges: unsent,
    fromAccountsList: true,
    title: l10n.httpAccountRemoveTitle,
    reason: l10n.httpAccountRemoveReason(displayHost(entry.connection.rootUri)),
  );
  if (removed != false) return;
  try {
    await kept.keep(
      twin.id,
      unsent: unsent,
      accountIds: {for (final other in accounts.accounts) other.id},
    );
  } on Object catch (error) {
    _log.warning('Could not note the kept account: ${error.runtimeType}');
  }
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
