import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/privacy/presentation/lock_after_texts.dart';

/// The Account tab's way to the privacy page, which belongs to this device
/// whichever account is active; in a build with crash reports its subtitle
/// says whether they are on.
class PrivacySection extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings =
        ref.watch(privacySettingsProvider).value ?? const PrivacySettings();
    final appLock = appLockSummary(l10n, settings);
    final subtitle = ref.watch(crashReportsDsnProvider) == null
        ? appLock
        : l10n.privacyEntryWithCrashReports(
            appLock,
            ref.watch(crashReportConsentControllerProvider).value ==
                    CrashReportConsent.allowed
                ? 'on'
                : 'off',
          );
    return SettingsSection(
      title: l10n.privacyTitle,
      trailing: const OnThisDeviceMark(),
      children: [
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.privacyEntryTitle),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(GoRouter.of(context).push(AppRoutes.privacy)),
        ),
      ],
    );
  }
}
