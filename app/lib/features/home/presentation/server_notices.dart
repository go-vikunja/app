import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/demo_note.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/legal_links.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/motd_card.dart';

/// The demo mode, the message of the day and the legal links of the stored
/// `/info`, which the app reads again at each start and then at most every
/// few hours while it is in front.
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
          if (info.demoModeEnabled) const DemoNote(),
          if (motd.isNotEmpty) MotdCard(message: motd),
          if (hasLegal) LegalLinksRow(links: legal),
        ],
      ),
    );
  }
}
