import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'recents_screenshots.g.dart';

/// Android 13's `Activity.setRecentsScreenshotEnabled`: with false the
/// Recents screen shows the window background instead of the app, while
/// the user's own screenshots keep working.
abstract interface class RecentsScreenshots {
  /// Whether the system applied it; false below Android 13 and on iOS.
  // ignore: avoid_positional_boolean_parameters
  Future<bool> setEnabled(bool enabled);
}

final class PlatformRecentsScreenshots implements RecentsScreenshots {
  new({this._channel = deviceChannel, bool? android})
    : _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  @override
  Future<bool> setEnabled(bool enabled) async {
    if (!_android) return false;
    final applied = await _channel.invokeMethod<bool>(
      'setRecentsScreenshotEnabled',
      {'enabled': enabled},
    );
    return applied ?? false;
  }
}

@Riverpod(keepAlive: true)
RecentsScreenshots recentsScreenshots(Ref ref) => PlatformRecentsScreenshots();

/// Whether the system itself keeps the app out of the Recents screen while
/// the app lock is on (Android 13+), as [RecentsScreenshots.setEnabled]
/// last answered; the lock then needs no cover of its own. False until it
/// answered, so the cover stands in.
@Riverpod(keepAlive: true)
class RecentsHiddenNatively extends _$RecentsHiddenNatively {
  @override
  bool build() => false;

  bool get hidden => state;

  set hidden(bool hidden) => state = hidden;
}
