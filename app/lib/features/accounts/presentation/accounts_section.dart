import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_actions.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';

/// The accounts other than the active one, most recently active first: a
/// tap switches, the menu removes one. Then Add account. Everything rests
/// while a sign-in or sign-out runs.
class AccountsSection extends ConsumerWidget {
  const new({required this.busy, super.key});

  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(accountsProvider).value;
    final others = [
      for (final entry
          in state?.accountsByRecency ?? const <RegisteredAccount>[])
        if (entry.id != state?.activeAccountId) entry,
    ];

    return SettingsSection(
      title: l10n.accountsHeading,
      children: [
        for (final entry in others)
          AccountTile(
            key: ValueKey(entry.id),
            entry: entry,
            onTap: busy
                ? null
                : () => unawaited(switchToAccount(context, ref, entry)),
            trailing: _AccountMenu(entry: entry, enabled: !busy),
          ),
        ListTile(
          // As wide as the accounts' avatars above it, so the titles line
          // up; alone it lines up with the other sections' icons.
          leading: others.isEmpty
              ? const Icon(Icons.person_add_alt_1_outlined)
              : const SizedBox.square(
                  dimension: 40,
                  child: Icon(Icons.person_add_alt_1_outlined),
                ),
          title: Text(l10n.accountAdd),
          onTap: busy ? null : () => addAccount(context),
        ),
      ],
    );
  }
}

enum _AccountAction { remove }

class _AccountMenu extends ConsumerWidget {
  const new({required this.entry, required this.enabled});

  final RegisteredAccount entry;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final unsent =
        ref.watch(accountPendingChangesProvider(entry.id)).value ?? 0;
    return PopupMenuButton<_AccountAction>(
      tooltip: l10n.accountMoreActions(entry.account.displayName),
      enabled: enabled,
      onSelected: (action) => switch (action) {
        _AccountAction.remove => unawaited(
          removeAccount(
            context,
            ref,
            entry,
            pendingChanges: unsent,
            fromAccountsList: true,
          ),
        ),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AccountAction.remove,
          child: Row(
            children: [
              Icon(Icons.logout, color: colors.error),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.accountRemove,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
