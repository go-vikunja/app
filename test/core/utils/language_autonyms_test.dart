import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/language_autonyms.dart';

void main() {
  group('languageAutonym', () {
    test('returns the native name for a known language', () {
      expect(languageAutonym(const Locale('en')), 'English');
      expect(languageAutonym(const Locale('it')), 'Italiano');
      expect(languageAutonym(const Locale('pl')), 'Polski');
    });

    test('falls back to the base language of a regional locale', () {
      expect(languageAutonym(const Locale('en', 'US')), 'English');
    });

    test('renders language_COUNTRY for an unmapped regional locale', () {
      expect(languageAutonym(const Locale('fr', 'CA')), 'fr_CA');
    });

    test('renders the bare language code for an unmapped locale', () {
      expect(languageAutonym(const Locale('fr')), 'fr');
    });
  });
}
