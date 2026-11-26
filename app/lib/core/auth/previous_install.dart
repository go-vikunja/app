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
/// The start waits for the wipe, but not past [wipeTimeout].
///
/// A retried start joins a check still running for the same [preferences]:
/// two concurrent checks could both miss the marker, and the slower one
/// would wipe tokens the faster one's start has stored since.
Future<void> purgeSecretsLeftByPreviousInstall({
  required PreferencesStore preferences,
  required SecureStore secureStore,
  Duration wipeTimeout = const Duration(seconds: 10),
}) {
  if (_purging[preferences] case final running?) return running;
  final running = _purge(preferences, secureStore, wipeTimeout);
  _purging[preferences] = running;
  return running.whenComplete(() {
    if (identical(_purging[preferences], running)) {
      _purging[preferences] = null;
    }
  });
}

final _purging = Expando<Future<void>>('purgeSecretsLeftByPreviousInstall');

Future<void> _purge(
  PreferencesStore preferences,
  SecureStore secureStore,
  Duration wipeTimeout,
) async {
  final marker = await preferences
      .getString(installMarkerKey)
      .timeout(AccountRegistry.readTimeout);
  if (marker != null) return;
  final registry = await preferences
      .getString(AccountRegistry.storageKey)
      .timeout(AccountRegistry.readTimeout);
  if (registry == null || registry.isEmpty) {
    try {
      // A wipe that answers late still deletes no token written after it:
      // the plugin runs its calls one after another.
      await secureStore.deleteAll().timeout(wipeTimeout);
    } on Object catch (error) {
      // Without the marker the next start tries again.
      _log.warning('Could not clear secure storage: ${error.runtimeType}');
      return;
    }
    _log.info('Cleared secure storage left by a previous install');
  }
  await preferences.setString(installMarkerKey, '1');
}
