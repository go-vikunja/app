import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'secure_display.g.dart';

final _log = Logger('SecureDisplay');

/// Android's `FLAG_SECURE` on the app's window: out of screenshots, screen
/// recordings and the Recents thumbnail. iOS cannot keep a window out of a
/// recording or a mirrored display; there the secure window says whether
/// the screen is captured, and a secret's widget hides it meanwhile.
abstract interface class SecureWindow {
  /// Resolves to whether the screen is captured now; always false where
  /// the window keeps itself out of captures.
  // Like Android's own `SurfaceView.setSecure(boolean)`.
  // ignore: avoid_positional_boolean_parameters
  Future<bool> setSecure(bool secure);

  /// Each change of whether the screen is captured while the window is
  /// secure; null where the window keeps itself out of captures.
  Stream<bool>? get captures;
}

final class PlatformSecureWindow implements SecureWindow {
  new({this._channel = deviceChannel, bool? android, bool? ios})
    : _android = android ?? Platform.isAndroid,
      _ios = ios ?? Platform.isIOS {
    if (_ios) _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final bool _android;
  final bool _ios;
  final _captures = StreamController<bool>.broadcast();

  @override
  Stream<bool>? get captures => _ios ? _captures.stream : null;

  @override
  Future<bool> setSecure(bool secure) async {
    if (_android) {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } else if (_ios) {
      final captured = await _channel.invokeMethod<bool>('setSecure', {
        'secure': secure,
      });
      return captured ?? false;
    }
    return false;
  }

  // The device channel's only call into Dart.
  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'screenCaptureChanged') {
      throw MissingPluginException();
    }
    if (call.arguments case final bool captured) _captures.add(captured);
  }
}

/// The window is secure while [setAlways] is on (the Block screenshots
/// switch) or any [hold] is unreleased (a secret on screen), so neither
/// clears the other's protection. Listeners hear when [hidesSecrets] or
/// [screenCaptured] changed.
final class SecureDisplay with ChangeNotifier {
  new(this._window) : _watchesCaptures = _window.captures != null {
    _captureChanges = _window.captures?.listen(_captureChanged);
    _lifecycle = _watchesCaptures
        ? AppLifecycleListener(onStateChange: _lifecycleChanged)
        : null;
  }

  final SecureWindow _window;
  final bool _watchesCaptures;
  late final StreamSubscription<bool>? _captureChanges;
  late final AppLifecycleListener? _lifecycle;
  var _always = false;
  var _holds = 0;
  var _applied = false;
  var _calls = 0;
  var _away = false;

  /// Null until the window answered the last change.
  bool? _captured;

  bool get isSecure => _always || _holds > 0;

  /// Whether a secret on screen must not show: the window does not keep
  /// itself out of captures (iOS) and the screen is captured, the app is
  /// not resumed, or the window has not said since the app was last
  /// resumed that the screen is not captured.
  bool get hidesSecrets => isSecure && _watchesCaptures && _captured != false;

  /// Whether the window said the screen is captured while it is secure.
  bool get screenCaptured => isSecure && _captured == true;

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

  void _apply() {
    final secure = isSecure;
    if (secure == _applied) return;
    _applied = secure;
    _ask();
  }

  // The channel delivers the calls and their answers in order, so the
  // last call wins. Listeners hear only answers and the app leaving, never
  // a change made while a widget builds or is disposed.
  void _ask() {
    final secure = _applied;
    _captured = null;
    final call = ++_calls;
    bool answers() => call == _calls && secure && _watchesCaptures && !_away;
    unawaited(
      _window
          .setSecure(secure)
          .then<void>(
            (captured) {
              if (answers()) _setCaptured(captured);
            },
            onError: (Object error) {
              _log.info('Screen protection unavailable: ${error.runtimeType}');
              // Hidden for good, a new token would be lost to its owner.
              if (answers()) _setCaptured(false);
            },
          ),
    );
  }

  // iOS takes the app switcher's snapshot after the app left, and shows it
  // and the last frame when the app comes back, before a capture that
  // started meanwhile is heard of, if it is heard of at all.
  void _lifecycleChanged(AppLifecycleState state) {
    final away = state != AppLifecycleState.resumed;
    if (away == _away) return;
    _away = away;
    if (!_applied) return;
    if (!away) {
      _ask();
    } else if (_captured != null) {
      _captured = null;
      notifyListeners();
    }
  }

  // A change heard before the last call's answer is older than that
  // answer.
  void _captureChanged(bool captured) {
    if (_applied && _captured != null) _setCaptured(captured);
  }

  void _setCaptured(bool captured) {
    if (captured == _captured) return;
    _captured = captured;
    notifyListeners();
  }

  @override
  void dispose() {
    // An answer still on its way finds no listeners to tell.
    _calls++;
    unawaited(_captureChanges?.cancel());
    _lifecycle?.dispose();
    super.dispose();
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
SecureDisplay secureDisplay(Ref ref) {
  final display = SecureDisplay(ref.watch(secureWindowProvider));
  ref.onDispose(display.dispose);
  return display;
}
