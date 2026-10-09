import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/file_size_format.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/widgets/section_heading.dart';

class ServerFeaturesSection extends StatelessWidget {
  const new({required this.connection, super.key});

  final ServerConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = _enabledFeatures(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.featuresHeading),
        if (features.isEmpty)
          Text(l10n.featuresNone)
        else
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final (icon, label) in features)
                    _FeatureRow(icon: icon, label: label),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<(IconData, String)> _enabledFeatures(AppLocalizations l10n) {
    final capabilities = connection.capabilities;
    bool has(Capability capability) => capabilities.has(capability);

    return [
      if (has(Capability.taskAttachments))
        (Icons.attach_file, _attachmentsLabel(l10n)),
      if (has(Capability.taskComments))
        (Icons.chat_bubble_outline, l10n.featureComments),
      if (has(Capability.linkSharing)) (Icons.link, l10n.featureLinkSharing),
      if (has(Capability.totp))
        (Icons.verified_user_outlined, l10n.featureTotp),
      if (has(Capability.caldav))
        (Icons.calendar_month_outlined, l10n.featureCaldav),
      if (has(Capability.webhooks)) (Icons.webhook, l10n.featureWebhooks),
      if (has(Capability.emailReminders))
        (Icons.mark_email_unread_outlined, l10n.featureEmailReminders),
      if (has(Capability.registration))
        (Icons.person_add_alt_1_outlined, l10n.featureRegistration),
      if (has(Capability.publicTeams))
        (Icons.groups_outlined, l10n.featurePublicTeams),
      if (has(Capability.userDeletion))
        (Icons.person_remove_outlined, l10n.featureUserDeletion),
      if (has(Capability.backgroundUpload) ||
          has(Capability.backgroundUnsplash))
        (Icons.wallpaper_outlined, l10n.featureBackgrounds),
    ];
  }

  String _attachmentsLabel(AppLocalizations l10n) {
    if (connection.info.maxFileSizeBytes case final bytes?) {
      return l10n.featureAttachmentsWithLimit(
        formatFileSize(bytes, l10n.localeName),
      );
    }
    final configured = connection.info.maxFileSize.trim();
    return configured.isEmpty
        ? l10n.featureAttachments
        : l10n.featureAttachmentsWithLimit(configured);
  }
}

class _FeatureRow extends StatelessWidget {
  const new({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
