import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

/// A palette as Android hands it over: 13 tones of each of the five tonal
/// palettes; tone 40 is the light scheme's primary, tone 80 the dark one's.
Int64List _palette({required int primary40, required int primary80}) {
  List<int> tones(int tone40, int tone80) => [
    0xFF000000,
    0xFF101010,
    0xFF202020,
    0xFF303030,
    tone40,
    0xFF505050,
    0xFF606060,
    0xFF707070,
    tone80,
    0xFF909090,
    0xFFF0F0F0,
    0xFFFAFAFA,
    0xFFFFFFFF,
  ];
  return Int64List.fromList([
    ...tones(primary40, primary80),
    ...tones(0xFF3D6650, 0xFFA3D0B4),
    ...tones(0xFF3C6472, 0xFFA4CDDE),
    ...tones(0xFF5E5E5E, 0xFFC6C6C6),
    ...tones(0xFF5A605B, 0xFFC1C8C2),
  ]);
}

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() => data = SyncFakes(now: now));

  ThemeData themeOf(WidgetTester tester, Type screen) =>
      Theme.of(tester.element(find.byType(screen)));

  void usePlatformBrightness(WidgetTester tester, Brightness brightness) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  void useSystemPalette(WidgetTester tester, Int64List? Function() palette) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DynamicColorPlugin.channel,
      (call) async =>
          call.method == DynamicColorPlugin.methodName ? palette() : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DynamicColorPlugin.channel,
        null,
      ),
    );
  }

  group('colour scheme from the web', () {
    testWidgets('auto follows the system, light and dark override it', (
      tester,
    ) async {
      usePlatformBrightness(tester, Brightness.dark);
      await pumpSignedInApp(tester, sync: data, now: now);
      expect(themeOf(tester, OverviewScreen).brightness, Brightness.dark);

      data.shared.settings = const UserSettings(colorSchema: ColorSchema.light);
      await tester.pumpAndSettle();
      expect(themeOf(tester, OverviewScreen).brightness, Brightness.light);

      usePlatformBrightness(tester, Brightness.light);
      data.shared.settings = const UserSettings(colorSchema: ColorSchema.dark);
      await tester.pumpAndSettle();
      expect(themeOf(tester, OverviewScreen).brightness, Brightness.dark);

      data.shared.settings = const UserSettings();
      await tester.pumpAndSettle();
      expect(themeOf(tester, OverviewScreen).brightness, Brightness.light);
    });

    testWidgets('signed out follows the system', (tester) async {
      usePlatformBrightness(tester, Brightness.dark);
      await pumpVikunjaApp(tester);

      expect(themeOf(tester, ConnectServerScreen).brightness, Brightness.dark);
    });

    testWidgets("an account switch takes the other account's choice", (
      tester,
    ) async {
      final auth = AuthFakes();
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      data.accounts[bob.id] = AccountDataFakes(now: now)
        ..settings = const UserSettings(colorSchema: ColorSchema.dark);
      await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
      expect(themeOf(tester, OverviewScreen).brightness, Brightness.light);

      await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
      await tester.pumpAndSettle();

      expect(themeOf(tester, OverviewScreen).brightness, Brightness.dark);
    });
  });

  group('system colours', () {
    final brandLight = AppTheme.light().colorScheme.primary;
    final brandDark = AppTheme.dark().colorScheme.primary;

    testWidgets('Android 12 and later take the palette for both modes and '
        'keep the component themes', (tester) async {
      useSystemPalette(
        tester,
        () => _palette(primary40: 0xFF00AA44, primary80: 0xFF66DD88),
      );
      await pumpSignedInApp(tester, sync: data, now: now);

      final light = themeOf(tester, OverviewScreen);
      expect(light.colorScheme.primary, const Color(0xFF00AA44));
      expect(
        light.filledButtonTheme.style?.minimumSize?.resolve({}),
        const Size(64, 52),
      );

      data.shared.settings = const UserSettings(colorSchema: ColorSchema.dark);
      await tester.pumpAndSettle();
      expect(
        themeOf(tester, OverviewScreen).colorScheme.primary,
        const Color(0xFF66DD88),
      );
    });

    testWidgets('the palette is read again when the app comes back', (
      tester,
    ) async {
      var primary = 0xFF00AA44;
      useSystemPalette(
        tester,
        () => _palette(primary40: primary, primary80: 0xFF66DD88),
      );
      await pumpSignedInApp(tester, sync: data, now: now);

      primary = 0xFFAA3300;
      const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ].forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pumpAndSettle();

      expect(
        themeOf(tester, OverviewScreen).colorScheme.primary,
        const Color(0xFFAA3300),
      );
    });

    testWidgets('the switch in the Account tab turns them off for the '
        'device, and on again', (tester) async {
      useSystemPalette(
        tester,
        () => _palette(primary40: 0xFF00AA44, primary80: 0xFF66DD88),
      );
      final auth = await pumpSignedInApp(tester, sync: data, now: now);
      await openTab(tester, en.tabAccount);
      final toggle = find.widgetWithText(
        SwitchListTile,
        en.appearanceSystemColors,
      );
      await tester.scrollUntilVisible(
        toggle,
        100,
        scrollable: find
            .descendant(
              of: find.byType(AccountTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(find.text(en.appearanceHeading), findsOneWidget);
      expect(find.text(en.appearanceSystemColorsSubtitle), findsOneWidget);
      expect(find.text(en.appearanceLightDarkHint), findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(themeOf(tester, AccountTab).colorScheme.primary, brandLight);
      expect(auth.preferences.values[useSystemColorsKey], 'false');

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        themeOf(tester, AccountTab).colorScheme.primary,
        const Color(0xFF00AA44),
      );
      expect(auth.preferences.values[useSystemColorsKey], 'true');
    });

    testWidgets('turned off before, the app starts in the brand blue', (
      tester,
    ) async {
      useSystemPalette(
        tester,
        () => _palette(primary40: 0xFF00AA44, primary80: 0xFF66DD88),
      );
      final auth = AuthFakes();
      auth.preferences.values[useSystemColorsKey] = 'false';
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await pumpVikunjaApp(tester, auth: auth, sync: data);

      expect(themeOf(tester, OverviewScreen).colorScheme.primary, brandLight);
    });

    for (final (name, variant) in [
      ('Android before 12', TargetPlatform.android),
      ('iOS', TargetPlatform.iOS),
    ]) {
      testWidgets('$name keeps the brand blue and offers no switch', (
        tester,
      ) async {
        useSystemPalette(tester, () => null);
        usePlatformBrightness(tester, Brightness.dark);
        await pumpSignedInApp(tester, sync: data, now: now);

        expect(themeOf(tester, OverviewScreen).colorScheme.primary, brandDark);
        await openTab(tester, en.tabAccount);
        await tester.scrollUntilVisible(
          find.text(en.homeSignOut),
          100,
          scrollable: find
              .descendant(
                of: find.byType(AccountTab),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(en.appearanceHeading), findsNothing);
        expect(find.text(en.appearanceSystemColors), findsNothing);
      }, variant: TargetPlatformVariant.only(variant));
    }

    testWidgets('iOS never asks for a palette', (tester) async {
      var asked = 0;
      useSystemPalette(tester, () {
        asked++;
        return _palette(primary40: 0xFF00AA44, primary80: 0xFF66DD88);
      });
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(asked, 0);
      expect(themeOf(tester, OverviewScreen).colorScheme.primary, brandLight);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
