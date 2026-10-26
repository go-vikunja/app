import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_sheet.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// The active account's avatar (a guest's link) at the end of an app bar;
/// opens the account switcher.
class AccountSwitcherButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    if (entry == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final name = accountTitle(entry.account);
    final host = displayHost(entry.connection.rootUri);
    void open() => unawaited(showAccountSwitcher(context));
    return Semantics(
      container: true,
      button: true,
      label: entry.account.isLinkShare
          ? l10n.guestSwitcherButton(name, host)
          : l10n.accountSwitcherButton(name, host),
      onTap: open,
      excludeSemantics: true,
      child: IconButton(
        onPressed: open,
        tooltip: l10n.accountsHeading,
        icon: AccountAvatar(entry: entry, radius: 15),
      ),
    );
  }
}
