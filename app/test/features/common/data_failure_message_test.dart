import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';

import '../../helpers/pump_app.dart';

void main() {
  final root = Uri.parse('https://tasks.example.org');
  const host = 'tasks.example.org';

  String explanationOf(Object error) => describeDataFailure(
    en,
    error,
    serverRoot: root,
    platform: TargetPlatform.android,
    stale: true,
  ).explanation;

  test('secure storage that refused to read is not told as an outage', () {
    const failure = NetworkFailure(
      NetworkProblem.unreachable,
      cause: SecureStorageUnreadable(PlatformException),
    );

    final message = describeDataFailure(
      en,
      failure,
      serverRoot: root,
      platform: TargetPlatform.android,
      stale: false,
    );

    expect(message.explanation, en.failureSignInUnreadableExplanation(host));
    expect(message.suggestion, en.failureSignInUnreadableSuggestion);
  });

  test('a renewal another part of the app had on its way is not told as a '
      'server that did not answer', () {
    const failure = NetworkFailure(
      NetworkProblem.timeout,
      cause: RefreshDeferred.race,
    );

    final message = describeDataFailure(
      en,
      failure,
      serverRoot: root,
      platform: TargetPlatform.android,
      stale: false,
    );

    expect(message.explanation, en.failureRenewalDeferredExplanation(host));
    expect(message.suggestion, en.failureRenewalDeferredSuggestion);
  });

  test('other network failures keep their texts', () {
    expect(
      explanationOf(const NetworkFailure(NetworkProblem.unreachable)),
      en.failureUnreachableExplanation(host),
    );
    expect(
      explanationOf(const NetworkFailure(NetworkProblem.timeout)),
      en.failureTimeoutExplanation(host),
    );
  });
}
