import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/legal_links.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/motd_card.dart';

/// The demo mode, the message of the day and the legal links the server
/// reported at sign-in; not refreshed while signed in (D60).
class ServerNotices extends StatelessWidget {
  const new({required this.info, super.key});

  final ServerInfo info;

  @override
  Widget build(BuildContext context) {
    final motd = info.motd.trim();
    final legal = info.legal;
    final hasLegal = LegalLinksRow.hasAny(legal);
    if (!info.demoModeEnabled && motd.isEmpty && !hasLegal) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (info.demoModeEnabled) const _DemoNote(),
          if (motd.isNotEmpty) MotdCard(message: motd),
          if (hasLegal) LegalLinksRow(links: legal),
        ],
      ),
    );
  }
}

class _DemoNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          container: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.science_outlined,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.overviewDemoNote,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
