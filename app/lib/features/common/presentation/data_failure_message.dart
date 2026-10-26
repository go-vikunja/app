import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

/// Explains a failed read. [stale] is true when older data stays on screen.
/// A [guest] opens its link again instead of signing in.
FailureMessage describeDataFailure(
  AppLocalizations l10n,
  Object error, {
  required Uri serverRoot,
  required TargetPlatform platform,
  required bool stale,
  bool guest = false,
}) {
  final host = displayHost(serverRoot);
  final title = stale
      ? l10n.dataFailureRefreshTitle
      : l10n.dataFailureLoadTitle;
  final staleNote = stale ? l10n.dataFailureStaleNote : null;
  FailureMessage message(String explanation, String? suggestion) =>
      FailureMessage(
        title: title,
        explanation: explanation,
        suggestion: [?suggestion, ?staleNote].join(' '),
      );
  return switch (error) {
    NetworkFailure(problem: NetworkProblem.unreachable) => message(
      l10n.failureUnreachableExplanation(host),
      l10n.failureUnreachableSuggestion,
    ),
    NetworkFailure(problem: NetworkProblem.timeout) => message(
      l10n.failureTimeoutExplanation(host),
      l10n.failureTimeoutSuggestion,
    ),
    NetworkFailure(problem: NetworkProblem.tls) => message(
      l10n.failureTlsExplanation(host),
      platform == TargetPlatform.iOS
          ? l10n.failureTlsSuggestionIos
          : l10n.failureTlsSuggestion,
    ),
    SessionEnded() || TokenRejected() || RefreshRaceLost() => message(
      guest
          ? l10n.guestDataFailureAccessEnded(host)
          : l10n.dataFailureSessionEnded(host),
      null,
    ),
    Forbidden() => message(l10n.dataFailureForbidden(host), null),
    NotFound() => message(l10n.dataFailureNotFound(host), null),
    RateLimited() => message(
      l10n.dataFailureRateLimited(host),
      l10n.signInRateLimitedSuggestion,
    ),
    ServerFailure() => message(
      l10n.failureUnavailableExplanation(host),
      l10n.failureUnavailableSuggestion,
    ),
    _ => message(
      l10n.dataFailureUnexpected(host),
      l10n.failureUnexpectedSuggestion,
    ),
  };
}
