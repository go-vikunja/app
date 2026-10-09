import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret key-value storage.
abstract interface class PreferencesStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

/// [SharedPreferencesAsync] has no in-memory cache, so every read sees what
/// other isolates wrote.
final class SharedPreferencesStore implements PreferencesStore {
  new([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
