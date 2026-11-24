import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret key-value storage.
abstract interface class PreferencesStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

/// A [PreferencesStore] that also reads what is kept as one preference per
/// entry.
abstract interface class PrefixedPreferencesStore implements PreferencesStore {
  /// The strings whose keys start with [prefix], by their whole key.
  Future<Map<String, String>> stringsUnder(String prefix);
}

/// [SharedPreferencesAsync] has no in-memory cache, so every read sees what
/// other isolates wrote.
final class SharedPreferencesStore implements PrefixedPreferencesStore {
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

  @override
  Future<Map<String, String>> stringsUnder(String prefix) async {
    final keys = {
      for (final key in await _preferences.getKeys())
        if (key.startsWith(prefix)) key,
    };
    if (keys.isEmpty) return const {};
    return {
      for (final MapEntry(:key, :value) in (await _preferences.getAll(
        allowList: keys,
      )).entries)
        if (value is String) key: value,
    };
  }
}
