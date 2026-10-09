import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';

class LegalLinksRow extends ConsumerWidget {
  const new({required this.links, super.key});

  final LegalLinks links;

  static bool hasAny(LegalLinks links) =>
      isWebLink(links.imprintUrl) || isWebLink(links.privacyPolicyUrl);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final imprint = links.imprintUrl;
    final privacy = links.privacyPolicyUrl;

    Future<void> open(Uri uri) async {
      final opened = await ref.read(externalLinkOpenerProvider).open(uri);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.legalOpenFailed)));
      }
    }

    return Wrap(
      spacing: 8,
      children: [
        if (imprint != null && isWebLink(imprint))
          TextButton.icon(
            onPressed: () => open(imprint),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.legalImprint),
          ),
        if (privacy != null && isWebLink(privacy))
          TextButton.icon(
            onPressed: () => open(privacy),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.legalPrivacy),
          ),
      ],
    );
  }
}
