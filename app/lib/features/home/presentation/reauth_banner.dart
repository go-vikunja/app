import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_button.dart';

/// The server ended the session: sign in again, or for a link-share
/// [guest] open the shared link again.
class ReauthBanner extends StatelessWidget {
  const new({
    required this.serverRoot,
    required this.isSigningIn,
    required this.onSignInAgain,
    this.guest = false,
    super.key,
  });

  final Uri serverRoot;
  final bool isSigningIn;
  final VoidCallback onSignInAgain;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = colors.onTertiaryContainer;
    final host = displayHost(serverRoot);
    return Card.filled(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    guest ? Icons.link_off : Icons.lock_clock_outlined,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guest ? l10n.guestReauthTitle : l10n.reauthTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          guest
                              ? l10n.guestReauthBody(host)
                              : l10n.reauthBody(host),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SignInButton(
              label: guest ? l10n.guestOpenLinkAgain : l10n.reauthAction,
              isSigningIn: isSigningIn,
              onPressed: onSignInAgain,
            ),
          ],
        ),
      ),
    );
  }
}
