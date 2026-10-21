import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'secure_display.g.dart';

/// Keeps the screen out of screenshots, screen recordings and the Recents
/// thumbnail while a secret is visible (Android's `FLAG_SECURE` on the
/// app's window). Nothing on iOS until the iOS phase.
abstract interface class SecureDisplay {
  // Like Android's own `SurfaceView.setSecure(boolean)`.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setSecure(bool secure);
}

final class PlatformSecureDisplay implements SecureDisplay {
  new({this._channel = deviceChannel, bool? android})
    : _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  @override
  Future<void> setSecure(bool secure) async {
    if (!_android) return;
    await _channel.invokeMethod<void>('setSecure', {'secure': secure});
  }
}

@Riverpod(keepAlive: true)
SecureDisplay secureDisplay(Ref ref) => PlatformSecureDisplay();
