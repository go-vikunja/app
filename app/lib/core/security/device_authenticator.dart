import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'device_authenticator.g.dart';

final _log = Logger('DeviceAuth');

enum DeviceAuthResult {
  success,

  /// By the user, the system or a timeout; trying again may work.
  cancelled,

  /// The device has neither a screen lock nor biometrics.
  noCredentials,

  /// Too many failed attempts.
  lockedOut,

  /// An earlier prompt that never answered still holds the system's
  /// prompt; closing the app completely releases it.
  inProgress,
  unavailable,
}

/// What the system prompt says: Android shows [title], [hint] (60
/// characters at most each) and [reason], iOS only [reason]. [cancel]
/// labels Android's button for leaving a prompt without the screen lock.
@immutable
final class DeviceAuthPrompt {
  const new({
    required this.title,
    required this.hint,
    required this.cancel,
    required this.reason,
  });

  /// The app's texts, with [reason] saying what the prompt is for.
  factory forReason(AppLocalizations l10n, String reason) => DeviceAuthPrompt(
    title: l10n.appTitle,
    hint: l10n.appLockPromptHint,
    cancel: l10n.cancel,
    reason: reason,
  );

  final String title;
  final String hint;
  final String cancel;
  final String reason;
}

/// The device's own screen lock or biometrics, as the system prompts for
/// them.
abstract interface class DeviceAuthenticator {
  /// Whether the device has a screen lock or biometrics to prompt for.
  Future<bool> isSupported();

  /// Never throws.
  Future<DeviceAuthResult> authenticate(DeviceAuthPrompt prompt);
}

final class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  new([LocalAuthentication? localAuth])
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on Object catch (error) {
      _log.warning('Could not ask for a screen lock: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(DeviceAuthPrompt prompt) async {
    try {
      // biometricOnly and persistAcrossBackgrounding stay at their false
      // defaults: the screen lock must remain a way in (biometrics lock
      // out), and the app lock prompts again on its own return.
      final authenticated = await _localAuth.authenticate(
        localizedReason: prompt.reason,
        // iOS needs none: it shows the reason and the system's own button
        // titles.
        authMessages: [
          AndroidAuthMessages(
            signInTitle: prompt.title,
            signInHint: prompt.hint,
            cancelButton: prompt.cancel,
          ),
        ],
        sensitiveTransaction: false,
      );
      // iOS answers a failed or app-cancelled attempt with false.
      return authenticated
          ? DeviceAuthResult.success
          : DeviceAuthResult.cancelled;
    } on LocalAuthException catch (error) {
      return deviceAuthResultOf(error.code);
    } on Object catch (error) {
      _log.warning('Authentication failed: ${error.runtimeType}');
      return DeviceAuthResult.unavailable;
    }
  }
}

DeviceAuthResult deviceAuthResultOf(LocalAuthExceptionCode code) {
  switch (code) {
    case LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout:
      return DeviceAuthResult.cancelled;
    case LocalAuthExceptionCode.noCredentialsSet:
      return DeviceAuthResult.noCredentials;
    case LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout:
      return DeviceAuthResult.lockedOut;
    case LocalAuthExceptionCode.authInProgress:
      return DeviceAuthResult.inProgress;
    case _:
      // The description can carry platform details; the code is enough.
      _log.warning('Authentication unavailable: ${code.name}');
      return DeviceAuthResult.unavailable;
  }
}

@Riverpod(keepAlive: true)
DeviceAuthenticator deviceAuthenticator(Ref ref) =>
    LocalAuthDeviceAuthenticator();

/// Asked again whenever the app comes back to the front, because the user
/// sets up a screen lock in the system settings.
@riverpod
class DeviceAuthSupported extends _$DeviceAuthSupported {
  @override
  Future<bool> build() {
    final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
    ref.onDispose(lifecycle.dispose);
    return ref.watch(deviceAuthenticatorProvider).isSupported();
  }
}
