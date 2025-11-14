import 'package:flutter/widgets.dart';

/// Returns the native name (autonym) for a given locale's language code.
/// Fallback is the raw language code (and country code if present).
String languageAutonym(Locale locale) {
  final code = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toUpperCase();

  switch (code) {
    case 'en':
      return 'English';
    case 'pl':
      return 'Polski';
    // On new language: Add autonyms here
  }

  // For region-specific locales, return languageCode_countryCode (e.g., pt_BR)
  if (country != null && country.isNotEmpty) {
    return '${locale.languageCode}_${country}';
  }
  return locale.languageCode;
}
