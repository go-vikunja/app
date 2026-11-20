import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android's `SharedPreferences.apply()` reaches the disk only after a
/// delay; a process that dies meanwhile loses the change.
abstract final class StorageFlush {
  static const channelName = 'io.vikunja.vikunja_storage_flush';

  @visibleForTesting
  static const channel = MethodChannel(channelName);

  /// Completes once every change to the SharedPreferences file [name] is on
  /// disk. Does nothing outside Android.
  static Future<void> flushSharedPreferences(String name) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await channel.invokeMethod<void>('flushSharedPreferences', {'name': name});
  }
}
