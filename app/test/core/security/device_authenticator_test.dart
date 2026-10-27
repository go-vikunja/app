import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';

import '../../helpers/app_lock_fakes.dart';

void main() {
  testWidgets('whether a screen lock is set is asked again on every '
      'resume', (tester) async {
    final authenticator = FakeDeviceAuthenticator(supported: false);
    final container = ProviderContainer(
      overrides: [deviceAuthenticatorProvider.overrideWithValue(authenticator)],
    );
    addTearDown(container.dispose);
    container.listen(deviceAuthSupportedProvider, (_, _) {});
    expect(await container.read(deviceAuthSupportedProvider.future), isFalse);

    authenticator.supported = true;
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(Duration.zero);

    expect(await container.read(deviceAuthSupportedProvider.future), isTrue);
  });

  test('asks for biometrics or the screen lock without a second '
      'confirmation', () async {
    final localAuth = _FakeLocalAuth(answer: () async => true);

    final result = await LocalAuthDeviceAuthenticator(localAuth)
        .authenticate(promptFor('Unlock Rurana'));

    expect(result, DeviceAuthResult.success);
    expect(localAuth.reason, 'Unlock Rurana');
    expect(localAuth.biometricOnly, isFalse);
    expect(localAuth.sensitiveTransaction, isFalse);
    expect(localAuth.persistAcrossBackgrounding, isFalse);
  });

  test("gives Android's prompt the app's title, hint and cancel button "
      'besides the reason', () async {
    final localAuth = _FakeLocalAuth(answer: () async => true);

    await LocalAuthDeviceAuthenticator(localAuth).authenticate(
      const DeviceAuthPrompt(
        title: 'Rurana',
        hint: 'Nutze Fingerabdruck, Gesicht oder Displaysperre',
        cancel: 'Abbrechen',
        reason: 'Rurana entsperren',
      ),
    );

    final android = localAuth.authMessages!
        .whereType<AndroidAuthMessages>()
        .single;
    expect(android.signInTitle, 'Rurana');
    expect(
      android.signInHint,
      'Nutze Fingerabdruck, Gesicht oder Displaysperre',
    );
    expect(android.cancelButton, 'Abbrechen');
    expect(localAuth.reason, 'Rurana entsperren');
  });

  test('a failed attempt reported as false counts as cancelled', () async {
    final result = await LocalAuthDeviceAuthenticator(
      _FakeLocalAuth(answer: () async => false),
    ).authenticate(promptFor('Unlock Rurana'));

    expect(result, DeviceAuthResult.cancelled);
  });

  for (final (code, expected) in [
    (LocalAuthExceptionCode.userCanceled, DeviceAuthResult.cancelled),
    (LocalAuthExceptionCode.systemCanceled, DeviceAuthResult.cancelled),
    (LocalAuthExceptionCode.timeout, DeviceAuthResult.cancelled),
    (LocalAuthExceptionCode.noCredentialsSet, DeviceAuthResult.noCredentials),
    (LocalAuthExceptionCode.temporaryLockout, DeviceAuthResult.lockedOut),
    (LocalAuthExceptionCode.biometricLockout, DeviceAuthResult.lockedOut),
    (LocalAuthExceptionCode.uiUnavailable, DeviceAuthResult.unavailable),
    (LocalAuthExceptionCode.authInProgress, DeviceAuthResult.inProgress),
    (
      LocalAuthExceptionCode.userRequestedFallback,
      DeviceAuthResult.unavailable,
    ),
    (LocalAuthExceptionCode.noBiometricsEnrolled, DeviceAuthResult.unavailable),
    (LocalAuthExceptionCode.deviceError, DeviceAuthResult.unavailable),
    (LocalAuthExceptionCode.unknownError, DeviceAuthResult.unavailable),
  ]) {
    test('${code.name} maps to ${expected.name}', () async {
      final result = await LocalAuthDeviceAuthenticator(
        _FakeLocalAuth(
          answer: () async => throw LocalAuthException(code: code),
        ),
      ).authenticate(promptFor('Unlock Rurana'));

      expect(result, expected);
    });
  }

  test('any other error is unavailable', () async {
    final result = await LocalAuthDeviceAuthenticator(
      _FakeLocalAuth(answer: () async => throw MissingPluginException()),
    ).authenticate(promptFor('Unlock Rurana'));

    expect(result, DeviceAuthResult.unavailable);
  });

  test('supported is what the plugin says, and false when it fails', () async {
    expect(
      await LocalAuthDeviceAuthenticator(
        _FakeLocalAuth(supported: () async => true),
      ).isSupported(),
      isTrue,
    );
    expect(
      await LocalAuthDeviceAuthenticator(
        _FakeLocalAuth(supported: () async => throw MissingPluginException()),
      ).isSupported(),
      isFalse,
    );
  });
}

final class _FakeLocalAuth extends Fake implements LocalAuthentication {
  new({Future<bool> Function()? answer, this.supported})
    : answer = answer ?? (() async => true);

  final Future<bool> Function() answer;
  final Future<bool> Function()? supported;
  String? reason;
  Iterable<Object?>? authMessages;
  bool? biometricOnly;
  bool? sensitiveTransaction;
  bool? persistAcrossBackgrounding;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) {
    reason = localizedReason;
    this.authMessages = authMessages;
    this.biometricOnly = biometricOnly;
    this.sensitiveTransaction = sensitiveTransaction;
    this.persistAcrossBackgrounding = persistAcrossBackgrounding;
    return answer();
  }

  @override
  Future<bool> isDeviceSupported() => supported!();
}
