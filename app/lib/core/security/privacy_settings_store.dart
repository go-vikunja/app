import 'dart:convert';

import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

/// The stored settings could not be read or decoded.
final class PrivacySettingsUnreadable implements Exception {
  const new(this.cause);

  /// The type of what went wrong, never the stored value.
  final String cause;

  @override
  String toString() => 'PrivacySettingsUnreadable($cause)';
}

/// `privacy.settings` in the preferences store, as JSON. A device key, so
/// sign-out leaves it alone.
final class PrivacySettingsStore {
  new(this._preferences);

  static const key = 'privacy.settings';

  final PreferencesStore _preferences;

  /// The defaults when nothing is stored; throws [PrivacySettingsUnreadable]
  /// when the read fails or the value does not decode.
  Future<PrivacySettings> read() async {
    final String? stored;
    try {
      stored = await _preferences.getString(key);
    } on Object catch (error) {
      throw PrivacySettingsUnreadable('${error.runtimeType}');
    }
    if (stored == null) return const PrivacySettings();
    try {
      return PrivacySettings.fromJson(jsonDecode(stored));
    } on FormatException catch (error) {
      throw PrivacySettingsUnreadable('${error.runtimeType}');
    }
  }

  Future<void> write(PrivacySettings settings) =>
      _preferences.setString(key, jsonEncode(settings.toJson()));
}
