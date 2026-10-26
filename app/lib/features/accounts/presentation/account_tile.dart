import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';

/// One account in the switcher or the Accounts section: avatar, name,
/// `@username · host` (a guest's link, share name and `Guest · host`), and
/// badges for a session that ended and for changes not sent yet. The
/// [current] account is marked instead of [trailing].
class AccountTile extends ConsumerWidget {
  const new({
    required this.entry,
    this.current = false,
    this.onTap,
    this.trailing,
    this.contentPadding,
    super.key,
  });

  final RegisteredAccount entry;
  final bool current;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final account = entry.account;
    final unsent =
        ref.watch(accountPendingChangesProvider(entry.id)).value ?? 0;
    final badges = [
      if (account.needsReauth)
        _Badge(
          label: account.isLinkShare
              ? l10n.guestOpenLinkAgain
              : l10n.accountBadgeSignInAgain,
          icon: account.isLinkShare
              ? Icons.link_off
              : Icons.lock_clock_outlined,
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      if (unsent > 0)
        _Badge(
          label: l10n.accountBadgeUnsent(unsent),
          icon: Icons.cloud_upload_outlined,
          background: colors.secondaryContainer,
          foreground: colors.onSecondaryContainer,
        ),
    ];
    final trailing = current
        ? Icon(Icons.check, semanticLabel: l10n.accountCurrent)
        : this.trailing;

    final tile = ListTile(
      selected: current,
      onTap: onTap,
      contentPadding: contentPadding,
      leading: AccountAvatar(entry: entry, radius: 20),
      title: Text(accountTitle(account)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(accountSubtitleOf(l10n, entry)),
          if (badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: badges),
            ),
        ],
      ),
      trailing: trailing,
    );
    // A trailing button keeps its own node; otherwise the row is read as
    // one.
    return current || this.trailing == null
        ? MergeSemantics(child: tile)
        : tile;
  }
}

class _Badge extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 14, color: foreground)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
