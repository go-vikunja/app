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
}

@Riverpod(keepAlive: true)
AppBackgrounding appBackgrounding(Ref ref) => PlatformAppBackgrounding();
