import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_dialog_action.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_providers.dart';

final _log = Logger('CrashReports');

final _asking = Expando<bool>('crash report question');

/// The one question about crash reports: in a build with a DSN, the first time
/// an account of any kind reaches the shell, until it is answered
/// (decision log: Diagnostics). Allow allows, No thanks and going back decline;
/// from then on only the privacy page's switch changes it. Closed by the app (a
/// notification or widget tap closes every dialog), it is not answered and
/// comes again at the shell's next start.
Future<void> askAboutCrashReportsOnce(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(crashReportsDsnProvider) == null) return;
  // The shell may be gone once the answer comes; the container stays.
  final container = ProviderScope.containerOf(context, listen: false);
  if (_asking[container] ?? false) return;
  _asking[container] = true;
  try {
    final consent = await container.read(
      crashReportConsentControllerProvider.future,
    );
    if (consent != CrashReportConsent.notAsked || !context.mounted) return;
    final allowed = await showCrashReportsQuestion(context);
    if (allowed == null) return;
    await container
        .read(crashReportConsentControllerProvider.notifier)
        .set(
          allowed ? CrashReportConsent.allowed : CrashReportConsent.declined,
        );
  } on Object catch (error) {
    _log.warning(
      'Could not store the crash report choice: ${error.runtimeType}',
    );
  } finally {
    _asking[container] = false;
  }
}

/// True for Allow, false for No thanks and for going back, null when the
/// app closed it. Neither answer is the default.
Future<bool?> showCrashReportsQuestion(BuildContext context) {
  final l10n = context.l10n;
  return showAdaptiveDialog<bool>(
    context: context,
    // Not by a stray tap.
    barrierDismissible: false,
    builder: (context) => PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: AlertDialog.adaptive(
        scrollable: true,
        title: Text(l10n.crashReportsQuestionTitle),
        content: Text(l10n.crashReportsQuestionBody),
        actions: [
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.crashReportsQuestionDecline),
          ),
          AdaptiveDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.crashReportsQuestionAllow),
          ),
        ],
      ),
    ),
  );
}
