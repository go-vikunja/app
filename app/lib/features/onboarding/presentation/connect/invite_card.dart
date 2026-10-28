import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// A registration invite an admin sent: what it gives as far as the server
/// could tell, opening it in the browser to register, and the sign-in
/// after that, which the browser cannot hand back to the app.
class InviteCard extends StatelessWidget {
  const new({
    required this.serverRoot,
    required this.check,
    required this.onCreateAccount,
    required this.onContinue,
    this.preview,
    super.key,
  });

  final Uri serverRoot;
  final InviteCheck check;

  /// Null unless [check] is [InviteCheck.passed].
  final InvitePreview? preview;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSecondaryContainer,
    );
    final preview = this.preview;
    final name = preview?.name.trim() ?? '';
    final teams = [
      for (final team in preview?.teams ?? const <InviteTeam>[])
        if (team.name.trim().isNotEmpty) team.name.trim(),
    ];
    final lines = [
      if (name.isNotEmpty) name,
      if (teams.isNotEmpty) l10n.inviteTeams(teams.join(', ')),
      switch ((check, preview?.skipsEmailConfirmation)) {
        (InviteCheck.passed, true) => l10n.inviteNoEmailConfirmation,
        (InviteCheck.passed, _) => l10n.inviteEmailConfirmation,
        (InviteCheck.unavailable, _) => l10n.inviteUnchecked,
        (InviteCheck.failed, _) => l10n.inviteCheckFailed,
      },
      l10n.inviteSteps,
    ];
    return Card.filled(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.how_to_reg_outlined,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          headingLevel: 2,
                          child: Text(
                            l10n.inviteHeading(displayHost(serverRoot)),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        for (final line in lines) ...[
                          const SizedBox(height: 6),
                          Text(line, style: textStyle),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.open_in_new),
              label: Text(
                l10n.inviteCreateAccount,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onContinue,
              child: Text(l10n.continueToSignIn, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}
