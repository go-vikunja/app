import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_button.dart';

/// Without [onCreateAccount] or [onForgotPassword] that button is hidden.
class OverviewActions extends StatelessWidget {
  const new({
    required this.canSignIn,
    required this.isSigningIn,
    required this.onContinue,
    required this.onUseDifferentServer,
    this.isSettling = false,
    this.onCreateAccount,
    this.onForgotPassword,
    this.registrationNeedsInvitation = false,
    super.key,
  });

  final bool canSignIn;
  final bool isSigningIn;

  /// Waiting for an earlier sign-out before the browser opens; leaving
  /// stays possible.
  final bool isSettling;
  final VoidCallback onContinue;
  final VoidCallback onUseDifferentServer;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onForgotPassword;
  final bool registrationNeedsInvitation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final useDifferentServer = Text(
      l10n.useDifferentServer,
      textAlign: TextAlign.center,
    );
    final onCreateAccount = this.onCreateAccount;
    final onForgotPassword = this.onForgotPassword;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canSignIn) ...[
          SignInButton(
            label: l10n.continueToSignIn,
            isSigningIn: isSigningIn || isSettling,
            waitingLabel: isSettling ? l10n.signInFinishingSignOut : null,
            onPressed: onContinue,
          ),
          const SizedBox(height: 4),
          if (registrationNeedsInvitation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                l10n.overviewRegistrationNeedsInvitation,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (onCreateAccount != null || onForgotPassword != null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (onCreateAccount != null)
                  TextButton(
                    onPressed: isSigningIn || isSettling
                        ? null
                        : onCreateAccount,
                    child: Text(
                      l10n.overviewCreateAccount,
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (onForgotPassword != null)
                  TextButton(
                    onPressed: isSigningIn ? null : onForgotPassword,
                    child: Text(
                      l10n.overviewForgotPassword,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          TextButton(
            onPressed: isSigningIn ? null : onUseDifferentServer,
            child: useDifferentServer,
          ),
        ] else
          FilledButton(
            onPressed: onUseDifferentServer,
            child: useDifferentServer,
          ),
      ],
    );
  }
}
