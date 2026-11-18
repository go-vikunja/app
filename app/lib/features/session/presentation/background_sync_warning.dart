import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/app_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/session/application/background_restriction.dart';

/// The device keeps the background sync from running, which is what keeps
/// the sessions alive (D22): the server then ends one after 3 days without
/// the app opened. With the way to the app's page in the system settings,
/// unless the user cannot change it there. Nothing while no user account
/// is signed in, as a guest's session signs in again by itself (D62).
/// [framed] puts it on a card of its own below a gap, for a screen
/// without sections.
class BackgroundSyncWarning extends ConsumerWidget {
  const new({this.framed = false, super.key});

  final bool framed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restriction = ref.watch(backgroundRestrictionStateProvider).value;
    final hasUser = ref.watch(
      accountsProvider.select(
        (accounts) =>
            accounts.value?.accounts.any(
              (entry) => !entry.account.isLinkShare,
            ) ??
            false,
      ),
    );
    if (restriction == null || !hasUser) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final block = SettingsBlock(
      icon: Icons.sync_disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  l10n.backgroundSyncLimitedTitle,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  switch (restriction) {
                    BackgroundRestriction.refreshOff ||
                    BackgroundRestriction.refreshRestricted =>
                      l10n.backgroundSyncLimitedIos,
                    BackgroundRestriction.restricted =>
                      l10n.backgroundSyncLimitedAndroid,
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (restriction.hasSetting)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => unawaited(_openSettings(context, ref)),
                child: Text(l10n.backgroundSyncOpenSettings),
              ),
            ),
        ],
      ),
    );
    if (!framed) return block;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card.outlined(margin: EdgeInsets.zero, child: block),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.backgroundSyncSettingsNotOpened;
    if (await ref.read(appSettingsPageProvider).open()) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
  }
}
