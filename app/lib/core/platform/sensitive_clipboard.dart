import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';

part 'sensitive_clipboard.g.dart';

final _log = Logger('SensitiveClipboard');

/// Copies a secret, such as a new token or a share link, so that the
/// system shows and keeps as little of it as it can: Android 13 and later
/// preview copied text unless it is marked sensitive; on iOS the copy
/// stays on this device (no Universal Clipboard) and expires after two
/// minutes, or is a plain copy where the app's channel does not answer.
abstract interface class SensitiveClipboard {
  Future<void> copy(String text);
}

final class PlatformSensitiveClipboard implements SensitiveClipboard {
  new({this._channel = deviceChannel, bool? android, bool? ios})
    : _android = android ?? Platform.isAndroid,
      _ios = ios ?? Platform.isIOS;

  final MethodChannel _channel;
  final bool _android;
  final bool _ios;

  @override
  Future<void> copy(String text) async {
    if (_android) {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
      return;
    }
    if (_ios) {
      try {
        await _channel.invokeMethod<void>('copySensitive', {'text': text});
        return;
      } on Exception catch (error) {
        // A build without the channel, or the pasteboard refused.
        _log.warning('Copied plainly instead: ${error.runtimeType}');
      }
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}

@Riverpod(keepAlive: true)
SensitiveClipboard sensitiveClipboard(Ref ref) => PlatformSensitiveClipboard();
