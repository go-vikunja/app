import 'package:flutter/widgets.dart';

/// The languages the app offers, English first as the fallback (D88). An
/// ARB file not listed here compiles, but nothing selects it. Android's
/// locales_config.xml, iOS's CFBundleLocalizations, `PreviousApp.kt` and
/// the store descriptions' language line list the same languages; tests keep
/// them equal.
const List<Locale> shippedLocales = [Locale('en'), Locale('de')];

/// The shipped locale MaterialApp's default resolution picks for a device
/// that reports [locales], resolved over the whole list, else English.
/// Tests pass another [shipped] list.
Locale shippedLocaleFor(
  Iterable<Locale> locales, {
  List<Locale> shipped = shippedLocales,
}) => basicLocaleListResolution(locales.toList(), shipped);

/// The app's locale for a device that reports [locales]: the language
/// [shippedLocaleFor] picks, in the region of the device's first locale of
/// that language, so that dates, numbers, the first day of the week and the
/// clock follow the region (en_GB, de_CH) while the texts stay the
/// language's. A per-app language without a region (`en`) takes the
/// region of the device's own locale of that language.
Locale appLocaleFor(
  Iterable<Locale> locales, {
  List<Locale> shipped = shippedLocales,
}) {
  final language = shippedLocaleFor(locales, shipped: shipped);
  if (language.countryCode != null) return language;
  for (final locale in locales) {
    if (locale case Locale(:final languageCode, countryCode: final region?)
        when languageCode == language.languageCode && region.isNotEmpty) {
      return Locale.fromSubtags(
        languageCode: language.languageCode,
        scriptCode: language.scriptCode,
        countryCode: region,
      );
    }
  }
  return language;
}

/// The locale of a tag like `pt-BR`, `zh-Hant` or an intl locale name like
/// `en_GB`.
Locale localeOfTag(String tag) {
  final subtags = tag.split(RegExp('[-_]'));
  final script = subtags.elementAtOrNull(1)?.length == 4 ? subtags[1] : null;
  return Locale.fromSubtags(
    languageCode: subtags.first,
    scriptCode: script,
    countryCode: subtags.elementAtOrNull(script == null ? 1 : 2),
  );
}
