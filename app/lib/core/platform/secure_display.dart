import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'secure_display.g.dart';

final _log = Logger('SecureDisplay');

/// Android's `FLAG_SECURE` on the app's window: out of screenshots, screen
/// recordings and the Recents thumbnail. Nothing on iOS.
abstract interface class SecureWindow {
  // Like Android's own `SurfaceView.setSecure(boolean)`.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setSecure(bool secure);
}

final class PlatformSecureWindow implements SecureWindow {
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

/// The window is secure while [setAlways] is on (the Block screenshots
/// switch) or any [hold] is unreleased (a secret on screen), so neither
/// clears the other's protection.
final class SecureDisplay {
  new(this._window);

  final SecureWindow _window;
  var _always = false;
  var _holds = 0;
  var _applied = false;

  bool get isSecure => _always || _holds > 0;

  SecureHold hold() {
    _holds++;
    _apply();
    return SecureHold._(this);
  }

  // Reads like setSecure, which mirrors Android's own API.
  // ignore: avoid_positional_boolean_parameters
  void setAlways(bool always) {
    _always = always;
    _apply();
  }

  void _release() {
    _holds--;
    _apply();
  }

  // The channel delivers the calls in order, so the last one wins.
  void _apply() {
    final secure = isSecure;
    if (secure == _applied) return;
    _applied = secure;
    unawaited(
      _window
          .setSecure(secure)
          .then<void>(
            (_) {},
            onError: (Object error) => _log.info(
              'Screen protection unavailable: ${error.runtimeType}',
            ),
          ),
    );
  }
}

final class SecureHold {
  new _(this._display);

  final SecureDisplay _display;
  var _released = false;

  /// Only the first call counts.
  void release() {
    if (_released) return;
    _released = true;
    _display._release();
  }
}

@Riverpod(keepAlive: true)
SecureWindow secureWindow(Ref ref) => PlatformSecureWindow();

@Riverpod(keepAlive: true)
SecureDisplay secureDisplay(Ref ref) =>
    SecureDisplay(ref.watch(secureWindowProvider));
