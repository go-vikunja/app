import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'app_backgrounding.g.dart';

/// Puts the app behind the screen it was opened from and keeps its state
/// (Android's `moveTaskToBack`), as a launcher's own setup step ends.
/// Nothing on iOS.
abstract interface class AppBackgrounding {
  Future<void> moveToBack();

  /// While [enabled], system back that the framework leaves to the
  /// platform moves the app to the back as well, instead of Android closing
  /// the activity.
  Future<void> setBackMovesToBack({required bool enabled});
}

final class PlatformAppBackgrounding implements AppBackgrounding {
  new({this._channel = deviceChannel, bool? android})
    : _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  @override
  Future<void> moveToBack() async {
    if (!_android) return;
    await _channel.invokeMethod<void>('moveTaskToBack');
  }

  @override
  Future<void> setBackMovesToBack({required bool enabled}) async {
    if (!_android) return;
    await _channel.invokeMethod<void>('setBackMovesTaskToBack', {
      'enabled': enabled,
    });
  }
}

@Riverpod(keepAlive: true)
AppBackgrounding appBackgrounding(Ref ref) => PlatformAppBackgrounding();
