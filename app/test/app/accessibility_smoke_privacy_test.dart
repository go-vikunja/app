import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_page.dart';

import '../helpers/app_lock_fakes.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';

// The privacy page and the Account tab's entry to it at 200 % text in dark
// mode on a small phone, in English and German. Layout overflows are
// reported as test failures, so reaching the end of each scenario without
// an exception is the assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  void useWorstCase(WidgetTester tester, Locale locale) {
    usePhoneSurface(tester, logicalSize: smallPhone);
    useAccessibilityExtremes(tester);
    useLocale(tester, locale);
  }

  Finder scrollableOf(Type page) => find
      .descendant(of: find.byType(page), matching: find.byType(Scrollable))
      .first;

  Future<void> scrollToEnd(WidgetTester tester, Type page) async {
    final scrollable = scrollableOf(page);
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var i = 0; i < 80 && position.extentAfter > 0; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(position.extentAfter, 0);
  }

  Future<void> bringIntoView(
    WidgetTester tester,
    Type page,
    Finder finder, {
    double delta = 200,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollableOf(page),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<FakeDeviceAuthenticator> pumpPrivacy(
    WidgetTester tester, {
    PrivacySettings? settings,
    bool unreadable = false,
  }) async {
    final auth = AuthFakes();
    final authenticator = FakeDeviceAuthenticator();
    if (settings != null) {
      await storePrivacySettings(auth.preferences, settings);
    }
    if (unreadable) {
      auth.preferences.values[PrivacySettingsStore.key] = 'not json';
    }
    useResumedLifecycle(tester);
    await pumpSignedInApp(
      tester,
      auth: auth,
      overrides: [deviceAuthenticatorProvider.overrideWithValue(authenticator)],
    );
    await pumpPastPromptSettle(tester);
    unawaited(
      containerOf(tester).read(appRouterProvider).push(AppRoutes.privacy),
    );
    await tester.pumpAndSettle();
    return authenticator;
  }

  for (final locale in locales) {
    testWidgets('the privacy page with the lock on, a lockout, unreadable '
        'settings and the Lock after sheet at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final authenticator = await pumpPrivacy(tester, unreadable: true);

      expect(find.byType(PrivacyPage), findsOneWidget);
      authenticator.result = DeviceAuthResult.success;
      final lockSwitch = find.text(l10n.privacyAppLockSwitch);
      await bringIntoView(tester, PrivacyPage, lockSwitch);
      await tester.tap(lockSwitch);
      await tester.pumpAndSettle();
      authenticator.result = DeviceAuthResult.lockedOut;
      // Turning the lock on stored the settings, which drops the note on
      // the unreadable ones above it.
      await tester.ensureVisible(lockSwitch);
      await tester.pumpAndSettle();
      await tester.tap(lockSwitch);
      await tester.pumpAndSettle();
      expect(find.text(l10n.privacyAppLockLockedOut), findsOneWidget);

      final lockAfter = find.text(l10n.privacyLockAfter);
      await bringIntoView(tester, PrivacyPage, lockAfter);
      await tester.tap(lockAfter);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.privacyLockAfterImmediately).last);
      await tester.pumpAndSettle();

      await scrollToEnd(tester, PrivacyPage);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the privacy page on iOS with the lock screen hint at 200 % in dark '
      'mode (${locale.languageCode})',
      (tester) async {
        useWorstCase(tester, locale);
        final l10n = lookupAppLocalizations(locale);
        await pumpPrivacy(
          tester,
          settings: const PrivacySettings(
            notificationContent: NotificationContent.hiddenOnLockScreen,
          ),
        );

        await bringIntoView(
          tester,
          PrivacyPage,
          find.text(l10n.privacyNotificationContentIosHint),
        );
        await scrollToEnd(tester, PrivacyPage);
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );

    testWidgets("the Account tab's privacy entry with the lock on at 200 % "
        'in dark mode (${locale.languageCode})', (tester) async {
      useWorstCase(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      final auth = AuthFakes();
      await storePrivacySettings(
        auth.preferences,
        const PrivacySettings(appLock: true, lockAfter: LockAfter.oneHour),
      );
      useResumedLifecycle(tester);
      await pumpSignedInApp(
        tester,
        auth: auth,
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(
            FakeDeviceAuthenticator(),
          ),
        ],
      );
      await pumpPastPromptSettle(tester);
      await tester.pumpAndSettle();
      await openTab(tester, l10n.tabAccount);

      await bringIntoView(
        tester,
        AccountTab,
        find.text(l10n.privacyEntryAppLockAfter(l10n.privacyLockAfterHours(1))),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
