import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/l10n/licence_page_localizations.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/legal.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';

/// The app's legal notices (AGPL section 5(d)): its version and copyright,
/// that it is unofficial and not the Vikunja project's, the licence with the
/// app store permission and no warranty, the licence page, where the source
/// code is, and the name and logo, which the licence does not cover; and
/// Rurana's privacy policy and legal notice. Open signed out and to guests.
class AboutPage extends ConsumerWidget {
  const new({this.sourceCode = sourceCodeUrl, super.key});

  final String? sourceCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (:version, :build) = ref.watch(appVersionProvider);
    final versionText = build.isEmpty
        ? l10n.aboutVersionWithoutBuild(version)
        : l10n.aboutVersion(version, build);
    final sourceCode = this.sourceCode;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: ScreenTitle(l10n.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ReadableWidth.builder(
          maxWidth: ReadableWidth.form,
          builder: (_, _, inset) => ListView(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
            children: [
              _Header(version: versionText),
              SectionCard(
                title: l10n.aboutWebsiteHeading,
                children: [
                  for (final (page, icon, title, subtitle) in [
                    (
                      WebsitePage.privacy,
                      Icons.privacy_tip_outlined,
                      l10n.aboutPrivacyPolicy,
                      l10n.aboutPrivacyPolicySubtitle,
                    ),
                    (
                      WebsitePage.legalNotice,
                      Icons.contact_mail_outlined,
                      l10n.aboutLegalNotice,
                      l10n.aboutLegalNoticeSubtitle,
                    ),
                  ])
                    ListTile(
                      leading: Icon(icon),
                      title: Text(title),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => unawaited(
                        _open(
                          context,
                          ref,
                          page.uri(languageCode: languageCode),
                        ),
                      ),
                    ),
                ],
              ),
              SectionCard(
                title: l10n.aboutLicenceHeading,
                children: [
                  SettingsNote(
                    icon: Icons.balance_outlined,
                    text: l10n.aboutLicence,
                  ),
                  SettingsNote(
                    icon: Icons.info_outline,
                    text: l10n.aboutNoWarranty,
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.aboutLicences),
                    subtitle: Text(l10n.aboutLicencesSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLicences(context, versionText),
                  ),
                ],
              ),
              SectionCard(
                title: l10n.aboutSourceCodeHeading,
                children: [
                  if (sourceCode == null)
                    SettingsNote(
                      icon: Icons.code,
                      text: l10n.aboutSourceCodeLater,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: Text(l10n.aboutSourceCodeOpen),
                      subtitle: Text(sourceCode),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () =>
                          unawaited(_open(context, ref, Uri.parse(sourceCode))),
                    ),
                ],
              ),
              SectionCard(
                title: l10n.aboutNameAndLogoHeading,
                children: [
                  SettingsNote(
                    icon: Icons.copyright_outlined,
                    text: l10n.aboutNameAndLogo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Flutter's `showLicensePage` with the page's English in British
  /// spelling.
  void _showLicences(BuildContext context, String version) {
    final navigator = Navigator.of(context);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final appTitle = context.l10n.appTitle;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => themes.wrap(
          Localizations.override(
            context: context,
            delegates: const [licencePageLocalizations],
            child: LicensePage(
              applicationName: appTitle,
              applicationVersion: version,
              applicationIcon: const _Logo(),
              applicationLegalese: copyrightNotice,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Uri address) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.legalOpenFailed;
    final opened = await ref.read(externalLinkOpenerProvider).open(address);
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

class _Header extends StatelessWidget {
  const new({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          const _Logo(),
          const SizedBox(height: 12),
          Text(
            context.l10n.appTitle,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            version,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            copyrightNotice,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.aboutUnofficial,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Image.asset(
    ConnectHeader.logoAsset,
    width: 64,
    height: 64,
    excludeFromSemantics: true,
  );
}
