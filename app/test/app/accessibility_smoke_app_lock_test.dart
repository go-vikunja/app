import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/security/device_authenticator.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';

import '../helpers/app_lock_fakes.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';

// The lock screen with its longest message at 200 % text in dark mode on a
// small phone, in English and German. Layout overflows are reported as test
// failures, so reaching the end without an exception is the main assertion.
void main() {
  const smallPhone = Size(320, 640);
  const locales = [Locale('en'), Locale('de')];

  for (final locale in locales) {
    testWidgets('the lock screen with an error at 200 % in dark mode '
        '(${locale.languageCode})', (tester) async {
      usePhoneSurface(tester, logicalSize: smallPhone);
      useAccessibilityExtremes(tester);
      useLocale(tester, locale);
      final l10n = lookupAppLocalizations(locale);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final auth = AuthFakes();
      await storePrivacySettings(
        auth.preferences,
        const PrivacySettings(appLock: true),
      );
      final device = FakeDeviceAuthenticator(
        result: DeviceAuthResult.unavailable,
      );
      final semantics = tester.ensureSemantics();

      await pumpSignedInApp(
        tester,
        auth: auth,
        overrides: [deviceAuthenticatorProvider.overrideWithValue(device)],
      );
      await pumpPastPromptSettle(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.appLockTitle), findsOneWidget);
      expect(find.text(l10n.appLockUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // In reach without scrolling.
      await tester.tap(find.text(l10n.appLockUnlock));
      await tester.pumpAndSettle();
      expect(device.prompts, 2);
      semantics.dispose();
    });
  }
}
