import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_message.dart';
import 'package:vikunja_mobile/features/connection/application/connection_fix.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';

import '../../helpers/pump_app.dart';

void main() {
  final root = Uri.parse('https://vikunja.example.com');
  const host = 'vikunja.example.com';

  FailureMessage connect(
    ServerConnectionFailure failure, {
    bool? hasClientCertificate,
    bool pinned = false,
  }) => FailureMessage.describe(
    en,
    failure: failure,
    input: host,
    platform: TargetPlatform.android,
    hasClientCertificate: hasClientCertificate,
    pinned: pinned,
  );

  group('on the connect screen', () {
    test('a client-certificate failure is worded by what is stored', () {
      final failure = TlsFailure(root, clientCertificateRefused: true);

      expect(
        connect(failure).explanation,
        en.connectionClientCertificateFailureExplanation(host),
      );
      expect(
        connect(failure, hasClientCertificate: false).explanation,
        en.connectionClientCertificateNeededExplanation(host),
      );
      final refused = connect(failure, hasClientCertificate: true);
      expect(
        refused.explanation,
        en.connectionClientCertificateRefusedExplanation(host),
      );
      expect(
        refused.suggestion,
        en.connectionClientCertificateRefusedSuggestion,
      );
    });

    test('a rejected certificate of a pinned origin is a changed one', () {
      final message = connect(
        TlsFailure(root, certificateRejected: true),
        pinned: true,
      );

      expect(message.explanation, en.connectionPinMismatchExplanation(host));
      expect(message.suggestion, en.connectionPinMismatchSuggestion);
    });

    test('each connection-settings problem has its own text', () {
      String explanation(ConnectionSettingsProblem problem) =>
          connect(ConnectionSettingsFailure(root, problem: problem))
              .explanation;

      expect(
        explanation(ConnectionSettingsProblem.cleartextBlocked),
        en.connectionCleartextBlockedExplanation(host),
      );
      expect(
        explanation(ConnectionSettingsProblem.locked),
        en.connectionProfileLockedExplanation(host),
      );
      expect(
        explanation(ConnectionSettingsProblem.incomplete),
        en.connectionProfileIncompleteExplanation(host),
      );
      expect(
        explanation(ConnectionSettingsProblem.damaged),
        en.connectionProfileDamagedExplanation,
      );
    });

    test('a login proxy no longer calls headers planned', () {
      final message = connect(BehindLoginProxy(root));

      expect(message.suggestion, en.connectionLoginProxySuggestion);
      expect(message.suggestion, isNot(contains('planned')));
    });
  });

  group('after sign-in and for data', () {
    const problems = {
      NetworkProblem.clientCertificate: 'clientCertificate',
      NetworkProblem.cleartextBlocked: 'cleartextBlocked',
      NetworkProblem.profileLocked: 'profileLocked',
      NetworkProblem.profileIncomplete: 'profileIncomplete',
      NetworkProblem.profileDamaged: 'profileDamaged',
    };

    String expectedExplanation(NetworkProblem problem) => switch (problem) {
      NetworkProblem.clientCertificate =>
        en.connectionClientCertificateFailureExplanation(host),
      NetworkProblem.cleartextBlocked =>
        en.connectionCleartextBlockedExplanation(host),
      NetworkProblem.profileLocked => en.connectionProfileLockedExplanation(
        host,
      ),
      NetworkProblem.profileIncomplete =>
        en.connectionProfileIncompleteExplanation(host),
      NetworkProblem.profileDamaged => en.connectionProfileDamagedExplanation,
      _ => throw ArgumentError(problem),
    };

    for (final MapEntry(key: problem, value: name) in problems.entries) {
      test('$name explains itself, never as offline', () {
        final failure = NetworkFailure(problem);

        expect(
          describeSignInFailure(
            en,
            failure,
            serverRoot: root,
            platform: TargetPlatform.android,
          ).explanation,
          expectedExplanation(problem),
        );
        expect(
          describeDataFailure(
            en,
            failure,
            serverRoot: root,
            platform: TargetPlatform.android,
            stale: true,
          ).explanation,
          expectedExplanation(problem),
        );
        expect(
          offlineAfter(
            null,
            SyncFailed(failure: failure, lastSyncedAt: DateTime.utc(2026)),
          ),
          isNull,
        );
      });
    }

    test('an unreachable server is still offline', () {
      expect(
        offlineAfter(
          null,
          SyncFailed(
            failure: const NetworkFailure(NetworkProblem.unreachable),
            lastSyncedAt: DateTime.utc(2026),
          ),
        ),
        isNotNull,
      );
    });

    test('a TLS failure points to the connection settings', () {
      final message = describeDataFailure(
        en,
        const NetworkFailure(NetworkProblem.tls),
        serverRoot: root,
        platform: TargetPlatform.iOS,
        stale: false,
      );

      expect(message.suggestion, en.connectionTlsSuggestionIos);
    });
  });

  group('the fixes', () {
    test('on the connect screen, by failure', () {
      expect(
        connectionFixFor(TlsFailure(root, certificateRejected: true)),
        ConnectionFix.viewCertificate,
      );
      expect(
        connectionFixFor(TlsFailure(root, clientCertificateRefused: true)),
        ConnectionFix.clientCertificate,
      );
      expect(
        connectionFixFor(BehindLoginProxy(root)),
        ConnectionFix.addHeaders,
      );
      expect(
        connectionFixFor(NotAVikunjaServer(root, statusCode: 401)),
        ConnectionFix.addHeaders,
      );
      expect(
        connectionFixFor(NotAVikunjaServer(root, statusCode: 404)),
        isNull,
      );
      expect(connectionFixFor(TlsFailure(root)), isNull);
      expect(
        connectionFixFor(const NetworkFailure(NetworkProblem.tls)),
        ConnectionFix.viewCertificate,
      );
      expect(
        connectionFixFor(const NetworkFailure(NetworkProblem.unreachable)),
        isNull,
      );
    });

    test('elsewhere: the settings, or for damaged ones the reset', () {
      expect(
        opensConnectionSettings(const NetworkFailure(NetworkProblem.tls)),
        isTrue,
      );
      expect(
        opensConnectionSettings(
          const NetworkFailure(NetworkProblem.profileLocked),
        ),
        isTrue,
      );
      expect(
        opensConnectionSettings(
          const NetworkFailure(NetworkProblem.profileDamaged),
        ),
        isFalse,
      );
      expect(
        needsConnectionSettingsReset(
          const NetworkFailure(NetworkProblem.profileDamaged),
        ),
        isTrue,
      );
      expect(
        opensConnectionSettings(
          const NetworkFailure(NetworkProblem.unreachable),
        ),
        isFalse,
      );
    });
  });
}
