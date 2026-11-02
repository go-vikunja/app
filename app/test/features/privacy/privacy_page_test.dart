import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/privacy/presentation/lock_after_texts.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_page.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late FakeDeviceAuthenticator authenticator;
  late NotificationFakes notifications;

  setUp(() {
    auth = AuthFakes();
    authenticator = FakeDeviceAuthenticator();
    notifications = NotificationFakes();
  });

  List<Override> overrides() => [
    deviceAuthenticatorProvider.overrideWithValue(authenticator),
  ];

  PrivacySettings stored() =>
      switch (auth.preferences.values[PrivacySettingsStore.key]) {
        final json? => PrivacySettings.fromJson(jsonDecode(json)),
        null => const PrivacySettings(),
      };

  Future<void> openPage(WidgetTester tester) async {
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.privacy),
    );
    await tester.pumpAndSettle();
  }

  /// Signed in on the privacy page; a lock already on is unlocked by the
  /// prompt at the start, which [FakeDeviceAuthenticator.promptTexts] then
  /// no longer holds.
  Future<void> pumpPage(WidgetTester tester) async {
    useResumedLifecycle(tester);
    await pumpSignedInApp(
      tester,
      auth: auth,
      notifications: notifications,
      overrides: overrides(),
    );
    await pumpPastPromptSettle(tester);
    await openPage(tester);
    authenticator.promptTexts.clear();
  }

  Finder lockSwitch() =>
      find.widgetWithText(SwitchListTile, en.privacyAppLockSwitch);

  SwitchListTile switchTile(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title));

  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    double delta = 150,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find
          .descendant(
            of: find.byType(PrivacyPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await scrollTo(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('the summary names the time before the lock', () {
    expect(appLockSummary(en, const PrivacySettings()), 'App lock: Off');
    expect(
      appLockSummary(
        en,
        const PrivacySettings(appLock: true, lockAfter: LockAfter.immediately),
      ),
      'App lock: On · immediately',
    );
    expect(
      appLockSummary(en, const PrivacySettings(appLock: true)),
      'App lock: On · after 1 minute',
    );
    expect(
      appLockSummary(
        de,
        const PrivacySettings(appLock: true, lockAfter: LockAfter.oneHour),
      ),
      'App-Sperre: An · nach 1 Stunde',
    );
  });

  testWidgets('the app lock turns on only once the device confirms it', (
    tester,
  ) async {
    authenticator.result = DeviceAuthResult.cancelled;
    await pumpPage(tester);

    expect(switchTile(tester, en.privacyAppLockSwitch).value, isFalse);
    expect(find.text(en.privacyLockAfter), findsNothing);
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();

    expect(authenticator.reasons, [en.privacyAppLockReasonOn]);
    expect(authenticator.promptTexts.single.title, en.appTitle);
    expect(authenticator.promptTexts.single.hint, en.appLockPromptHint);
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isFalse);
    expect(stored().appLock, isFalse);

    authenticator.result = DeviceAuthResult.success;
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();

    expect(authenticator.reasons, hasLength(2));
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isTrue);
    expect(stored().appLock, isTrue);
    expect(find.text(en.privacyLockAfter), findsOneWidget);
    expect(find.text(en.privacyLockAfterMinutes(1)), findsOneWidget);
    expect(find.text(en.privacyLockAfterRestart), findsOneWidget);
  });

  testWidgets('the switch stays put while the prompt is up', (tester) async {
    authenticator.holdPrompts = true;
    await pumpPage(tester);

    await tester.tap(lockSwitch());
    await tester.pump();
    expect(authenticator.prompting, isTrue);
    expect(switchTile(tester, en.privacyAppLockSwitch).onChanged, isNull);

    authenticator.finish(DeviceAuthResult.success);
    await tester.pumpAndSettle();
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isTrue);
    expect(switchTile(tester, en.privacyAppLockSwitch).onChanged, isNotNull);
  });

  testWidgets('turning the lock off asks too, and a lockout says so', (
    tester,
  ) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true),
    );
    await pumpPage(tester);

    authenticator.result = DeviceAuthResult.lockedOut;
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();

    expect(authenticator.reasons, [en.privacyAppLockReasonOff]);
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isTrue);
    expect(find.text(en.privacyAppLockLockedOut), findsOneWidget);

    authenticator.result = DeviceAuthResult.unavailable;
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();
    expect(find.text(en.privacyAppLockLockedOut), findsNothing);
    expect(find.text(en.privacyAppLockFailed), findsOneWidget);
    expect(stored().appLock, isTrue);

    authenticator.result = DeviceAuthResult.success;
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isFalse);
    expect(find.text(en.privacyAppLockFailed), findsNothing);
    expect(find.text(en.privacyLockAfter), findsNothing);
    expect(stored().appLock, isFalse);
  });

  testWidgets('without a screen lock the switch is off and says why, until '
      'one is set up in the system settings', (tester) async {
    authenticator.supported = false;
    await pumpPage(tester);

    expect(switchTile(tester, en.privacyAppLockSwitch).onChanged, isNull);
    expect(find.text(en.privacyAppLockUnsupported), findsOneWidget);
    expect(find.text(en.privacyAppLockSubtitle), findsNothing);
    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();
    expect(authenticator.prompts, 0);

    authenticator.supported = true;
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(switchTile(tester, en.privacyAppLockSwitch).onChanged, isNotNull);
    expect(find.text(en.privacyAppLockSubtitle), findsOneWidget);
  });

  testWidgets('a device that lost its screen lock still turns the lock off', (
    tester,
  ) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true),
    );
    await pumpPage(tester);
    authenticator
      ..supported = false
      ..result = DeviceAuthResult.noCredentials;

    await tester.tap(lockSwitch());
    await tester.pumpAndSettle();

    expect(switchTile(tester, en.privacyAppLockSwitch).value, isFalse);
    expect(stored().appLock, isFalse);
    expect(find.text(en.privacyAppLockUnsupported), findsOneWidget);
    expect(switchTile(tester, en.privacyAppLockSwitch).onChanged, isNull);
  });

  testWidgets('Lock after offers five choices and keeps the one picked '
      'without a prompt', (tester) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true),
    );
    await pumpPage(tester);

    await tester.tap(find.text(en.privacyLockAfter));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    for (final label in [
      en.privacyLockAfterImmediately,
      en.privacyLockAfterMinutes(1),
      en.privacyLockAfterMinutes(5),
      en.privacyLockAfterMinutes(15),
      en.privacyLockAfterHours(1),
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.text(en.privacyLockAfterMinutes(15)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      stored(),
      const PrivacySettings(appLock: true, lockAfter: LockAfter.fifteenMinutes),
    );
    expect(find.text(en.privacyLockAfterMinutes(15)), findsOneWidget);
    expect(authenticator.prompts, 0);
  });

  testWidgets('screenshots, notification content and widget titles change '
      'without a prompt', (tester) async {
    await pumpPage(tester);

    await tapAndSettle(
      tester,
      find.widgetWithText(SwitchListTile, en.privacyBlockScreenshots),
    );
    expect(stored().blockScreenshots, isTrue);

    expect(
      tester
          .widget<RadioGroup<NotificationContent>>(
            find.byType(RadioGroup<NotificationContent>),
          )
          .groupValue,
      NotificationContent.all,
    );
    await tapAndSettle(
      tester,
      find.text(en.privacyNotificationContentNoTitles),
    );
    expect(stored().notificationContent, NotificationContent.noTitles);
    // Android hides the content itself.
    expect(find.text(en.privacyNotificationContentIosHint), findsNothing);
    await tapAndSettle(tester, find.text(en.privacyNotificationContentHidden));
    expect(
      stored().notificationContent,
      NotificationContent.hiddenOnLockScreen,
    );
    expect(find.text(en.privacyNotificationContentIosHint), findsNothing);
    // Android leaves such notifications off the secure lock screen.
    expect(
      find.text(en.privacyNotificationContentHiddenSubtitleAndroid),
      findsOneWidget,
    );
    expect(
      find.text(en.privacyNotificationContentHiddenSubtitle),
      findsNothing,
    );

    await scrollTo(tester, find.text(en.widgetsPrivacyNote));
    await tapAndSettle(
      tester,
      find.widgetWithText(SwitchListTile, en.privacyWidgetTitles),
    );
    expect(stored().widgetTitles, isFalse);
    expect(find.text(en.widgetsPrivacyNote), findsNothing);
    expect(authenticator.prompts, 0);
  });

  testWidgets(
    'on iOS there is no screenshot switch, and hiding from the lock screen '
    "leads to the system's setting",
    (tester) async {
      await pumpPage(tester);

      expect(find.text(en.privacyBlockScreenshots), findsNothing);
      expect(find.text(en.privacyNotificationContentIosHint), findsNothing);
      await tapAndSettle(
        tester,
        find.text(en.privacyNotificationContentHidden),
      );
      expect(
        stored().notificationContent,
        NotificationContent.hiddenOnLockScreen,
      );
      expect(find.text(en.privacyNotificationContentIosHint), findsOneWidget);
      expect(
        find.text(en.privacyNotificationContentHiddenSubtitle),
        findsOneWidget,
      );
      expect(
        find.text(en.privacyNotificationContentHiddenSubtitleAndroid),
        findsNothing,
      );
      expect(find.text(en.privacyAppSwitcherHidden), findsOneWidget);

      await tapAndSettle(
        tester,
        find.widgetWithText(TextButton, en.notificationsOpenSettings),
      );
      expect(notifications.calls('openNotificationSettings'), 1);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('the app switcher is best effort on Android 12 and older', (
    tester,
  ) async {
    auth.preferences.values[androidVersionKey] = '12';
    await pumpPage(tester);

    expect(find.text(en.privacyAppSwitcherBestEffort), findsOneWidget);
    expect(find.text(en.privacyAppSwitcherHidden), findsNothing);
  });

  testWidgets('Android 13 hides the app switcher thumbnail itself', (
    tester,
  ) async {
    auth.preferences.values[androidVersionKey] = '13';
    await pumpPage(tester);

    expect(find.text(en.privacyAppSwitcherHidden), findsOneWidget);
    expect(find.text(en.privacyAppSwitcherBestEffort), findsNothing);
  });

  testWidgets('unreadable settings show the defaults with a note until a '
      'change stores them again', (tester) async {
    auth.preferences.values[PrivacySettingsStore.key] = '{"version": 7}';
    await pumpPage(tester);

    expect(find.text(en.privacySettingsUnreadable), findsOneWidget);
    expect(switchTile(tester, en.privacyAppLockSwitch).value, isFalse);

    await tapAndSettle(
      tester,
      find.widgetWithText(SwitchListTile, en.privacyWidgetTitles),
    );
    expect(stored(), const PrivacySettings(widgetTitles: false));
    await scrollTo(tester, find.text(en.privacyAppLockSwitch), delta: -150);
    expect(find.text(en.privacySettingsUnreadable), findsNothing);
  });

  testWidgets('the page starts right below the app bar under a status bar', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 600);
    addTearDown(tester.view.resetPadding);
    await pumpPage(tester);

    final appBar = find.descendant(
      of: find.byType(PrivacyPage),
      matching: find.byType(AppBar),
    );
    final appBarBottom = tester.getBottomLeft(appBar).dy;
    final firstHeader = tester
        .getTopLeft(
          find.widgetWithText(ListSectionHeader, en.privacyAppLockHeading),
        )
        .dy;
    expect(firstHeader - appBarBottom, lessThan(40));
  });

  testWidgets("the Account tab's device section between notifications and "
      'appearance says how the lock is set and opens the page', (tester) async {
    await storePrivacySettings(
      auth.preferences,
      const PrivacySettings(appLock: true, lockAfter: LockAfter.fiveMinutes),
    );
    useResumedLifecycle(tester);
    // Tall enough for the sections around it, which the list builds lazily.
    usePhoneSurface(tester, logicalSize: const Size(400, 2000));
    await pumpSignedInApp(
      tester,
      auth: auth,
      notifications: notifications,
      overrides: overrides(),
    );
    await pumpPastPromptSettle(tester);
    await tester.pumpAndSettle();
    await openTab(tester, en.tabAccount);

    final entry = find.text(en.privacyEntryTitle);
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();

    final header = find.widgetWithText(ListSectionHeader, en.privacyTitle);
    expect(
      find.descendant(of: header, matching: find.text(en.onThisDeviceHeading)),
      findsOneWidget,
    );
    expect(
      find.text(en.privacyEntryAppLockAfter(en.privacyLockAfterMinutes(5))),
      findsOneWidget,
    );
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(
      top(header),
      greaterThan(
        top(find.widgetWithText(ListSectionHeader, en.notificationsHeading)),
      ),
    );
    expect(
      top(header),
      lessThan(
        top(find.widgetWithText(ListSectionHeader, en.appearanceHeading)),
      ),
    );

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(
      containerOf(tester).read(appRouterProvider).state.matchedLocation,
      AppRoutes.privacy,
    );
  });

  testWidgets('a link-share guest has the section and the page too', (
    tester,
  ) async {
    await pumpGuestApp(
      tester,
      auth: auth,
      data: SyncFakes(),
      overrides: overrides(),
    );
    await pumpPastPromptSettle(tester);
    await tester.pumpAndSettle();
    await openTab(tester, en.tabAccount);

    final entry = find.text(en.privacyEntryTitle);
    await tester.scrollUntilVisible(
      entry,
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(find.text(en.privacyEntryAppLockOff), findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPage), findsOneWidget);
    expect(
      containerOf(tester).read(appRouterProvider).state.matchedLocation,
      AppRoutes.privacy,
    );
    expect(AppRoutes.isClosedToGuests(AppRoutes.privacy), isFalse);
  });
}
