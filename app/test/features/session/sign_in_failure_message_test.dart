import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/browser_sign_in.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  final root = Uri.parse('https://vikunja.example.com:8443/sub');

  FailureMessage describe(
    Object error, {
    TargetPlatform platform = TargetPlatform.android,
  }) => describeSignInFailure(en, error, serverRoot: root, platform: platform);

  test('maps each failure to its own message', () {
    final cases = <Object, (String, String, String)>{
      const NetworkFailure(NetworkProblem.unreachable): (
        en.failureUnreachableTitle,
        en.failureUnreachableExplanation('vikunja.example.com:8443'),
        en.failureUnreachableSuggestion,
      ),
      const NetworkFailure(NetworkProblem.timeout): (
        en.failureTimeoutTitle,
        en.failureTimeoutExplanation('vikunja.example.com:8443'),
        en.failureTimeoutSuggestion,
      ),
      const OAuthFailure(OAuthProblem.codeExpired, code: 17005): (
        en.signInExpiredTitle,
        en.signInExpiredExplanation,
        en.signInRetrySuggestion,
      ),
      const OAuthFailure(OAuthProblem.pkceMismatch, code: 17006): (
        en.signInRejectedTitle,
        en.signInRejectedExplanation('vikunja.example.com:8443', '17006'),
        en.signInRejectedSuggestion,
      ),
      const SessionEnded(SessionEndReason.accountDisabled): (
        en.signInAccountDisabledTitle,
        en.signInAccountDisabledExplanation('vikunja.example.com:8443'),
        en.signInAccountBlockedSuggestion,
      ),
      const SessionEnded(SessionEndReason.accountLocked): (
        en.signInAccountLockedTitle,
        en.signInAccountLockedExplanation('vikunja.example.com:8443'),
        en.signInAccountBlockedSuggestion,
      ),
      const SessionEnded(SessionEndReason.invalidRefreshToken): (
        en.signInRejectedTitle,
        en.signInSessionEndedExplanation('vikunja.example.com:8443'),
        en.signInRetrySuggestion,
      ),
      const SignedInAsDifferentUser(
        signedInUsername: 'bob',
        expectedUsername: 'alice',
      ): (
        en.signInDifferentUserTitle,
        en.signInDifferentUserExplanation('bob', 'alice'),
        en.signInDifferentUserSuggestion('alice', 'vikunja.example.com:8443'),
      ),
      const ServerFailure(502): (
        en.failureUnavailableTitle,
        en.signInServerErrorExplanation('vikunja.example.com:8443', '502'),
        en.failureUnavailableSuggestion,
      ),
      const NotFound(): (
        en.signInEndpointMissingTitle,
        en.signInEndpointMissingExplanation('vikunja.example.com:8443'),
        en.signInEndpointMissingSuggestion,
      ),
      const AuthorizationCallbackException(
        AuthorizationCallbackProblem.stateMismatch,
      ): (
        en.signInDiscardedTitle,
        en.signInDiscardedExplanation,
        en.signInRetrySuggestion,
      ),
      const AuthorizationCallbackException(
        AuthorizationCallbackProblem.missingCode,
      ): (
        en.signInIncompleteTitle,
        en.signInIncompleteExplanation,
        en.signInIncompleteSuggestion,
      ),
      const WebAuthenticationFailed(WebAuthenticationProblem.noBrowser): (
        en.signInNoBrowserTitle,
        en.signInNoBrowserExplanation,
        en.signInNoBrowserSuggestion,
      ),
      const WebAuthenticationFailed(WebAuthenticationProblem.failed): (
        en.signInBrowserFailedTitle,
        en.signInBrowserFailedExplanation,
        en.signInBrowserFailedSuggestion,
      ),
      StateError('bug'): (
        en.failureUnexpectedTitle,
        en.signInUnexpectedExplanation,
        en.failureUnexpectedSuggestion,
      ),
    };

    for (final MapEntry(key: error, value: (title, explanation, suggestion))
        in cases.entries) {
      final message = describe(error);
      expect(message.title, title, reason: '$error');
      expect(message.explanation, explanation, reason: '$error');
      expect(message.suggestion, suggestion, reason: '$error');
    }
  });

  test('says how long to wait after too many attempts', () {
    expect(
      describe(const RateLimited(retryAfter: Duration(seconds: 30))).suggestion,
      en.signInRateLimitedSuggestionSeconds(30),
    );
    expect(
      describe(const RateLimited(retryAfter: Duration(seconds: 150)))
          .suggestion,
      en.signInRateLimitedSuggestionMinutes(3),
    );
    expect(
      describe(const RateLimited()).suggestion,
      en.signInRateLimitedSuggestion,
    );
  });

  test('a connection failure while negotiating reads like on connect', () {
    final failure = ServerUnreachable(root);

    final message = describe(failure);

    expect(message.title, en.failureUnreachableTitle);
  });

  test('on iOS a TLS failure explains certificate trust', () {
    final message = describe(
      const NetworkFailure(NetworkProblem.tls),
      platform: TargetPlatform.iOS,
    );

    expect(message.suggestion, en.connectionTlsSuggestionIos);
  });

  test('every message exists in German', () {
    for (final error in [
      const RateLimited(retryAfter: Duration(minutes: 2)),
      const OAuthFailure(OAuthProblem.clientMismatch),
      const WebAuthenticationFailed(WebAuthenticationProblem.noBrowser),
      const SignedInAsDifferentUser(
        signedInUsername: 'bob',
        expectedUsername: 'alice',
      ),
    ]) {
      final german = describeSignInFailure(
        de,
        error,
        serverRoot: root,
        platform: TargetPlatform.android,
      );
      final english = describe(error);
      expect(german.title, isNot(english.title));
      expect(german.explanation, isNot(english.explanation));
    }
  });
}
