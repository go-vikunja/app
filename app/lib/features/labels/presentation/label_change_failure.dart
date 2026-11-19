import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';

/// Why a change or delete of a label the server has failed; a create, and
/// a change of a label created here, are stored on the device and queued.
String labelChangeFailureText(AppLocalizations l10n, Object error) {
  final shared = actionFailureText(l10n, error);
  return switch (error) {
    // The server may have made the change before the answer was lost.
    NetworkFailure(problem: NetworkProblem.timeout) => l10n.labelsUnconfirmed,
    NetworkFailure() => l10n.labelsNeedsConnection,
    Forbidden() => l10n.labelsNotCreator,
    NotFound() => l10n.labelsGone,
    ValidationFailed() || VikunjaFailure(code: 2002) => l10n.labelsInvalid,
    _ when shared != null => shared,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.labelsRefused(message.trim()),
    _ => l10n.labelsFailed,
  };
}
