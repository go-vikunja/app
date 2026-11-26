import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/platform/location_removal.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';

final _log = Logger('ShareFiles');

sealed class ShareFileStatus {
  const new();
}

final class ShareFilePreparing extends ShareFileStatus {
  const new();
}

final class ShareFileReady extends ShareFileStatus {
  const new(this.copy, {this.keptLocation = false});

  final CopiedSharedFile copy;

  /// Its location could not be removed; the sheet says so, and the file
  /// goes only when the user chooses Upload when asked.
  final bool keptLocation;
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
/// with the server's limit, so that the sheet can say which can go; every
/// copy goes through the location removal before it is ready. At most
/// [maxFiles]; the rest are [leftOut]. A removed file is no longer copied,
/// and one removed while it copies has that copy called off, so the next
/// file does not wait for a sending app that never delivers; its copy goes
/// when the share is cleared.
final class ShareFilesController extends ValueNotifier<List<ShareFileItem>> {
  new({
    required this._source,
    required IncomingShare share,
    required this._uploadsEnabled,
    required this._maxBytes,
    this._locations,
  }) : _share = share,
       leftOut = share.files.length > maxFiles
           ? share.files.length - maxFiles
           : 0,
       super([
         for (final file in share.files.take(maxFiles))
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
  final IncomingShare _share;
  final LocationRemoval? _locations;
  final bool _uploadsEnabled;
  final int _maxBytes;
  final int leftOut;
  var _stopped = false;
  Future<void>? _preparing;
  ({String uri, Completer<Never> removed})? _copying;

  bool get preparing => value.any((item) => item.status is ShareFilePreparing);

  List<(ShareFileItem, CopiedSharedFile)> get ready => [
    for (final item in value)
      if (item.status case ShareFileReady(:final copy)) (item, copy),
  ];

  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    if (!_uploadsEnabled) return;
    for (final item in [...value]) {
      if (_stopped) return;
      if (item.status is! ShareFilePreparing) continue;
      if (!value.any((current) => current.file.uri == item.file.uri)) continue;
      final CopiedSharedFile copy;
      final removed = Completer<Never>();
      _copying = (uri: item.file.uri, removed: removed);
      try {
        copy = await Future.any([
          _source.copy(_share, item.file.uri, maxBytes: _maxBytes),
          removed.future,
        ]);
      } on SharedFileTooLarge catch (error) {
        _set(item.file, ShareFileTooLarge(error.maxBytes));
        continue;
      } on Object catch (error) {
        _log.info('Copying a shared file failed: ${error.runtimeType}');
        _set(item.file, const ShareFileUnreadable());
        continue;
      } finally {
        _copying = null;
      }
      if (_stopped) return;
      // Not by the other app's type, which can be generic: the platform
      // tells photos and videos apart by their content.
      final kept = await _locations?.removeFromAll([copy.path]);
      _set(
        item.file,
        ShareFileReady(copy, keptLocation: kept?.isNotEmpty ?? false),
      );
    }
  }

  void remove(SharedFile file) {
    if (_stopped) return;
    _cancelCopy(file.uri);
    value = [
      for (final item in value)
        if (item.file.uri != file.uri) item,
    ];
  }

  void _cancelCopy(String? onlyUri) {
    if (_copying case (:final uri, :final removed)?
        when onlyUri == null || uri == onlyUri) {
      _copying = null;
      removed.completeError(const SharedFileUnreadable());
      unawaited(_source.cancelCopy(_share, uri));
    }
  }

  void _set(SharedFile file, ShareFileStatus status) {
    if (_stopped) return;
    value = [
      for (final item in value)
        if (item.file.uri == file.uri)
          ShareFileItem(item.file, status)
        else
          item,
    ];
  }

  /// Calls off any pending copy, but waits for a location rewrite already
  /// using a returned path before the share can be cleared.
  Future<void> stopPreparing() {
    _stop();
    return _preparing ?? Future.value();
  }

  void _stop() {
    _stopped = true;
    _cancelCopy(null);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
