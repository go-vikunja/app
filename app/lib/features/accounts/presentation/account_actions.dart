import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/presentation/remove_account_dialog.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

// The screen a flow starts from belongs to the previous account and is gone
// once the registry changes, so everything needed afterwards is read first.

/// The shell closes the previous account's screens.
Future<void> switchToAccount(
  BuildContext context,
  WidgetRef ref,
  RegisteredAccount entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.accountSwitchedTo(entry.account.displayName);
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
/// the connect screen.
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
  final confirmed = await confirmRemoveAccount(
    context,
    entry: entry,
    pendingChanges: pendingChanges,
    nextAccount: accounts?.activeAccountId == entry.id
        ? others.firstOrNull
        : null,
    fromAccountsList: fromAccountsList,
  );
  if (!confirmed || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.accountSignedOutOf(entry.account.displayName);
  await ref.read(signOutControllerProvider.notifier).signOut(entry.id);
  if (others.isEmpty) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
