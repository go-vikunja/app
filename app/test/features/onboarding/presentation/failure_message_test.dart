import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';

import '../../../helpers/pump_app.dart';

void main() {
  final uri = Uri.parse('https://vikunja.example.com');
  final certificateFailure = TlsFailure(uri, certificateRejected: true);

  FailureMessage describe(
    TargetPlatform platform, {
    ServerConnectionFailure? failure,
  }) => FailureMessage.describe(
    en,
    failure: failure ?? certificateFailure,
    input: 'vikunja.example.com',
    platform: platform,
  );

  test('a TLS failure on iOS points to the certificate trust settings', () {
    expect(describe(TargetPlatform.iOS).suggestion, en.failureTlsSuggestionIos);
  });

  test('a TLS failure elsewhere only asks to install the certificate', () {
    expect(
      describe(TargetPlatform.android).suggestion,
      en.failureTlsSuggestion,
    );
  });

  test('a handshake failure without a rejected certificate is not blamed on '
      'the certificate', () {
    final message = describe(TargetPlatform.android, failure: TlsFailure(uri));

    expect(
      message.explanation,
      en.failureTlsHandshakeExplanation('vikunja.example.com'),
    );
    expect(message.suggestion, en.failureTlsHandshakeSuggestion);
  });
}
