import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

class AccountHeader extends StatelessWidget {
  const new({required this.entry, super.key});

  final RegisteredAccount entry;

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
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: Text(
              initialsOf(account.displayName),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colors.onPrimaryContainer,
              ),
              // The avatar has a fixed size; the name below scales instead.
              textScaler: TextScaler.noScaling,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          container: true,
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
        const SizedBox(height: 16),
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

String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first.characters.first;
  final last = words.length > 1 ? words.last.characters.first : '';
  return (first + last).toUpperCase();
}
