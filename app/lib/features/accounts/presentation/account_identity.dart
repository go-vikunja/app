import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

export 'package:vikunja_mobile/core/auth/account_title.dart';

/// `@username · host`, or `Guest · host` for a link-share guest, whose
/// username is the server's made-up `link-share-<id>`.
String accountSubtitleOf(AppLocalizations l10n, RegisteredAccount entry) {
  final host = displayHost(entry.connection.rootUri);
  final account = entry.account;
  return account.isLinkShare
      ? l10n.guestAccountSubtitle(host)
      : l10n.accountSubtitle(account.username, host);
}

/// The user's avatar from the account's server, or a link for a guest,
/// which has no picture of its own. Only decoration, like [UserAvatar].
class AccountAvatar extends StatelessWidget {
  const new({required this.entry, required this.radius, super.key});

  final RegisteredAccount entry;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final account = entry.account;
    if (!account.isLinkShare) {
      return UserAvatar(
        user: User(
          id: account.userId,
          username: account.username,
          name: account.displayName,
        ),
        radius: radius,
        accountId: entry.id,
        primary: true,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: colors.tertiaryContainer,
        child: Icon(
          Icons.link,
          size: radius * 1.1,
          color: colors.onTertiaryContainer,
        ),
      ),
    );
  }
}
