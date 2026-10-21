import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// The active account's avatar at the end of an app bar; opens the
/// account switcher.
class AccountSwitcherButton extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      accountsProvider.select((accounts) => accounts.value?.activeAccount),
    );
    if (entry == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    void open() => unawaited(showAccountSwitcher(context));
    return Semantics(
      container: true,
      button: true,
      label: l10n.accountSwitcherButton(
        entry.account.displayName,
        displayHost(entry.connection.rootUri),
      ),
      onTap: open,
      excludeSemantics: true,
      child: IconButton(
        onPressed: open,
        tooltip: l10n.accountsHeading,
        icon: UserAvatar(
          user: User(
            id: entry.account.userId,
            username: entry.account.username,
            name: entry.account.displayName,
          ),
          radius: 15,
          accountId: entry.id,
          primary: true,
        ),
      ),
    );
  }
}
