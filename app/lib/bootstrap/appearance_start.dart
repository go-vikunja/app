import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';

final _log = Logger('Bootstrap');

/// The device's theme, the system colours and the active account's
/// settings, which the first frame would otherwise switch away from a
/// moment later. Never throws: the app starts in the default colours
/// instead.
Future<void> loadAppearance(ProviderContainer container) async {
  // Kept for the app's lifetime: some reads take the settings' current
  // value at once, e.g. the default project.
  container.listen(userSettingsProvider, (_, _) {});
  try {
    await Future.wait([
      container.read(themeChoiceProvider.future),
      container.read(userSettingsProvider.future),
      container.read(systemColorsProvider.future),
      container.read(useSystemColorsProvider.future),
    ]);
  } on Object catch (error) {
    _log.warning('Could not load the appearance: ${error.runtimeType}');
  }
}
