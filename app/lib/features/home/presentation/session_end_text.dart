import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// Why the session ended, with the server's code when it gave one.
String describeSessionEndCause(
  AppLocalizations l10n,
  SessionEndDiagnosis diagnosis, {
  required DateTime now,
}) {
  final cause = switch (diagnosis.cause) {
    SessionEndCause.refreshRejected => switch (diagnosis.lostRefreshAt) {
      final lost? when _mayHaveLostAnswer(diagnosis.resolution) =>
        isJustNow(lost, now: now)
            ? l10n.sessionEndCauseLostAnswerJustNow
            : l10n.sessionEndCauseLostAnswer(
                formatRelativeTime(l10n, lost, now: now),
              ),
      _ => l10n.sessionEndCauseRefreshRejected,
    },
    SessionEndCause.sessionExpired => l10n.sessionEndCauseExpired,
    SessionEndCause.accountDisabled => l10n.sessionEndCauseDisabled,
    SessionEndCause.accountLocked => l10n.sessionEndCauseLocked,
    SessionEndCause.missingTokens => l10n.sessionEndCauseMissingTokens,
    SessionEndCause.storageUnreadable => l10n.sessionEndCauseStorageUnreadable,
    SessionEndCause.shareGone => l10n.sessionEndCauseShareGone,
    SessionEndCause.sharePasswordNeeded => l10n.sessionEndCauseSharePassword,
  };
  final code = diagnosis.code;
  return code == null ? cause : '$cause ${l10n.sessionEndCode(code)}';
}

/// A deletion on the server explains the refusal better, and a session
/// that still worked or works again lost no answer.
bool _mayHaveLostAnswer(SessionEndResolution? resolution) =>
    switch (resolution) {
      SessionEndResolution.goneOnServer ||
      SessionEndResolution.wasAlive ||
      SessionEndResolution.restored => false,
      SessionEndResolution.orphanRevoked ||
      SessionEndResolution.noTokens ||
      SessionEndResolution.unknown ||
      null => true,
    };

/// What became of the ended session, when that tells something.
String? describeSessionEndResolution(
  AppLocalizations l10n,
  SessionEndResolution? resolution,
) => switch (resolution) {
  SessionEndResolution.orphanRevoked => l10n.sessionEndResolvedOrphan,
  SessionEndResolution.goneOnServer => l10n.sessionEndResolvedGone,
  SessionEndResolution.wasAlive => l10n.sessionEndResolvedAlive,
  SessionEndResolution.restored => l10n.sessionEndResolvedRestored,
  SessionEndResolution.noTokens || SessionEndResolution.unknown || null => null,
};
