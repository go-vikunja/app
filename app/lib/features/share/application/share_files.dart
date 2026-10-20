import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

final _log = Logger('ShareFiles');

sealed class ShareFileStatus {
  const new();
}

final class ShareFilePreparing extends ShareFileStatus {
  const new();
}

final class ShareFileReady extends ShareFileStatus {
  const new(this.copy);

  final CopiedSharedFile copy;
}

final class ShareFileTooLarge extends ShareFileStatus {
  const new(this.maxBytes);

  final int maxBytes;
}

final class ShareFileUnreadable extends ShareFileStatus {
  const new();
}

/// The account's server takes no attachments.
final class ShareFileNotTaken extends ShareFileStatus {
  const new();
}

@immutable
final class ShareFileItem {
  const new(this.file, this.status);

  final SharedFile file;
  final ShareFileStatus status;

  /// The other app's name for it, made safe to show and to send.
  String get name => safeFileName(file.displayName);
}

/// The files of a share, copied one after the other into the share inbox
/// with the server's limit, so that the sheet can say which can go. At
/// most [maxFiles]; the rest are [leftOut]. A removed file is no longer
/// copied; its copy goes when the share is cleared.
final class ShareFilesController extends ValueNotifier<List<ShareFileItem>> {
  new({
    required this._source,
    required List<SharedFile> files,
    required this._uploadsEnabled,
    required this._maxBytes,
  }) : leftOut = files.length > maxFiles ? files.length - maxFiles : 0,
       super([
         for (final file in files.take(maxFiles))
           ShareFileItem(
             file,
             !_uploadsEnabled
                 ? const ShareFileNotTaken()
                 : (file.size ?? 0) > _maxBytes
                 ? ShareFileTooLarge(_maxBytes)
                 : const ShareFilePreparing(),
           ),
       ]);

  static const maxFiles = 20;

  final ShareIntentSource _source;
  final bool _uploadsEnabled;
  final int _maxBytes;
  final int leftOut;
  var _disposed = false;

  bool get preparing => value.any((item) => item.status is ShareFilePreparing);

  List<(ShareFileItem, CopiedSharedFile)> get ready => [
    for (final item in value)
      if (item.status case ShareFileReady(:final copy)) (item, copy),
  ];

  Future<void> prepare() async {
    if (!_uploadsEnabled) return;
    for (final item in [...value]) {
      if (_disposed) return;
      if (item.status is! ShareFilePreparing) continue;
      if (!value.any((current) => current.file.uri == item.file.uri)) continue;
      final ShareFileStatus status;
      try {
        status = ShareFileReady(
          await _source.copy(item.file.uri, maxBytes: _maxBytes),
        );
      } on SharedFileTooLarge catch (error) {
        _set(item.file, ShareFileTooLarge(error.maxBytes));
        continue;
      } on Object catch (error) {
        _log.info('Copying a shared file failed: ${error.runtimeType}');
        _set(item.file, const ShareFileUnreadable());
        continue;
      }
      _set(item.file, status);
    }
  }

  void remove(SharedFile file) {
    if (_disposed) return;
    value = [
      for (final item in value)
        if (item.file.uri != file.uri) item,
    ];
  }

  void _set(SharedFile file, ShareFileStatus status) {
    if (_disposed) return;
    value = [
      for (final item in value)
        if (item.file.uri == file.uri)
          ShareFileItem(item.file, status)
        else
          item,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
