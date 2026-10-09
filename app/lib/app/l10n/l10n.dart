import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

export 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

// The generated AppLocalizations.localizationsDelegates still points at the
// legacy flutter_localizations Material delegates, whose types do not match
// material_ui's, so the list is composed here instead.
const List<LocalizationsDelegate<Object?>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

const List<Locale> appSupportedLocales = AppLocalizations.supportedLocales;

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
