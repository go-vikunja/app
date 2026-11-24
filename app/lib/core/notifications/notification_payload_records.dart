import 'package:vikunja_mobile/core/storage/preferences_store.dart';

/// The payload of each notification the app gave to Android, by its id.
/// Android hands back the id of a notification it shows but not its
/// payload, and the tray is cleared by payload: of a task that is done, of
/// an account that signed out, of everything once titles may not show
/// (decision log: Notifications and widgets). One preference per id, so
/// that two isolates never overwrite each other's.
final class NotificationPayloadRecords {
  const new(this._preferences);

  static const _prefix = 'notifications.payload.';

  final PrefixedPreferencesStore _preferences;

  Future<Map<int, String>> all() async => {
    for (final MapEntry(:key, :value) in (await _preferences.stringsUnder(
      _prefix,
    )).entries)
      ?int.tryParse(key.substring(_prefix.length)): value,
  };

  Future<void> put(int osId, String payload) async {
    final key = _key(osId);
    // A new process schedules its whole window again, mostly as it was.
    if (await _preferences.getString(key) == payload) return;
    await _preferences.setString(key, payload);
  }

  Future<void> removeAll(Iterable<int> osIds) async {
    for (final osId in osIds) {
      final key = _key(osId);
      // Most cancels are of an id nothing was kept for.
      if (await _preferences.getString(key) != null) {
        await _preferences.remove(key);
      }
    }
  }

  static String _key(int osId) => '$_prefix$osId';
}
