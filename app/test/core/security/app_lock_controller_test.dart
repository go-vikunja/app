import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/platform/recents_screenshots.dart';
import 'package:vikunja_mobile/core/platform/secure_display.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';
import 'package:vikunja_mobile/core/security/screen_protection.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';

const _locked = PrivacySettings(appLock: true);
const _immediately = PrivacySettings(
  appLock: true,
  lockAfter: LockAfter.immediately,
);

void main() {
  late MemoryPreferencesStore preferences;
  late FakeDeviceAuthenticator auth;
  late DateTime now;

  setUp(() {
    preferences = MemoryPreferencesStore();
    auth = FakeDeviceAuthenticator();
    now = DateTime.utc(2026, 10, 27, 9);
  });

  /// The containers of the running test, disposed at the end of the test
  /// itself: the binding wants the lock's timers gone before tear-downs
  /// run.
  final containers = <ProviderContainer>[];

  void track(ProviderContainer container) {
    containers.add(container);
    addTearDown(container.dispose);
  }

  void testLock(String description, WidgetTesterCallback body) =>
      testWidgets(description, (tester) async {
        try {
          await body(tester);
        } finally {
          for (final container in containers) {
            container.dispose();
          }
          containers.clear();
        }
      });

  void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
      states.forEach(tester.binding.handleAppLifecycleStateChanged);

  void leave(WidgetTester tester) => lifecycle(tester, const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]);

  void comeBack(WidgetTester tester) => lifecycle(tester, const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]);

  /// As bootstrap does it: the settings first, then the controller.
  Future<ProviderContainer> start(
    WidgetTester tester, {
    PrivacySettings? settings,
    PreferencesStore? store,
    bool awaitSettings = true,
  }) async {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    if (settings != null) await storePrivacySettings(preferences, settings);
    final container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store ?? preferences),
        clockProvider.overrideWithValue(() => now),
        deviceAuthenticatorProvider.overrideWithValue(auth),
      ],
    );
    track(container);
    if (awaitSettings) {
      await container.read(privacySettingsControllerProvider.future);
    }
    container.listen(appLockControllerProvider, (_, _) {});
    return container;
  }

  /// Started with [settings] and unlocked through the automatic prompt;
  /// later prompts are cancelled unless a test says otherwise.
  Future<ProviderContainer> startUnlocked(
    WidgetTester tester, [
    PrivacySettings settings = _locked,
  ]) async {
    final container = await start(tester, settings: settings);
    await pumpPastPromptSettle(tester);
    expect(container.read(appLockControllerProvider).locked, isFalse);
    auth.result = DeviceAuthResult.cancelled;
    return container;
  }

  AppLockState lockOf(ProviderContainer container) =>
      container.read(appLockControllerProvider);

  AppLockController controllerOf(ProviderContainer container) =>
      container.read(appLockControllerProvider.notifier);

  group('a cold start', () {
    testLock('is locked while the lock is on', (tester) async {
      auth.result = DeviceAuthResult.cancelled;

      final container = await start(tester, settings: _locked);

      expect(lockOf(container).enabled, isTrue);
      expect(lockOf(container).locked, isTrue);
    });

    testLock('is open while the lock is off', (tester) async {
      final container = await start(tester);

      expect(lockOf(container), const AppLockState());
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 0);
    });

    testLock('is locked when the settings cannot be read', (tester) async {
      auth.result = DeviceAuthResult.cancelled;
      preferences.values[PrivacySettingsStore.key] = '{"version": 7}';

      final container = await start(tester);

      expect(lockOf(container).enabled, isTrue);
      expect(lockOf(container).locked, isTrue);
      expect(preferences.values[PrivacySettingsStore.key], '{"version": 7}');
    });

    testLock('prompts once after the first frame and opens on '
        'success', (tester) async {
      final container = await start(tester, settings: _locked);
      expect(auth.prompts, 0);

      await pumpPastPromptSettle(tester);

      expect(auth.reasons, [en.appLockPromptReason]);
      expect(lockOf(container).locked, isFalse);
    });

    testLock('waits for the resume to prompt', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final container = ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(() => now),
          deviceAuthenticatorProvider.overrideWithValue(auth),
        ],
      );
      track(container);
      await storePrivacySettings(preferences, _locked);
      await container.read(privacySettingsControllerProvider.future);
      container.listen(appLockControllerProvider, (_, _) {});

      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpPastPromptSettle(tester);

      expect(auth.prompts, 1);
      expect(lockOf(container).locked, isFalse);
    });

    testLock('before the settings are read is locked, and opens when '
        'they say the lock is off', (tester) async {
      final slow = _SlowPreferences(preferences);

      final container = await start(tester, store: slow, awaitSettings: false);
      expect(lockOf(container).locked, isTrue);
      expect(controllerOf(container).isLockedNow(), isTrue);

      slow.release();
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isFalse);
      expect(lockOf(container).enabled, isFalse);
      expect(auth.prompts, 0);
    });

    testLock('before the settings are read stays locked and prompts when '
        'they say the lock is on', (tester) async {
      auth.result = DeviceAuthResult.cancelled;
      await storePrivacySettings(preferences, _locked);
      final slow = _SlowPreferences(preferences);

      final container = await start(tester, store: slow, awaitSettings: false);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 0);

      slow.release();
      await pumpPastPromptSettle(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isTrue);
      expect(auth.prompts, 1);
    });
  });

  group('after leaving the app', () {
    testLock('a return within the time stays open', (tester) async {
      final container = await startUnlocked(tester);

      leave(tester);
      now = now.add(const Duration(seconds: 59));
      comeBack(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isFalse);
      expect(auth.prompts, 1);
    });

    testLock('a return after the time is locked and prompts once', (
      tester,
    ) async {
      final container = await startUnlocked(tester);

      leave(tester);
      now = now.add(const Duration(minutes: 1));
      comeBack(tester);

      expect(lockOf(container).locked, isTrue);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 2);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 2);
    });

    testLock('locks on the show, before the resume', (tester) async {
      final container = await startUnlocked(tester);

      leave(tester);
      now = now.add(const Duration(minutes: 5));
      lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]);

      expect(lockOf(container).locked, isTrue);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 1, reason: 'no prompt before the resume');
    });

    testLock('a clock moved back locks', (tester) async {
      final container = await startUnlocked(tester);

      leave(tester);
      now = now.subtract(const Duration(seconds: 5));
      comeBack(tester);

      expect(lockOf(container).locked, isTrue);
    });

    testLock('the longer choices wait their time', (tester) async {
      final container = await startUnlocked(
        tester,
        const PrivacySettings(appLock: true, lockAfter: LockAfter.oneHour),
      );

      leave(tester);
      now = now.add(const Duration(minutes: 59));
      comeBack(tester);
      expect(lockOf(container).locked, isFalse);

      leave(tester);
      now = now.add(const Duration(hours: 1));
      comeBack(tester);
      expect(lockOf(container).locked, isTrue);
    });

    testLock('immediately locks as the app is hidden', (tester) async {
      final container = await startUnlocked(tester, _immediately);

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);

      expect(lockOf(container).locked, isTrue);
    });

    testLock('a locked app prompts again on every return', (tester) async {
      auth.result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 1);

      leave(tester);
      comeBack(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isTrue);
      expect(auth.prompts, 2);
    });

    testLock('the lock off never locks', (tester) async {
      final container = await start(tester);

      leave(tester);
      now = now.add(const Duration(days: 1));
      comeBack(tester);

      expect(lockOf(container).locked, isFalse);
      expect(lockOf(container).covered, isFalse);
    });
  });

  group('isLockedNow', () {
    testLock('evaluates the time out of sight before the show event', (
      tester,
    ) async {
      final container = await startUnlocked(tester);
      leave(tester);

      now = now.add(const Duration(seconds: 30));
      expect(controllerOf(container).isLockedNow(), isFalse);

      now = now.add(const Duration(seconds: 30));
      expect(controllerOf(container).isLockedNow(), isTrue);
      expect(lockOf(container).locked, isTrue);
    });

    testLock('is false while open and in sight', (tester) async {
      final container = await startUnlocked(tester);
      now = now.add(const Duration(hours: 2));

      expect(controllerOf(container).isLockedNow(), isFalse);
    });
  });

  group('the privacy cover', () {
    testLock('covers while inactive and comes off on the return', (
      tester,
    ) async {
      final container = await startUnlocked(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(lockOf(container).covered, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(lockOf(container).covered, isFalse);
    });

    testLock('comes off on the show after the lock decision', (tester) async {
      final container = await startUnlocked(tester);
      final states = <AppLockState>[];
      container.listen(
        appLockControllerProvider,
        (_, next) => states.add(next),
      );

      leave(tester);
      now = now.add(const Duration(minutes: 2));
      lifecycle(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]);

      expect(states.map((state) => (state.locked, state.covered)), [
        (false, true),
        (true, true),
        (true, false),
      ]);
    });

    testLock('is not used while the lock is off', (tester) async {
      final container = await start(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).covered, isFalse);
    });

    testLock('is not used while the prompt is up', (tester) async {
      final container = await startUnlocked(tester);
      auth.holdPrompts = true;
      unawaited(
        controllerOf(container)
            .setAppLock(enabled: false, prompt: promptFor('off')),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).authenticating, isTrue);
      expect(lockOf(container).covered, isFalse);
      auth.finish(DeviceAuthResult.cancelled);
    });

    testLock('is not used during an excursion', (tester) async {
      final container = await startUnlocked(tester);
      final picker = Completer<void>();
      unawaited(controllerOf(container).excursion(() => picker.future));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).covered, isFalse);
      picker.complete();
    });

    testLock('is used again once an excursion outlasts ten minutes', (
      tester,
    ) async {
      final container = await startUnlocked(
        tester,
        const PrivacySettings(appLock: true, lockAfter: LockAfter.oneHour),
      );
      final stuck = Completer<void>();
      unawaited(controllerOf(container).excursion(() => stuck.future));

      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).covered, isTrue);
      stuck.complete();
    });
  });

  group('while the prompt is up', () {
    testLock('leaving and returning neither locks nor covers; a cancel '
        'then counts the time out of sight, without a prompt', (tester) async {
      final container = await startUnlocked(tester, _immediately);
      auth.holdPrompts = true;
      final turningOff = controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));

      leave(tester);
      now = now.add(const Duration(minutes: 3));
      comeBack(tester);
      expect(lockOf(container).locked, isFalse);
      expect(lockOf(container).covered, isFalse);

      auth.finish(DeviceAuthResult.cancelled);
      expect(await turningOff, DeviceAuthResult.cancelled);
      expect(lockOf(container).locked, isTrue);
      expect(lockOf(container).enabled, isTrue);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 2, reason: 'no prompt after the cancel');
    });

    testLock('with a minute, a cancel that answers after the return '
        'locks only after a longer absence', (tester) async {
      final container = await startUnlocked(tester);
      auth.holdPrompts = true;

      var turningOff = controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));
      leave(tester);
      now = now.add(const Duration(seconds: 30));
      comeBack(tester);
      auth.finish(DeviceAuthResult.cancelled);
      await turningOff;
      expect(lockOf(container).locked, isFalse);

      turningOff = controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));
      leave(tester);
      now = now.add(const Duration(hours: 1));
      comeBack(tester);
      auth.finish(DeviceAuthResult.cancelled);
      await turningOff;
      expect(lockOf(container).locked, isTrue);
    });

    testLock('a cancel that answers out of sight counts from the first '
        'hide', (tester) async {
      final container = await startUnlocked(tester);
      auth.holdPrompts = true;
      final turningOff = controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));

      leave(tester);
      now = now.add(const Duration(seconds: 50));
      auth.finish(DeviceAuthResult.cancelled);
      await turningOff;
      expect(lockOf(container).locked, isFalse);

      now = now.add(const Duration(seconds: 20));
      comeBack(tester);
      expect(lockOf(container).locked, isTrue);
    });

    testLock('a success on the PIN screen that answers before the return '
        'does not lock again', (tester) async {
      auth.holdPrompts = true;
      final container = await start(tester, settings: _immediately);
      await pumpPastPromptSettle(tester);
      expect(auth.prompting, isTrue);

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);
      auth.finish(DeviceAuthResult.success);
      await pumpPastPromptSettle(tester);
      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isFalse);
      expect(auth.prompts, 1);
    });

    testLock('a success that answers after the return stays open', (
      tester,
    ) async {
      auth.holdPrompts = true;
      final container = await start(tester, settings: _immediately);
      await pumpPastPromptSettle(tester);

      leave(tester);
      comeBack(tester);
      auth.finish(DeviceAuthResult.success);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isFalse);
      expect(auth.prompts, 1);
    });

    testLock('a cancelled prompt does not bring itself back', (tester) async {
      auth
        ..holdPrompts = true
        ..result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);

      // Face ID: inactive and back; the PIN screen: hidden and back.
      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      leave(tester);
      comeBack(tester);
      auth.finish();
      await pumpPastPromptSettle(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isTrue);
      expect(auth.prompts, 1);
    });

    testLock('a prompt cancelled while the app is hidden does not '
        'prompt on a return right after', (tester) async {
      auth
        ..holdPrompts = true
        ..result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);

      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);
      auth.finish();
      await pumpPastPromptSettle(tester);
      now = now.add(const Duration(seconds: 2));
      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isTrue);
      expect(auth.prompts, 1);

      leave(tester);
      comeBack(tester);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 2, reason: 'a later return prompts again');
    });

    testLock('a prompt cancelled while the app is hidden prompts on a '
        'later return', (tester) async {
      auth
        ..holdPrompts = true
        ..result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);

      // Home during the prompt: the system cancels it.
      leave(tester);
      auth.finish();
      await pumpPastPromptSettle(tester);
      now = now.add(const Duration(hours: 3));
      comeBack(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isTrue);
      expect(auth.prompts, 2);
      auth.finish();
    });

    testLock('a second unlock does not prompt twice', (tester) async {
      auth
        ..holdPrompts = true
        ..result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);

      await controllerOf(container).unlock().timeout(Duration.zero);

      expect(auth.prompts, 1);
      auth.finish();
    });
  });

  group('a prompt that never answers', () {
    Future<ProviderContainer> startPrompting(WidgetTester tester) async {
      auth.holdPrompts = true;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);
      expect(auth.prompting, isTrue);
      return container;
    }

    testLock('is given up once the app has been back a while after '
        'leaving, and its late answer is ignored', (tester) async {
      final container = await startPrompting(tester);

      leave(tester);
      comeBack(tester);
      await tester.pump(
        AppLockController.answerGrace - const Duration(milliseconds: 1),
      );
      expect(lockOf(container).authenticating, isTrue);

      await tester.pump(const Duration(milliseconds: 1));
      expect(lockOf(container).authenticating, isFalse);
      expect(lockOf(container).locked, isTrue);
      expect(lockOf(container).error, isNull);

      auth.finish(DeviceAuthResult.success);
      await tester.pump();
      expect(lockOf(container).locked, isTrue);

      auth
        ..holdPrompts = false
        ..result = DeviceAuthResult.success;
      await controllerOf(container).unlock();
      expect(lockOf(container).locked, isFalse);
    });

    testLock('still counts when it answers just after the return', (
      tester,
    ) async {
      final container = await startPrompting(tester);

      leave(tester);
      comeBack(tester);
      await tester.pump(const Duration(seconds: 1));
      auth.finish(DeviceAuthResult.success);
      await tester.pump();

      expect(lockOf(container).locked, isFalse);
    });

    testLock('is not given up while the app stays in front', (tester) async {
      final container = await startPrompting(tester);

      // Face ID makes the app inactive only.
      lifecycle(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump(const Duration(minutes: 1));

      expect(lockOf(container).authenticating, isTrue);
      auth.finish(DeviceAuthResult.cancelled);
    });

    testLock('one the system still holds asks to restart the app', (
      tester,
    ) async {
      auth.result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);
      auth.result = DeviceAuthResult.inProgress;

      await controllerOf(container).unlock();

      expect(lockOf(container).locked, isTrue);
      expect(lockOf(container).error, AppLockError.promptStuck);
    });
  });

  group('the automatic prompt', () {
    testLock('waits until the app has stayed in front a moment', (
      tester,
    ) async {
      await start(tester, settings: _locked);

      await tester.pump(
        AppLockController.promptSettle - const Duration(milliseconds: 1),
      );
      expect(auth.prompts, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(auth.prompts, 1);
    });

    testLock('waits for the next resume when the app left meanwhile', (
      tester,
    ) async {
      auth.result = DeviceAuthResult.cancelled;
      await start(tester, settings: _locked);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 1);
    });

    testLock('names the app, the ways in and the reason', (tester) async {
      await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);

      final prompt = auth.promptTexts.single;
      expect(prompt.title, en.appTitle);
      expect(prompt.hint, en.appLockPromptHint);
      expect(prompt.cancel, en.cancel);
      expect(prompt.reason, en.appLockPromptReason);
    });
  });

  group('excursions', () {
    testLock('leaving for a picker does not lock', (tester) async {
      final container = await startUnlocked(tester, _immediately);
      final picker = Completer<String>();

      final picked = controllerOf(container).excursion(() => picker.future);
      leave(tester);
      now = now.add(const Duration(minutes: 5));
      comeBack(tester);
      picker.complete('photo.jpg');

      expect(await picked, 'photo.jpg');
      expect(lockOf(container).locked, isFalse);
      await pumpPastPromptSettle(tester);
      expect(auth.prompts, 1);
    });

    testLock('one longer than ten minutes counts from its start', (
      tester,
    ) async {
      final container = await startUnlocked(tester);
      final picker = Completer<void>();

      unawaited(controllerOf(container).excursion(() => picker.future));
      leave(tester);
      now = now.add(const Duration(minutes: 10));
      comeBack(tester);

      expect(lockOf(container).locked, isTrue);
      picker.complete();
    });

    testLock('one longer than ten minutes still waits for a longer lock '
        'time', (tester) async {
      final container = await startUnlocked(
        tester,
        const PrivacySettings(
          appLock: true,
          lockAfter: LockAfter.fifteenMinutes,
        ),
      );
      final picker = Completer<void>();

      unawaited(controllerOf(container).excursion(() => picker.future));
      leave(tester);
      now = now.add(const Duration(minutes: 12));
      comeBack(tester);

      expect(lockOf(container).locked, isFalse);
      picker.complete();
    });

    testLock('nested and overlapping ones protect until the last ends', (
      tester,
    ) async {
      final container = await startUnlocked(tester, _immediately);
      final controller = controllerOf(container);
      final share = Completer<void>();
      final camera = Completer<void>();

      final outer = controller.excursion(
        () => controller.excursion(() => share.future),
      );
      final overlapping = controller.excursion(() => camera.future);
      share.complete();
      await outer;
      leave(tester);
      comeBack(tester);
      expect(lockOf(container).locked, isFalse);

      camera.complete();
      await overlapping;
      leave(tester);

      expect(lockOf(container).locked, isTrue);
    });

    testLock('one that ends while the app is hidden counts as a hide from '
        'then on', (tester) async {
      final container = await startUnlocked(tester);
      final share = Completer<void>();

      final shared = controllerOf(container).excursion(() => share.future);
      leave(tester);
      now = now.add(const Duration(minutes: 3));
      share.complete();
      await shared;
      expect(lockOf(container).locked, isFalse);

      now = now.add(const Duration(seconds: 59));
      comeBack(tester);
      expect(lockOf(container).locked, isFalse);

      leave(tester);
      final again = Completer<void>();
      final sharedAgain = controllerOf(container).excursion(() => again.future);
      now = now.add(const Duration(minutes: 1));
      again.complete();
      await sharedAgain;
      now = now.add(const Duration(minutes: 1));
      comeBack(tester);
      expect(lockOf(container).locked, isTrue);
    });

    testLock('one that ends hidden with immediately locks at once', (
      tester,
    ) async {
      final container = await startUnlocked(tester, _immediately);
      final browser = Completer<void>();

      final signIn = controllerOf(container).excursion(() => browser.future);
      leave(tester);
      expect(lockOf(container).locked, isFalse);
      browser.complete();
      await signIn;

      expect(lockOf(container).locked, isTrue);
      expect(controllerOf(container).isLockedNow(), isTrue);
    });
  });

  group('unlocking', () {
    Future<ProviderContainer> startLocked(WidgetTester tester) async {
      auth.result = DeviceAuthResult.cancelled;
      final container = await start(tester, settings: _locked);
      await pumpPastPromptSettle(tester);
      return container;
    }

    testLock('a cancelled prompt stays locked without an error', (
      tester,
    ) async {
      final container = await startLocked(tester);

      expect(lockOf(container).locked, isTrue);
      expect(lockOf(container).error, isNull);
      expect(lockOf(container).authenticating, isFalse);
    });

    testLock('success opens the app', (tester) async {
      final container = await startLocked(tester);
      auth.result = DeviceAuthResult.success;

      await controllerOf(container).unlock();

      expect(lockOf(container).locked, isFalse);
      expect(auth.reasons.last, en.appLockPromptReason);
    });

    for (final (result, error) in [
      (DeviceAuthResult.lockedOut, AppLockError.lockedOut),
      (DeviceAuthResult.unavailable, AppLockError.unavailable),
    ]) {
      testLock('${result.name} stays locked with an error', (tester) async {
        final container = await startLocked(tester);
        auth.result = result;

        await controllerOf(container).unlock();

        expect(lockOf(container).locked, isTrue);
        expect(lockOf(container).error, error);

        auth.result = DeviceAuthResult.success;
        await controllerOf(container).unlock();
        expect(lockOf(container).error, isNull);
      });
    }

    testLock('a device without a screen lock turns the lock off, opens '
        'and tells', (tester) async {
      final container = await startLocked(tester);
      auth.result = DeviceAuthResult.noCredentials;

      await controllerOf(container).unlock();

      expect(lockOf(container).locked, isFalse);
      expect(lockOf(container).enabled, isFalse);
      expect(
        lockOf(container).notice,
        AppLockNotice.turnedOffWithoutScreenLock,
      );
      expect(await PrivacySettingsStore(preferences).read(), isNot(_locked));
      expect((await PrivacySettingsStore(preferences).read()).appLock, isFalse);

      controllerOf(container).dismissNotice();
      expect(lockOf(container).notice, isNull);
    });

    testLock('a device without a screen lock also opens unreadable '
        'settings', (tester) async {
      auth.result = DeviceAuthResult.noCredentials;
      preferences.values[PrivacySettingsStore.key] = 'garbage';

      final container = await start(tester);
      await pumpPastPromptSettle(tester);

      expect(lockOf(container).locked, isFalse);
      expect(lockOf(container).enabled, isFalse);
      expect(
        container.read(privacySettingsControllerProvider).value?.unreadable,
        isFalse,
      );
    });

    testLock('does nothing while open', (tester) async {
      final container = await start(tester);

      await controllerOf(container).unlock();

      expect(auth.prompts, 0);
    });
  });

  group('turning the lock on and off', () {
    testLock('on needs a successful prompt and stays open', (tester) async {
      final container = await start(tester);

      final result = await controllerOf(container)
          .setAppLock(enabled: true, prompt: promptFor('on'));

      expect(result, DeviceAuthResult.success);
      expect(auth.reasons, ['on']);
      expect(lockOf(container).enabled, isTrue);
      expect(lockOf(container).locked, isFalse);
      expect((await PrivacySettingsStore(preferences).read()).appLock, isTrue);
    });

    for (final result in [
      DeviceAuthResult.cancelled,
      DeviceAuthResult.noCredentials,
      DeviceAuthResult.lockedOut,
      DeviceAuthResult.unavailable,
    ]) {
      testLock('on stays off after ${result.name}', (tester) async {
        final container = await start(tester);
        auth.result = result;

        expect(
          await controllerOf(container)
              .setAppLock(enabled: true, prompt: promptFor('on')),
          result,
        );

        expect(lockOf(container).enabled, isFalse);
        expect(preferences.values, isEmpty);
      });
    }

    testLock('off needs a successful prompt', (tester) async {
      final container = await startUnlocked(tester);

      await controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));
      expect(lockOf(container).enabled, isTrue);

      auth.result = DeviceAuthResult.success;
      await controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));

      expect(lockOf(container).enabled, isFalse);
      expect(auth.reasons, [en.appLockPromptReason, 'off', 'off']);
      expect((await PrivacySettingsStore(preferences).read()).appLock, isFalse);
    });

    testLock('off works on a device without a screen lock', (tester) async {
      final container = await startUnlocked(tester);
      auth.result = DeviceAuthResult.noCredentials;

      await controllerOf(container)
          .setAppLock(enabled: false, prompt: promptFor('off'));

      expect(lockOf(container).enabled, isFalse);
    });

    testLock('a new lock time needs no prompt and applies to the next '
        'hide', (tester) async {
      final container = await startUnlocked(tester);

      await container
          .read(privacySettingsControllerProvider.notifier)
          .change(
            (settings) => settings.copyWith(lockAfter: LockAfter.immediately),
          );
      leave(tester);

      expect(auth.prompts, 1);
      expect(lockOf(container).locked, isTrue);
    });
  });

  group('screen protection', () {
    late FakeRecentsScreenshots recents;
    late FakeSecureWindow window;

    Future<ProviderContainer> protect(
      WidgetTester tester,
      PrivacySettings settings, {
      bool systemHidesRecents = true,
    }) async {
      useResumedLifecycle(tester);
      recents = FakeRecentsScreenshots(applies: systemHidesRecents);
      window = FakeSecureWindow();
      await storePrivacySettings(preferences, settings);
      final container = ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(preferences),
          clockProvider.overrideWithValue(() => now),
          deviceAuthenticatorProvider.overrideWithValue(auth),
          recentsScreenshotsProvider.overrideWithValue(recents),
          secureWindowProvider.overrideWithValue(window),
        ],
      );
      track(container);
      await container.read(privacySettingsControllerProvider.future);
      container
        ..listen(appLockControllerProvider, (_, _) {})
        ..listen(screenProtectionProvider, (_, _) {});
      await pumpPastPromptSettle(tester);
      return container;
    }

    testLock('hides the Recents thumbnail while the lock is on', (
      tester,
    ) async {
      final container = await protect(tester, _locked);
      expect(recents.calls, [false]);

      auth.result = DeviceAuthResult.success;
      await container
          .read(appLockControllerProvider.notifier)
          .setAppLock(enabled: false, prompt: promptFor('off'));

      expect(recents.calls, [false, true]);
      await tester.pump(Duration.zero);
    });

    testLock('leaves the cover out where the system hides Recents itself, '
        'so losing focus does not blank the app', (tester) async {
      final container = await protect(tester, _locked);
      expect(lockOf(container).locked, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).covered, isFalse);
    });

    testLock('keeps the cover where the system cannot hide Recents '
        '(Android 12 and older, iOS)', (tester) async {
      final container = await protect(
        tester,
        _locked,
        systemHidesRecents: false,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

      expect(lockOf(container).covered, isTrue);
    });

    testLock('shows it while the lock is off', (tester) async {
      await protect(tester, const PrivacySettings());

      expect(recents.calls, [true]);
      expect(window.changes, isEmpty);
    });

    testLock('blocks screenshots while the switch is on, without '
        'clearing a secret view', (tester) async {
      final container = await protect(
        tester,
        const PrivacySettings(blockScreenshots: true),
      );
      expect(window.secure, isTrue);

      final secretView = container.read(secureDisplayProvider).hold();
      await container
          .read(privacySettingsControllerProvider.notifier)
          .change((settings) => settings.copyWith(blockScreenshots: false));
      await tester.pump(Duration.zero);
      expect(window.secure, isTrue);

      secretView.release();
      expect(window.secure, isFalse);
      expect(window.changes, [true, false]);
    });
  });
}

/// Holds the first read until [release].
final class _SlowPreferences implements PreferencesStore {
  new(this._inner);

  final PreferencesStore _inner;
  final _released = Completer<void>();

  void release() => _released.complete();

  @override
  Future<String?> getString(String key) async {
    await _released.future;
    return await _inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) =>
      _inner.setString(key, value);

  @override
  Future<void> remove(String key) => _inner.remove(key);
}
