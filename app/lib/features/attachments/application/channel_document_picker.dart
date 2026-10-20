import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/attachments/application/attachment_picker.dart';

final _log = Logger('DocumentPicker');

/// Android's document picker through `MainActivity`'s channel, in place of
/// file_selector, which reads every picked file whole into memory on the
/// main thread. The activity reports the picked files first; only the
/// ones not known to be above the limit are copied, capped and off the
/// main thread, into the app's cache. Names come from other apps and are
/// made safe here.
final class ChannelDocumentPicker {
  new({this._channel = const MethodChannel(channelName)});

  static const channelName = 'dev.coderoftime.vikunja/documents';

  final MethodChannel _channel;

  Future<PickedFiles> pick({
    required int maxBytes,
    required bool imagesOnly,
    required bool multiple,
  }) async {
    final described =
        await _channel.invokeListMethod<Object?>('pick', {
          'imagesOnly': imagesOnly,
          'multiple': multiple,
        }) ??
        const [];
    final files = <PickedFile>[];
    final tooLarge = <String>[];
    final failed = <String>[];
    for (final entry in described) {
      if (entry case {
        'uri': final String uri,
        'name': final String? rawName,
        'size': final int? size,
        'mime': final String? mimeType,
      }) {
        final name = safeFileName(rawName ?? '');
        if (size != null && size > maxBytes) {
          tooLarge.add(name);
          continue;
        }
        try {
          final copied = await _channel.invokeMapMethod<String, Object?>(
            'copy',
            {'uri': uri, 'maxBytes': maxBytes},
          );
          if (copied case {'path': final String path}) {
            files.add(PickedFile(path: path, name: name, mimeType: mimeType));
          } else {
            failed.add(name);
          }
        } on PlatformException catch (error) {
          if (error.code == 'too_large') {
            tooLarge.add(name);
          } else {
            _log.info('A picked file could not be copied: ${error.code}');
            failed.add(name);
          }
        }
      }
    }
    return PickedFiles(files: files, tooLarge: tooLarge, failed: failed);
  }
}
