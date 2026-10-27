import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter's licence page in British English, as the rest of the app:
/// "Licences" in its title and counts. Only English is replaced; the page's
/// other English texts read the same in Flutter's default, and German keeps
/// Flutter's own.
const LocalizationsDelegate<MaterialLocalizations> licencePageLocalizations =
    _LicencePageLocalizationsDelegate();

final class _LicencePageLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const new();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(const _BritishLicencePageLocalizations());

  @override
  bool shouldReload(_LicencePageLocalizationsDelegate old) => false;
}

final class _BritishLicencePageLocalizations
    extends DefaultMaterialLocalizations {
  const new();

  @override
  String get licensesPageTitle => 'Licences';

  @override
  String licensesPackageDetailText(int licenseCount) => switch (licenseCount) {
    0 => 'No licences.',
    1 => '1 licence.',
    _ => '$licenseCount licences.',
  };
}
