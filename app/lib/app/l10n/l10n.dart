import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/picker_localizations.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_de.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations_en.dart';

export 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

// The generated AppLocalizations.localizationsDelegates still points at the
// legacy flutter_localizations Material delegates, whose types do not match
// material_ui's, so the list is composed here instead. Of each type the
// first delegate that supports the locale serves it.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [
  _AppLocalizationsDelegate(),
  appMaterialLocalizationsDelegate,
  ...GlobalMaterialLocalizations.delegates,
];

// Not AppLocalizations.supportedLocales, which has every ARB file's.
const List<Locale> appSupportedLocales = shippedLocales;

/// MaterialApp's `localeListResolutionCallback`: [appLocaleFor], so the
/// app's locale keeps the device's region.
Locale appLocaleResolution(List<Locale>? locales, Iterable<Locale> supported) =>
    appLocaleFor(locales ?? const [], shipped: supported.toList());

/// The texts of [locale]'s language, whose [AppLocalizations.localeName]
/// keeps [locale]'s region for the dates and numbers formatted with it.
/// gen-l10n's lookup names only the language.
AppLocalizations appLocalizationsFor(Locale locale) =>
    switch (lookupAppLocalizations(locale)) {
      AppLocalizationsEn() => AppLocalizationsEn(locale.toString()),
      AppLocalizationsDe() => AppLocalizationsDe(locale.toString()),
      final other => other,
    };

final class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(appLocalizationsFor(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
