import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// The signed-in account: its avatar and name, which open the account's
/// settings, and the server it is on.
class AccountHeader extends StatelessWidget {
  const new({required this.entry, required this.onOpenSettings, super.key});

  final RegisteredAccount entry;

  /// Null while the settings cannot be opened, e.g. during sign-out.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final account = entry.account;
    final connection = entry.connection;
    final version =
        connection.info.version?.display ?? connection.info.rawVersion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: onOpenSettings != null,
          onTapHint: onOpenSettings == null ? null : l10n.accountHeaderTapHint,
          child: InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  UserAvatar(
                    user: User(
                      id: account.userId,
                      username: account.username,
                      name: account.displayName,
                    ),
                    radius: 36,
                    accountId: entry.id,
                    primary: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Merged into the button, which it labels.
                        Semantics(
                          header: true,
                          child: Text(
                            account.displayName,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        if (account.displayName != account.username)
                          Text(
                            l10n.homeUsername(account.username),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    displayHost(connection.rootUri),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            if (version.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    l10n.overviewVikunjaVersion(version),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
