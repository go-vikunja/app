import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

const Map<String, String> kLocaleAutonyms = <String, String>{
  'en': 'English',
  'pl': 'Polski',
};

String languageAutonym(Locale locale) {
  final canonicalLocale = Intl.canonicalizedLocale(locale.toString());
  final nativeNames = kLocaleAutonyms;

  final autonym =
      nativeNames[canonicalLocale] ??
      nativeNames[locale.languageCode.toLowerCase()];

  if (autonym != null && autonym.isNotEmpty) {
    return autonym;
  }

  final country = locale.countryCode;
  if (country != null && country.isNotEmpty) {
    return '${locale.languageCode}_$country';
  }

  return locale.languageCode;
}
