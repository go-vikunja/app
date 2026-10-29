import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/platform/app_language_settings.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 29, 12);
  late List<String> calls;
  late bool canOpen;
  late bool opens;

  setUp(() {
    calls = [];
    canOpen = true;
    opens = true;
  });

  /// The device channel as Android 13 and later answer it when [canOpen],
  /// as Android 12 and older otherwise; iOS answers only the open.
  void useDeviceChannel(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(deviceChannel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'canOpenAppLocaleSettings' => canOpen,
          'openAppLocaleSettings' || 'openAppSettings' => opens,
          _ => null,
        };
      });
    addTearDown(() => messenger.setMockMethodCallHandler(deviceChannel, null));
  }

  void useSystemPalette(WidgetTester tester) {
    final palette = Int64List.fromList([
      for (var tone = 0; tone < 5 * 13; tone++) 0xFF000000 + tone * 0x030303,
    ]);
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        DynamicColorPlugin.channel,
        (call) async =>
            call.method == DynamicColorPlugin.methodName ? palette : null,
      );
    addTearDown(
      () =>
          messenger.setMockMethodCallHandler(DynamicColorPlugin.channel, null),
    );
  }

  Future<void> pumpAccountTab(
    WidgetTester tester, {
    bool android = false,
    bool ios = false,
    AppLocalizations? l10n,
  }) async {
    final texts = l10n ?? en;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    useDeviceChannel(tester);
    await pumpSignedInApp(
      tester,
      sync: SyncFakes(now: now),
      now: now,
      overrides: [
        appLanguageSettingsProvider.overrideWith(
          (ref) => PlatformAppLanguageSettings(
            excursions: ref.watch(appExcursionsProvider),
            android: android,
            ios: ios,
          ),
        ),
      ],
    );
    await openTab(tester, texts.tabAccount);
    await tester.scrollUntilVisible(
      find.text(texts.homeSignOut),
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  testWidgets('Android 13 and later: the Appearance section shows the row '
      "with the app's language, without a palette the row alone, and it "
      'opens the per-app language page as an excursion', (tester) async {
    await pumpAccountTab(tester, android: true);

    expect(find.text(en.appearanceHeading), findsOneWidget);
    expect(find.text(en.appearanceSystemColors), findsNothing);
    expect(
      find.descendant(
        of: row(en.appLanguageTitle),
        matching: find.text(en.appLanguageName),
      ),
      findsOneWidget,
    );
    expect(en.appLanguageName, 'English');

    await tester.tap(row(en.appLanguageTitle));
    await tester.pump();

    expect(calls, ['canOpenAppLocaleSettings', 'openAppLocaleSettings']);
    final excursions = containerOf(tester).read(appExcursionsProvider);
    expect(excursions.active, isTrue);
    const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(excursions.active, isFalse);
  });

  testWidgets('Android 12 and older: no row, and without a palette no '
      'Appearance section', (tester) async {
    canOpen = false;
    await pumpAccountTab(tester, android: true);

    expect(calls, ['canOpenAppLocaleSettings']);
    expect(find.text(en.appLanguageTitle), findsNothing);
    expect(find.text(en.appearanceHeading), findsNothing);
  });

  testWidgets("iOS: the row opens the app's settings page", (tester) async {
    await pumpAccountTab(tester, ios: true);

    await tester.tap(row(en.appLanguageTitle));
    await tester.pump();

    expect(calls, ['openAppSettings']);
    final excursions = containerOf(tester).read(appExcursionsProvider);
    expect(excursions.active, isTrue);
    const [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    expect(excursions.active, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a page that did not open ends the excursion at once', (
    tester,
  ) async {
    opens = false;
    await pumpAccountTab(tester, android: true);

    await tester.tap(row(en.appLanguageTitle));
    await tester.pump();

    expect(calls.last, 'openAppLocaleSettings');
    expect(containerOf(tester).read(appExcursionsProvider).active, isFalse);
  });

  testWidgets('with the system palette the row comes first, above the '
      'colours switch', (tester) async {
    useSystemPalette(tester);
    await pumpAccountTab(tester, android: true);

    final heading = find.text(en.appearanceHeading);
    final language = row(en.appLanguageTitle);
    final colours = find.text(en.appearanceSystemColors);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(top(heading), lessThan(top(language)));
    expect(top(language), lessThan(top(colours)));
  });

  testWidgets('in German it names the language in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpAccountTab(tester, android: true, l10n: de);

    expect(
      find.descendant(
        of: row(de.appLanguageTitle),
        matching: find.text('Deutsch'),
      ),
      findsOneWidget,
    );
  });
}
