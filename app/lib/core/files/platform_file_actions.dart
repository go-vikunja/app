import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

final _log = Logger('FileActions');

/// Android: "open with" and "save as" through `MainActivity`'s channel,
/// sharing through share_plus. iOS has no "open with" or document picker
/// of its own here: its share sheet offers "Open in…" and "Save to Files".
/// Leaving the app for any of them does not lock it.
final class PlatformFileActions implements FileActions {
  new({
    this._channel = const MethodChannel(channelName),
    bool? android,
    Future<ShareResult> Function(ShareParams params)? share,
    this._excursions,
  }) : _android = android ?? Platform.isAndroid,
       _share = share ?? SharePlus.instance.share;

  static const channelName = 'dev.coderoftime.vikunja/files';

  final MethodChannel _channel;
  final bool _android;
  final Future<ShareResult> Function(ShareParams params) _share;
  final AppExcursions? _excursions;

  @override
  Future<bool> openWith(
    File file, {
    required String mimeType,
    Rect? origin,
  }) async {
    if (!_android) {
      final result = await _shareFile(
        file,
        fileName: null,
        mimeType: mimeType,
        origin: origin,
      );
      return result.status != ShareResultStatus.unavailable;
    }
    // The other app opens and the channel answers at once.
    Future<bool> open() async =>
        await _channel.invokeMethod<bool>('openWith', {
          'path': file.path,
          'mime': plainMimeType(mimeType),
        }) ??
        false;
    final excursions = _excursions;
    if (excursions == null) return await open();
    return await excursions.launchAway(open, opened: (opened) => opened);
  }

  @override
  Future<bool> saveAs(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) async {
    if (!_android) {
      final result = await _shareFile(
        file,
        fileName: fileName,
        mimeType: mimeType,
        origin: origin,
      );
      return result.status == ShareResultStatus.success;
    }
    return await _roundTrip<bool?>(
          () => _channel.invokeMethod<bool>('saveAs', {
            'path': file.path,
            'name': fileName,
            'mime': plainMimeType(mimeType),
          }),
        ) ??
        false;
  }

  @override
  Future<void> share(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  }) async {
    final result = await _shareFile(
      file,
      fileName: fileName,
      mimeType: mimeType,
      origin: origin,
    );
    _log.fine('Shared a file: ${result.status.name}');
  }

  Future<ShareResult> _shareFile(
    File file, {
    required String? fileName,
    required String mimeType,
    required Rect? origin,
  }) => _roundTrip(
    () => _share(
      ShareParams(
        files: [XFile(file.path, mimeType: plainMimeType(mimeType))],
        fileNameOverrides: fileName == null ? null : [fileName],
        sharePositionOrigin: origin,
      ),
    ),
  );

  Future<T> _roundTrip<T>(Future<T> Function() action) =>
      _excursions?.roundTrip(action) ?? action();
}
