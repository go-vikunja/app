import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_actions.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

/// A Cupertino sheet on iOS, a modal bottom sheet elsewhere, over the tab
/// bar.
Future<void> showAccountSwitcher(BuildContext context) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      return showReadableCupertinoSheet<void>(
        context: context,
        showDragHandle: true,
        scrollableBuilder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: AccountSwitcherSheet(scrollController: scrollController),
        ),
      );
    case _:
      return showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => const AccountSwitcherSheet(),
      );
  }
}

/// Every account, the active one first and then by when they were last
/// active; a tap on another one switches to it.
class AccountSwitcherSheet extends ConsumerWidget {
  const new({this.scrollController, super.key});

  /// The Cupertino sheet's, so that dragging the list down closes it.
  final ScrollController? scrollController;

  void _switchTo(BuildContext context, WidgetRef ref, RegisteredAccount entry) {
    Navigator.of(context).pop();
    unawaited(switchToAccount(context, ref, entry));
  }

  // The sheet goes first: a pop after the push would close the new page.
  void _add(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push(AppRoutes.addAccount));
  }

  void _manage(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(AppRoutes.account);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(accountsProvider).value;
    final accounts = state?.accountsByRecency ?? const <RegisteredAccount>[];
    // Like the Accounts section: a switch during a sign-out would race its
    // wipe, and a sign-in activates its account when it ends.
    final busy =
        ref.watch(signOutControllerProvider) ||
        ref.watch(signInControllerProvider) is SignInInProgress;

    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        // The Cupertino sheet's drag handle is drawn in the top inset; the
        // Material sheet has none.
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: 8,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                l10n.accountsHeading,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          for (final entry in accounts)
            AccountTile(
              key: ValueKey(entry.id),
              entry: entry,
              current: entry.id == state?.activeAccountId,
              onTap: entry.id == state?.activeAccountId || busy
                  ? null
                  : () => _switchTo(context, ref, entry),
            ),
          const Divider(),
          ListTile(
            leading: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.person_add_alt_1_outlined),
            ),
            title: Text(l10n.accountAdd),
            onTap: busy ? null : () => _add(context),
          ),
          ListTile(
            leading: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.manage_accounts_outlined),
            ),
            title: Text(l10n.accountManage),
            onTap: () => _manage(context),
          ),
        ],
      ),
    );
  }
}
