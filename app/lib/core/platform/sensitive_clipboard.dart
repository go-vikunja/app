import 'dart:io';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'sensitive_clipboard.g.dart';

/// Copies a secret, such as a new token, so that the system does not show
/// it: Android 13 and later preview copied text unless it is marked
/// sensitive. On iOS a plain copy until the iOS phase.
abstract interface class SensitiveClipboard {
  Future<void> copy(String text);
}

final class PlatformSensitiveClipboard implements SensitiveClipboard {
  new({this._channel = deviceChannel, bool? android})
    : _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  @override
  Future<void> copy(String text) async {
    if (_android) {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}

@Riverpod(keepAlive: true)
SensitiveClipboard sensitiveClipboard(Ref ref) => PlatformSensitiveClipboard();
