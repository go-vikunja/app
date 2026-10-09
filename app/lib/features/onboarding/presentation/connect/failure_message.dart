import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';

final class FailureMessage {
  const new({
    required this.title,
    required this.explanation,
    required this.suggestion,
  });

  factory describe(
    AppLocalizations l10n, {
    required ServerConnectionFailure? failure,
    required String input,
    required TargetPlatform platform,
  }) {
    final failedUri = failure?.uri;
    final host = failedUri == null || failedUri.host.isEmpty
        ? input.trim()
        : displayHost(failedUri);

    return switch (failure) {
      InvalidServerAddress(:final input) => FailureMessage(
        title: l10n.failureInvalidAddressTitle,
        explanation: l10n.failureInvalidAddressExplanation(input.trim()),
        suggestion: l10n.failureInvalidAddressSuggestion,
      ),
      ServerUnreachable() => FailureMessage(
        title: l10n.failureUnreachableTitle,
        explanation: l10n.failureUnreachableExplanation(host),
        suggestion: l10n.failureUnreachableSuggestion,
      ),
      ServerTimeout() => FailureMessage(
        title: l10n.failureTimeoutTitle,
        explanation: l10n.failureTimeoutExplanation(host),
        suggestion: l10n.failureTimeoutSuggestion,
      ),
      TlsFailure(certificateRejected: true) => FailureMessage(
        title: l10n.failureTlsTitle,
        explanation: l10n.failureTlsExplanation(host),
        suggestion: platform == TargetPlatform.iOS
            ? l10n.failureTlsSuggestionIos
            : l10n.failureTlsSuggestion,
      ),
      TlsFailure() => FailureMessage(
        title: l10n.failureTlsTitle,
        explanation: l10n.failureTlsHandshakeExplanation(host),
        suggestion: l10n.failureTlsHandshakeSuggestion,
      ),
      NotAVikunjaServer() => FailureMessage(
        title: l10n.failureNotVikunjaTitle,
        explanation: l10n.failureNotVikunjaExplanation(host),
        suggestion: l10n.failureNotVikunjaSuggestion,
      ),
      ServerUnavailable() => FailureMessage(
        title: l10n.failureUnavailableTitle,
        explanation: l10n.failureUnavailableExplanation(host),
        suggestion: l10n.failureUnavailableSuggestion,
      ),
      BehindLoginProxy() => FailureMessage(
        title: l10n.failureLoginProxyTitle,
        explanation: l10n.failureLoginProxyExplanation(host),
        suggestion: l10n.failureLoginProxySuggestion,
      ),
      null => FailureMessage(
        title: l10n.failureUnexpectedTitle,
        explanation: l10n.failureUnexpectedExplanation,
        suggestion: l10n.failureUnexpectedSuggestion,
      ),
    };
  }

  final String title;
  final String explanation;
  final String suggestion;
}
