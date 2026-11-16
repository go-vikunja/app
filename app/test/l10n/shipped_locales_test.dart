import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';

String _read(String path) =>
    File(path)
        .readAsStringSync()
        .replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

Set<String> _firstGroups(String pattern, String text) => {
  for (final match in RegExp(pattern).allMatches(text)) match[1]!,
};

/// The values of the plist's CFBundleLocalizations, null without the key.
Set<String>? _bundleLocalizations(String plist) {
  final array = RegExp(
    r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(plist)?[1];
  return array == null ? null : _firstGroups('<string>([^<]*)</string>', array);
}

void main() {
  final shipped = {for (final locale in shippedLocales) locale.toLanguageTag()};

  test('English comes first, as the fallback, and no language twice', () {
    expect(shippedLocales.first, const Locale('en'));
    expect(shipped, hasLength(shippedLocales.length));
  });

  test("Android's per-app language list has the shipped languages", () {
    final config = _read('android/app/src/main/res/xml/locales_config.xml');

    expect(_firstGroups('android:name="([^"]+)"', config), shipped);
  });

  test("iOS's localizations of the app, and of the widgets if they list "
      'any, are the shipped languages', () {
    expect(_bundleLocalizations(_read('ios/Runner/Info.plist')), shipped);
    expect(
      _bundleLocalizations(_read('ios/VikunjaWidgets/Info.plist')),
      anyOf(isNull, shipped),
    );
  });

  test("the previous app's language is carried over on Android for the "
      'shipped languages', () {
    final kotlin = File(
      'android/app/src/main/kotlin/io/vikunja/app/PreviousApp.kt',
    ).readAsStringSync();
    final languages = RegExp(r'val LANGUAGES = setOf\(([^)]*)\)')
        .firstMatch(kotlin)?[1];

    expect(languages, isNotNull);
    expect(_firstGroups('"([^"]+)"', languages!), shipped);
  });

  test('every shipped language has an ARB file, which the generated code '
      'has read', () {
    for (final locale in shippedLocales) {
      expect(
        File('lib/l10n/arb/app_$locale.arb').existsSync(),
        isTrue,
        reason: '$locale',
      );
      expect(AppLocalizations.supportedLocales, contains(locale));
    }
  });

  test("every shipped language has Material's, Cupertino's and the "
      "widgets' texts", () {
    for (final locale in shippedLocales) {
      for (final delegate in appLocalizationsDelegates) {
        expect(
          delegate.isSupported(locale),
          isTrue,
          reason: '$delegate for $locale',
        );
      }
    }
  });

  testWidgets("a device's locales resolve as MaterialApp resolves them, over "
      'the shipped list and over one with regional and script variants', (
    tester,
  ) async {
    const zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    const variants = [
      Locale('en'),
      Locale('de'),
      Locale('pt'),
      Locale('pt', 'BR'),
      Locale('zh'),
      zhHant,
    ];
    // The device's locales and what the variants give.
    const cases = [
      (<Locale>[], Locale('en')),
      ([Locale('de', 'AT')], Locale('de')),
      ([Locale('fr', 'CH'), Locale('de', 'DE')], Locale('de')),
      // A language match below the first locale yields to a later exact one.
      ([Locale('fr'), Locale('de', 'AT'), Locale('en')], Locale('en')),
      ([Locale('pt', 'PT'), Locale('pt', 'BR')], Locale('pt', 'BR')),
      // With no language match, a shipped locale of the device's country.
      ([Locale('es', 'BR')], Locale('pt', 'BR')),
      (
        [
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ),
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ],
        zhHant,
      ),
      ([Locale('sr')], Locale('en')),
    ];
    Future<Locale> shownBy(List<Locale> supported) async {
      late Locale shown;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          supportedLocales: supported,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (context) {
              shown = Localizations.localeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return shown;
    }

    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    for (final (device, fromVariants) in cases) {
      tester.platformDispatcher.localesTestValue = device;

      expect(
        shippedLocaleFor(device),
        await shownBy(shippedLocales),
        reason: '$device',
      );
      expect(await shownBy(variants), fromVariants, reason: '$device');
      expect(
        shippedLocaleFor(device, shipped: variants),
        fromVariants,
        reason: '$device',
      );
    }
  });

  test('French is not shipped', () {
    expect(
      shippedLocales.map((locale) => locale.languageCode),
      isNot(contains('fr')),
      reason:
          'The locale and device language tests take French for a language '
          'the app does not ship; give them another one.',
    );
  });
}
