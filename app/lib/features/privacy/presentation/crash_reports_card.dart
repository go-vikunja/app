import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';

final _log = Logger('CrashReports');

/// The privacy page's switch for crash reports (D113), only in a build
/// with a DSN. It takes effect at once: off closes the SDK and deletes
/// the reports not sent yet, on starts it without a restart.
class CrashReportsCard extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CrashReportsCard> createState() => _CrashReportsCardState();
}

class _CrashReportsCardState extends ConsumerState<CrashReportsCard> {
  var _saveFailed = false;

  Future<void> _set({required bool allowed}) async {
    setState(() => _saveFailed = false);
    try {
      await ref
          .read(crashReportConsentControllerProvider.notifier)
          .set(
            allowed ? CrashReportConsent.allowed : CrashReportConsent.declined,
          );
    } on Object catch (error) {
      _log.warning(
        'Could not store the crash report choice: ${error.runtimeType}',
      );
      if (!mounted) return;
      setState(() => _saveFailed = true);
      announce(context, context.l10n.privacySaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(crashReportsDsnProvider) == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final consent = ref.watch(crashReportConsentControllerProvider).value;
    return SectionCard(
      title: l10n.privacyCrashReportsHeading,
      children: [
        SettingSwitch(
          icon: Icons.bug_report_outlined,
          title: l10n.privacyCrashReportsSwitch,
          subtitle: l10n.privacyCrashReportsSubtitle,
          value: consent == CrashReportConsent.allowed,
          error: _saveFailed ? l10n.privacySaveFailed : null,
          onChanged: consent == null
              ? null
              : (value) => unawaited(_set(allowed: value)),
        ),
        SettingsNote(
          icon: Icons.info_outline,
          text: l10n.privacyCrashReportsNote,
        ),
      ],
    );
  }
}
