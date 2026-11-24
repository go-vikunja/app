import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_storage_flush/vikunja_storage_flush.dart';

final _log = Logger('SecureStore');

abstract interface class SecureStore {
  Future<String?> read(String key);

  /// With [recoverLostKey], storage whose key cannot be unwrapped any more
  /// is wiped and starts over instead of failing (Android only).
  Future<void> write(String key, String value, {bool recoverLostKey = false});

  Future<void> delete(String key);

  Future<void> deleteAll();

  /// Waits until what was written is on disk, not only in memory.
  Future<void> flush();
}

final class FlutterSecureStore implements SecureStore {
  new([FlutterSecureStorage storage = defaultStorage]) : _storage = storage;

  // After first unlock, so background sync and notification actions can read
  // tokens while the device is locked. Never synced to iCloud or restored to
  // another device: a restored backup has to sign in again.
  //
  // On Android a value that cannot be decrypted is an error, not deleted
  // data: the plugin's reset would wipe every token after a passing
  // Keystore failure in a background engine.
  static const defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(resetOnError: false),
  );

  // The plugin's defaults reset storage on error, but it wipes data and
  // keys only when its key cannot be unwrapped while it starts; a write
  // that just fails stays an error. Storage keeps the options it was first
  // opened with until the engine ends, so after such a repair a read in
  // this engine deletes a value it cannot decrypt and finds nothing. Only a
  // value written with the replaced key fails then, which no later start
  // could decrypt either (decision log: Sessions).
  static const AndroidOptions _recoveringKey = AndroidOptions.defaultOptions;

  /// The plugin's SharedPreferences file on Android.
  static const _androidPreferencesName = 'FlutterSecureStorage';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value, {bool recoverLostKey = false}) =>
      _storage.write(
        key: key,
        value: value,
        aOptions: recoverLostKey ? _recoveringKey : null,
      );

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  // The plugin writes with SharedPreferences.apply(), which reaches the disk
  // only after a delay; a process killed meanwhile loses a rotated refresh
  // token the server has already replaced. The Keychain writes at once.
  @override
  Future<void> flush() async {
    try {
      await StorageFlush.flushSharedPreferences(_androidPreferencesName);
    } on Object catch (error) {
      _log.warning('Could not flush secure storage: ${error.runtimeType}');
    }
  }
}
