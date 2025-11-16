import 'package:flutter/widgets.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:intl/intl.dart';

String languageAutonym(Locale locale) {
  final canonicalLocale = Intl.canonicalizedLocale(locale.toString());
  final nativeNames = LocaleNamesLocalizationsDelegate.nativeLocaleNames;

  final autonym =
      nativeNames[canonicalLocale] ??
      nativeNames[locale.languageCode.toLowerCase()];

  if (autonym != null && autonym.isNotEmpty) {
    return autonym[0].toUpperCase() + autonym.substring(1);
  }

  final country = locale.countryCode;
  if (country != null && country.isNotEmpty) {
    return '${locale.languageCode}_$country';
  }

  return locale.languageCode;
}
