import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

class LegalLinksRow extends ConsumerWidget {
  const new({required this.links, super.key});

  final LegalLinks links;

  /// The server's legal links with a web address and a text, in its order.
  static List<LegalLink> shownOf(LegalLinks links) => [
    for (final link in links.links)
      if (isWebLink(link.url) && link.text.trim().isNotEmpty) link,
  ];

  static bool hasAny(LegalLinks links) => shownOf(links).isNotEmpty;

  /// The imprint and the privacy policy in the app's words, as the web
  /// translates them; any other link with its admin's text, untranslated.
  static String labelOf(AppLocalizations l10n, LegalLink link) =>
      switch (link.text) {
        LegalLink.imprintText => l10n.legalImprint,
        LegalLink.privacyPolicyText => l10n.legalPrivacy,
        _ => link.text,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    Future<void> open(Uri uri) async {
      final opened = await ref.read(externalLinkOpenerProvider).open(uri);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.legalOpenFailed)));
      }
    }

    // The server keeps "Imprint" and an admin's "Impressum" at one address
    // apart; in German both read „Impressum“, and one button is enough.
    final buttons = <(String, Uri)>{
      for (final link in shownOf(links)) (labelOf(l10n, link), link.url),
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final (label, url) in buttons)
          TextButton.icon(
            onPressed: () => open(url),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(label),
          ),
      ],
    );
  }
}
