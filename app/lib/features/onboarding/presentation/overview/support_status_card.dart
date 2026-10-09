import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/widgets/status_card.dart';

class SupportStatusCard extends StatelessWidget {
  const new({required this.connection, super.key});

  final ServerConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final minimum = ServerCapabilities.minimumSupportedVersion.display;
    return switch (connection.capabilities.tier) {
      SupportTier.unsupported => switch (connection.info.version) {
        final version? => StatusCard(
          icon: Icons.block,
          title: l10n.unsupportedTitle,
          body: l10n.unsupportedBody(minimum, version.display),
          footnote: l10n.unsupportedSuggestion,
          background: colors.errorContainer,
          foreground: colors.onErrorContainer,
        ),
        null => StatusCard(
          icon: Icons.help_outline,
          title: l10n.unsupportedUnknownVersionTitle,
          body: l10n.unsupportedUnknownVersionBody(minimum),
          footnote: l10n.unsupportedUnknownVersionSuggestion,
          background: colors.errorContainer,
          foreground: colors.onErrorContainer,
        ),
      },
      SupportTier.oauth => StatusCard(
        icon: Icons.check_circle_outline,
        title: l10n.tierOauthTitle,
        body: connection.apiV2Missing
            ? l10n.tierOauthV2UnreachableBody
            : l10n.tierOauthBody,
        background: colors.surfaceContainerHigh,
        foreground: colors.onSurface,
      ),
      SupportTier.full => StatusCard(
        icon: Icons.verified_outlined,
        title: l10n.tierFullTitle,
        body: l10n.tierFullBody,
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      ),
    };
  }
}
