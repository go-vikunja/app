import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';

NetworkProblem networkProblemOfSettings(ConnectionSettingsProblem problem) =>
    switch (problem) {
      ConnectionSettingsProblem.cleartextBlocked =>
        NetworkProblem.cleartextBlocked,
      ConnectionSettingsProblem.locked => NetworkProblem.profileLocked,
      ConnectionSettingsProblem.incomplete => NetworkProblem.profileIncomplete,
      ConnectionSettingsProblem.damaged => NetworkProblem.profileDamaged,
    };

/// The texts of a failure only the connection settings can fix; null for
/// the others. [hasClientCertificate] is known only where the profile is,
/// and words a client-certificate failure as missing or refused.
FailureMessage? connectionSettingsFailureMessage(
  AppLocalizations l10n,
  NetworkProblem problem, {
  required String host,
  bool? hasClientCertificate,
}) => switch (problem) {
  NetworkProblem.unreachable ||
  NetworkProblem.timeout ||
  NetworkProblem.tls => null,
  NetworkProblem.clientCertificate => FailureMessage(
    title: l10n.connectionClientCertificateFailureTitle,
    explanation: switch (hasClientCertificate) {
      null => l10n.connectionClientCertificateFailureExplanation(host),
      false => l10n.connectionClientCertificateNeededExplanation(host),
      true => l10n.connectionClientCertificateRefusedExplanation(host),
    },
    suggestion: hasClientCertificate ?? false
        ? l10n.connectionClientCertificateRefusedSuggestion
        : l10n.connectionClientCertificateFailureSuggestion,
  ),
  NetworkProblem.cleartextBlocked => FailureMessage(
    title: l10n.connectionCleartextBlockedTitle,
    explanation: l10n.connectionCleartextBlockedExplanation(host),
    suggestion: l10n.connectionCleartextBlockedSuggestion,
  ),
  NetworkProblem.profileLocked => FailureMessage(
    title: l10n.connectionProfileLockedTitle,
    explanation: l10n.connectionProfileLockedExplanation(host),
    suggestion: l10n.connectionProfileLockedSuggestion,
  ),
  NetworkProblem.profileIncomplete => FailureMessage(
    title: l10n.connectionProfileIncompleteTitle,
    explanation: l10n.connectionProfileIncompleteExplanation(host),
    suggestion: l10n.connectionProfileIncompleteSuggestion,
  ),
  NetworkProblem.profileDamaged => FailureMessage(
    title: l10n.connectionProfileDamagedTitle,
    explanation: l10n.connectionProfileDamagedExplanation,
    suggestion: l10n.connectionProfileDamagedSuggestion,
  ),
};
