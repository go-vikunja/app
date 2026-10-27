import 'package:flutter/foundation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

FailureMessage describeSignInFailure(
  AppLocalizations l10n,
  Object error, {
  required Uri serverRoot,
  required TargetPlatform platform,
}) {
  final host = displayHost(serverRoot);
  FailureMessage message(String title, String explanation, String suggestion) =>
      FailureMessage(
        title: title,
        explanation: explanation,
        suggestion: suggestion,
      );
  if (error case NetworkFailure(:final problem)) {
    final settings = connectionSettingsFailureMessage(
      l10n,
      problem,
      host: host,
    );
    if (settings != null) return settings;
  }
  return switch (error) {
    ServerConnectionFailure() => FailureMessage.describe(
      l10n,
      failure: error,
      input: serverRoot.toString(),
      platform: platform,
    ),
    NetworkFailure(problem: NetworkProblem.unreachable) => message(
      l10n.failureUnreachableTitle,
      l10n.failureUnreachableExplanation(host),
      l10n.failureUnreachableSuggestion,
    ),
    NetworkFailure(problem: NetworkProblem.timeout) => message(
      l10n.failureTimeoutTitle,
      l10n.failureTimeoutExplanation(host),
      l10n.failureTimeoutSuggestion,
    ),
    NetworkFailure(problem: NetworkProblem.tls) => message(
      l10n.failureTlsTitle,
      l10n.failureTlsExplanation(host),
      platform == TargetPlatform.iOS
          ? l10n.connectionTlsSuggestionIos
          : l10n.connectionTlsSuggestion,
    ),

    RateLimited(:final retryAfter) => message(
      l10n.signInRateLimitedTitle,
      l10n.signInRateLimitedExplanation(host),
      switch (retryAfter?.inSeconds) {
        null || <= 0 => l10n.signInRateLimitedSuggestion,
        final seconds when seconds < 90 =>
          l10n.signInRateLimitedSuggestionSeconds(seconds),
        final seconds => l10n.signInRateLimitedSuggestionMinutes(
          (seconds / 60).ceil(),
        ),
      },
    ),
    ServerFailure(:final statusCode) => message(
      l10n.failureUnavailableTitle,
      l10n.signInServerErrorExplanation(host, '$statusCode'),
      l10n.failureUnavailableSuggestion,
    ),
    OAuthFailure(
      problem: OAuthProblem.codeExpired || OAuthProblem.codeInvalid,
    ) =>
      message(
        l10n.signInExpiredTitle,
        l10n.signInExpiredExplanation,
        l10n.signInRetrySuggestion,
      ),
    OAuthFailure(:final code) => message(
      l10n.signInRejectedTitle,
      l10n.signInRejectedExplanation(host, '${code ?? '?'}'),
      l10n.signInRejectedSuggestion,
    ),
    SessionEnded(reason: SessionEndReason.accountDisabled) => message(
      l10n.signInAccountDisabledTitle,
      l10n.signInAccountDisabledExplanation(host),
      l10n.signInAccountBlockedSuggestion,
    ),
    SessionEnded(reason: SessionEndReason.accountLocked) => message(
      l10n.signInAccountLockedTitle,
      l10n.signInAccountLockedExplanation(host),
      l10n.signInAccountBlockedSuggestion,
    ),
    SessionEnded() || TokenRejected() || RefreshRaceLost() => message(
      l10n.signInRejectedTitle,
      l10n.signInSessionEndedExplanation(host),
      l10n.signInRetrySuggestion,
    ),
    NotFound(routeAbsent: true) => message(
      l10n.signInEndpointMissingTitle,
      l10n.signInEndpointMissingExplanation(host),
      l10n.signInEndpointMissingSuggestion,
    ),
    AuthorizationCallbackException(
      problem: AuthorizationCallbackProblem.stateMismatch,
    ) =>
      message(
        l10n.signInDiscardedTitle,
        l10n.signInDiscardedExplanation,
        l10n.signInRetrySuggestion,
      ),
    AuthorizationCallbackException() => message(
      l10n.signInIncompleteTitle,
      l10n.signInIncompleteExplanation,
      l10n.signInIncompleteSuggestion,
    ),
    SignedInAsDifferentUser(:final signedInUsername, :final expectedUsername) =>
      message(
        l10n.signInDifferentUserTitle,
        l10n.signInDifferentUserExplanation(signedInUsername, expectedUsername),
        l10n.signInDifferentUserSuggestion(expectedUsername, host),
      ),
    WebAuthenticationFailed(problem: WebAuthenticationProblem.noBrowser) =>
      message(
        l10n.signInNoBrowserTitle,
        l10n.signInNoBrowserExplanation,
        l10n.signInNoBrowserSuggestion,
      ),
    WebAuthenticationFailed() => message(
      l10n.signInBrowserFailedTitle,
      l10n.signInBrowserFailedExplanation,
      l10n.signInBrowserFailedSuggestion,
    ),
    _ => message(
      l10n.failureUnexpectedTitle,
      l10n.signInUnexpectedExplanation,
      l10n.failureUnexpectedSuggestion,
    ),
  };
}
