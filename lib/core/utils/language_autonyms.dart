import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

const Map<String, String> kLocaleAutonyms = <String, String>{
  'en': 'English',
  'en_US': 'English (United States)',
  'en_GB': 'English (United Kingdom)',
  'es': 'español',
  'es_ES': 'español (España)',
  'pl': 'polski',
  'pl_PL': 'polski (Polska)',
  'de': 'Deutsch',
  'de_DE': 'Deutsch (Deutschland)',
  'fr': 'français',
  'fr_FR': 'français (France)',
  'pt': 'português',
  'pt_PT': 'português (Portugal)',
  'pt_BR': 'português (Brasil)',
  'it': 'italiano',
  'it_IT': 'italiano (Italia)',
  'nl': 'Nederlands',
  'nl_NL': 'Nederlands (Nederland)',
  'ru': 'русский',
  'ru_RU': 'русский (Россия)',
  'uk': 'українська',
  'uk_UA': 'українська (Україна)',
  'tr': 'Türkçe',
  'tr_TR': 'Türkçe (Türkiye)',
  'el': 'Ελληνικά',
  'el_GR': 'Ελληνικά (Ελλάδα)',
  'cs': 'čeština',
  'cs_CZ': 'čeština (Česká republika)',
  'sk': 'slovenčina',
  'sk_SK': 'slovenčina (Slovensko)',
  'sv': 'svenska',
  'sv_SE': 'svenska (Sverige)',
  'da': 'dansk',
  'da_DK': 'dansk (Danmark)',
  'nb': 'norsk bokmål',
  'nb_NO': 'norsk bokmål (Norge)',
  'fi': 'suomi',
  'fi_FI': 'suomi (Suomi)',
  'hu': 'magyar',
  'hu_HU': 'magyar (Magyarország)',
  'ro': 'română',
  'ro_RO': 'română (România)',
  'bg': 'български',
  'bg_BG': 'български (България)',
  'sr_Latn': 'srpski (latinica)',
  'sr_Cyrl': 'српски (ћирилица)',
  'hr': 'hrvatski',
  'hr_HR': 'hrvatski (Hrvatska)',
  'bs': 'bosanski',
  'bs_BA': 'bosanski (Bosna i Hercegovina)',
  'sl': 'slovenščina',
  'sl_SI': 'slovenščina (Slovenija)',
  'lt': 'lietuvių',
  'lt_LT': 'lietuvių (Lietuva)',
  'lv': 'latviešu',
  'lv_LV': 'latviešu (Latvija)',
  'et': 'eesti',
  'et_EE': 'eesti (Eesti)',
};

String languageAutonym(Locale locale) {
  final canonicalLocale = Intl.canonicalizedLocale(locale.toString());
  final nativeNames = kLocaleAutonyms;

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
