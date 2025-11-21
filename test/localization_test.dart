
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

void main() {
  final supportedLocales = AppLocalizations.supportedLocales;

  group('Localization coverage', () {
    test('Supported locales list is not empty', () {
      expect(
        supportedLocales.isNotEmpty,
        true,
        reason: 'No supported locales detected from AppLocalizations',
      );
    });

    test('Count untranslated strings per supported locale (vs English baseline)', () {
      final arbDir = Directory('lib/l10n');
      final enFile = File('${arbDir.path}/app_en.arb');
      expect(enFile.existsSync(), true, reason: 'English ARB not found at ${enFile.path}');

      final enJson = json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;
      final enKeys = enJson.keys.where((k) => !k.startsWith('@') && !k.startsWith('@@')).toList();

      for (final locale in supportedLocales) {
        final code = locale.languageCode;
        final file = File('${arbDir.path}/app_${code}.arb');
        if (!file.existsSync()) {
          print('WARNING: Missing ARB file for supported locale $code (${file.path})');
          continue;
        }
        final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;

        int untranslatedCount = 0;
        for (final key in enKeys) {
          final enVal = enJson[key];
          final locVal = jsonMap[key];
          final isMissing = locVal == null;
          final isEmpty = locVal is String ? locVal.trim().isEmpty : true;
          final equalsKey = locVal == key;
          final equalsEnglish = code != 'en' && locVal == enVal;

          if (isMissing || isEmpty || equalsKey || equalsEnglish) {
            untranslatedCount++;
          }
        }

        if (untranslatedCount > 0) {
          print('Locale $code: $untranslatedCount untranslated strings');
        }
      }
    });
  });
}
