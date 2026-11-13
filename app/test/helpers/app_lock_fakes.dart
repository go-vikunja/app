import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

/// The system prompt: answers [result] at once, or waits for [finish]
/// while [holdPrompts] is on. Every prompt is in [promptTexts], its reason
/// in [reasons].
final class FakeDeviceAuthenticator implements DeviceAuthenticator {
  new({this.supported = true, this.result = DeviceAuthResult.success});

  bool supported;
  DeviceAuthResult result;
  bool holdPrompts = false;
  final List<DeviceAuthPrompt> promptTexts = [];
  Completer<DeviceAuthResult>? _held;

  List<String> get reasons => [for (final prompt in promptTexts) prompt.reason];
  int get prompts => promptTexts.length;
  bool get prompting => _held != null;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<DeviceAuthResult> authenticate(DeviceAuthPrompt prompt) {
    promptTexts.add(prompt);
    if (!holdPrompts) return Future.value(result);
    final held = _held = Completer<DeviceAuthResult>();
    return held.future;
  }

  /// Answers the held prompt with [answer], else [result].
  void finish([DeviceAuthResult? answer]) {
    final held = _held;
    if (held == null) throw StateError('No prompt is held');
    _held = null;
    held.complete(answer ?? result);
  }
}

/// [enabled] as last set; every call in [calls]. [applies] says whether
/// the system takes it (Android 13+).
final class FakeRecentsScreenshots implements RecentsScreenshots {
  new({this.applies = true});

  final bool applies;
  bool? enabled;
  final List<bool> calls = [];

  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add(enabled);
    this.enabled = enabled;
    return applies;
  }
}

/// [secure] as last set; every call in [changes].
/// Android's window by default; with `capturable` iOS's, which shows in
/// captures and tells whether the screen is captured: [setSecure] answers
/// [captured], and [setCaptured] reports a change.
final class FakeSecureWindow implements SecureWindow {
  new({bool capturable = false})
    : _captures = capturable ? StreamController<bool>.broadcast() : null;

  bool secure = false;
  bool captured = false;
  final List<bool> changes = [];
  final StreamController<bool>? _captures;

  @override
  Stream<bool>? get captures => _captures?.stream;

  @override
  Future<bool> setSecure(bool secure) async {
    changes.add(secure);
    this.secure = secure;
    return _captures != null && captured;
  }

  // Like setSecure.
  // ignore: avoid_positional_boolean_parameters
  void setCaptured(bool captured) {
    this.captured = captured;
    _captures!.add(captured);
  }
}

Future<void> storePrivacySettings(
  PreferencesStore preferences,
  PrivacySettings settings,
) => preferences.setString(
  PrivacySettingsStore.key,
  jsonEncode(settings.toJson()),
);

/// The test binding starts without a lifecycle state, and the app lock
/// prompts on its own only while the app is resumed.
void useResumedLifecycle(WidgetTester tester) =>
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

/// Far enough for the app lock's own prompt, which waits until the app has
/// stayed in front a moment, and for the frame that shows its answer.
Future<void> pumpPastPromptSettle(WidgetTester tester) async {
  await tester.pump(AppLockController.promptSettle);
  await tester.pump();
}

/// A prompt as the app words it, with [reason].
DeviceAuthPrompt promptFor(String reason) => DeviceAuthPrompt(
  title: 'Vikunja',
  hint: 'Use your fingerprint, face or screen lock',
  cancel: 'Cancel',
  reason: reason,
);
