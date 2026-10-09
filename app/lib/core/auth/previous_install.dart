import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

final _log = Logger('PreviousInstall');

const installMarkerKey = 'auth.install_marker';

/// iOS keeps Keychain items when the app is deleted, but not its preferences,
/// so a reinstall would inherit the refresh tokens of accounts it no longer
/// knows. Preferences without the marker and without a registry mean a fresh
/// install: secure storage is wiped once. A registry without the marker is
/// an update from a build before the marker existed and is left alone.
///
/// Only for the UI start: a background isolate must never wipe tokens.
Future<void> purgeSecretsLeftByPreviousInstall({
  required PreferencesStore preferences,
  required SecureStore secureStore,
}) async {
  if (await preferences.getString(installMarkerKey) != null) return;
  final registry = await preferences.getString(AccountRegistry.storageKey);
  if (registry == null || registry.isEmpty) {
    try {
      await secureStore.deleteAll();
    } on Object catch (error) {
      // Without the marker the next start tries again.
      _log.warning('Could not clear secure storage: ${error.runtimeType}');
      return;
    }
    _log.info('Cleared secure storage left by a previous install');
  }
  await preferences.setString(installMarkerKey, '1');
}
