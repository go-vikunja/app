import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_identity.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// The signed-in account: its avatar, name, username and server, and Edit;
/// the whole row opens the account's settings. A link-share guest has no
/// settings: its link, name and `Guest · host` only.
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
    final host = displayHost(entry.connection.rootUri);
    final avatar = AccountAvatar(entry: entry, radius: 28);

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(accountTitle(account), style: theme.textTheme.titleLarge),
        ),
        Text(
          account.isLinkShare
              ? l10n.guestAccountSubtitle(host)
              : account.displayName == account.username
              ? host
              : l10n.accountSubtitle(account.username, host),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (account.isLinkShare) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 16),
            Expanded(child: texts),
          ],
        ),
      );
    }
    final edit = ExcludeSemantics(
      child: OutlinedButton(
        onPressed: onOpenSettings,
        child: Text(l10n.accountHeaderEdit),
      ),
    );
    // With large text Edit goes below the name, which keeps its width.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;

    // One button for screen readers, labelled by the name and the line
    // below it; Edit does the same for touch and is not read twice.
    return MergeSemantics(
      child: Semantics(
        button: onOpenSettings != null,
        onTapHint: onOpenSettings == null ? null : l10n.accountHeaderTapHint,
        child: InkWell(
          onTap: onOpenSettings,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: largeText
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 16),
                Expanded(
                  child: largeText
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [texts, edit],
                        )
                      : Row(
                          spacing: 8,
                          children: [
                            Expanded(child: texts),
                            edit,
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
