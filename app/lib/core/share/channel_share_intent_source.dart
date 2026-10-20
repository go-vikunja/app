import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

final _log = Logger('ShareIntent');

/// Android's shares through `MainActivity`'s channel. The activity checks
/// every URI (only `content://` of other apps) and copies on a background
/// thread; the names it reports come from other apps and are made safe
/// here. A platform without the channel has no shares.
final class ChannelShareIntentSource implements ShareIntentSource {
  new({this._channel = const MethodChannel(channelName)}) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'dev.coderoftime.vikunja/share';

  final MethodChannel _channel;
  final _shares = StreamController<IncomingShare>.broadcast();

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'shared') {
      throw MissingPluginException('No method ${call.method}');
    }
    if (incomingShareFromChannel(call.arguments) case final share?
        when !_shares.isClosed) {
      _shares.add(share);
    }
    return null;
  }

  @override
  Future<IncomingShare?> pending() async {
    try {
      return incomingShareFromChannel(
        await _channel.invokeMethod<Object?>('pending'),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      _log.warning('Reading the pending share failed: ${error.code}');
      return null;
    }
  }

  @override
  Stream<IncomingShare> get shares => _shares.stream;

  @override
  Future<CopiedSharedFile> copy(String uri, {required int maxBytes}) async {
    final Map<String, Object?>? copied;
    try {
      copied = await _channel.invokeMapMethod<String, Object?>('copy', {
        'uri': uri,
        'maxBytes': maxBytes,
      });
    } on PlatformException catch (error) {
      if (error.code == 'too_large') {
        throw SharedFileTooLarge(maxBytes: maxBytes);
      }
      _log.info('A shared file could not be copied: ${error.code}');
      throw const SharedFileUnreadable();
    } on MissingPluginException {
      throw const SharedFileUnreadable();
    }
    return switch (copied) {
      {'path': final String path, 'size': final int size} => CopiedSharedFile(
        path: path,
        size: size,
      ),
      _ => throw const SharedFileUnreadable(),
    };
  }

  @override
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      _log.info('Clearing the share failed: ${error.code}');
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_shares.close());
  }
}

/// The longest shared text taken, in UTF-16 code units; the rest of a
/// shared article is cut off.
const int maxSharedTextLength = 100000;

/// A share as the channel reports it: `{subject, text, files: [{uri, name,
/// size, mime}]}`; null when it carries nothing usable. File names are
/// made safe to show and to send as an attachment name.
IncomingShare? incomingShareFromChannel(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  final files = [
    if (value['files'] case final List<Object?> files)
      for (final file in files)
        if (file case {'uri': final String uri} when uri.startsWith('content:'))
          SharedFile(
            uri: uri,
            displayName: safeFileName(switch (file['name']) {
              final String name => name,
              _ => '',
            }),
            size: switch (file['size']) {
              final int size when size >= 0 => size,
              _ => null,
            },
            mimeType: switch (file['mime']) {
              final String mime when mime.isNotEmpty => mime,
              _ => null,
            },
          ),
  ];
  final share = IncomingShare(
    subject: _text(value['subject'], 1000),
    text: _text(value['text'], maxSharedTextLength),
    files: files,
  );
  return share.isEmpty ? null : share;
}

String? _text(Object? value, int maxLength) => switch (value) {
  final String text when text.trim().isNotEmpty =>
    text.length > maxLength ? text.substring(0, maxLength) : text,
  _ => null,
};
