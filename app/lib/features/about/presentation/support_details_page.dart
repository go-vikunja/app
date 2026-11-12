import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/app_bar_text_action.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/common/presentation/screen_title.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/share_web_link.dart';

/// The support details as they would be shared, collected when the page
/// opens; they leave the device only through the share sheet. Server
/// addresses show only while the switch is on, which is off on every
/// opening.
class SupportDetailsPage extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SupportDetailsPage> createState() => _SupportDetailsPageState();
}

class _SupportDetailsPageState extends ConsumerState<SupportDetailsPage> {
  bool _showServers = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final snapshot = ref.watch(supportSnapshotProvider).value;
    final text = snapshot == null
        ? null
        : renderSupportDetails(
            snapshot,
            showServers: _showServers,
            appLanguage: Localizations.localeOf(context).languageCode,
          );

    return Scaffold(
      appBar: AppBar(
        title: ScreenTitle(l10n.supportDetailsTitle),
        actions: [
          // The button's own context anchors the share sheet on an iPad.
          Builder(
            builder: (button) => AppBarTextAction(
              onPressed: text == null
                  ? null
                  : () => unawaited(
                      shareText(
                        button,
                        ref,
                        text: text,
                        subject: l10n.supportDetailsTitle,
                      ),
                    ),
              child: Text(l10n.supportDetailsShare),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth.builder(
          maxWidth: ReadableWidth.form,
          builder: (_, _, inset) => ListView(
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 24),
            children: [
              SectionCard(
                children: [
                  SettingsNote(
                    icon: Icons.info_outline,
                    text: l10n.supportDetailsIntro,
                  ),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.dns_outlined),
                    title: Text(l10n.supportDetailsShowServers),
                    subtitle: Text(l10n.supportDetailsShowServersSubtitle),
                    value: _showServers,
                    onChanged: (value) => setState(() => _showServers = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (text == null)
                LoadingPlaceholder(label: l10n.supportDetailsTitle)
              else
                SectionCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        text.trimRight(),
                        style: theme.textTheme.bodySmall?.merge(
                          AppTheme.monospace,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
