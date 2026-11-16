import 'dart:io';
import 'dart:ui' show Locale;

import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';

/// A language with an ARB file, and so generated strings, that the app does
/// not ship (`sr` today); null once every such language ships.
Locale? unshippedLanguageWithArb() {
  final shipped = {for (final locale in shippedLocales) locale.languageCode};
  final languages = [
    for (final file in Directory('lib/l10n/arb').listSync())
      if (RegExp(r'[/\\]app_([a-z]{2,3})\.arb$').firstMatch(file.path)?[1]
          case final language? when !shipped.contains(language))
        language,
  ]..sort();
  return languages.isEmpty ? null : Locale(languages.first);
}
