import 'package:vikunja_mobile/core/storage/preferences_store.dart';

/// How far each account's server clock is ahead of the device, so a new
/// isolate or a cold start judges stored tokens in server time right away.
/// Kept outside the account registry, whose writes announce changes.
final class ServerClockOffsets {
  new(this._preferences);

  final PreferencesStore _preferences;

  static String storageKey(String accountId) =>
      'auth.server_clock_offset.$accountId';

  Future<Duration?> read(String accountId) async {
    final raw = await _preferences.getString(storageKey(accountId));
    final milliseconds = raw == null ? null : int.tryParse(raw);
    return milliseconds == null ? null : Duration(milliseconds: milliseconds);
  }

  Future<void> write(String accountId, Duration offset) =>
      _preferences.setString(storageKey(accountId), '${offset.inMilliseconds}');

  Future<void> delete(String accountId) =>
      _preferences.remove(storageKey(accountId));
}
