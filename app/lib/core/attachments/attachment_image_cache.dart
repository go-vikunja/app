import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/image_disk_cache.dart';
import 'package:vikunja_mobile/core/attachments/image_pixels.dart';

final _log = Logger('AttachmentImages');

typedef AttachmentFetch = Future<AttachmentBlob> Function(
  int taskId,
  int attachmentId,
  AttachmentPreviewSize? preview,
);

typedef _Key = (int taskId, int attachmentId, AttachmentPreviewSize? preview);

const int _megabyte = 1024 * 1024;

const _noPreview = DomainError(422, code: 4038);

/// [AttachmentImages] in memory: the most recently used images up to
/// [maxBytes] together, one request per image at a time. A failure that
/// may pass (no connection, a server error) is answered from memory for
/// [retryAfter]; a missing or forbidden attachment, an answer the port
/// could not take (one larger than its limit among them), one larger
/// than [maxImageBytes] and an image of more than [maxPixels] for the
/// session.
///
/// Behind it, an [ImageDiskCache] keeps every size loaded from the server:
/// written after the load, read when a failure may pass or when the
/// server answers with no image while a copy is kept (a login or
/// maintenance page in front of it; attachments never change). Where the
/// disk keeps the original but not the `xl` preview, the original stands
/// in, as for a preview the server has none of, until [retryAfter].
final class AttachmentImageCache implements AttachmentImages {
  new(
    this._fetch, {
    this.maxBytes = 32 * _megabyte,
    this.maxImageBytes = maxAttachmentBytes,
    this.maxPixels = maxImagePixels,
    this.retryAfter = const Duration(minutes: 2),
    this._disk,
    ImagePixelCount? pixelsOf,
    DateTime Function()? now,
  }) : _pixelsOf = pixelsOf ?? encodedImagePixels,
       _now = now ?? DateTime.now;

  final AttachmentFetch _fetch;
  final ImageDiskCache? _disk;
  final int maxBytes;
  final int maxImageBytes;

  /// A small PNG or GIF can decode to gigabytes: the codecs scale only
  /// JPEG and WebP down while decoding.
  final int maxPixels;
  final Duration retryAfter;
  final ImagePixelCount _pixelsOf;
  final DateTime Function() _now;
  final _images = <_Key, AttachmentImage>{};
  final _failures = <_Key, ({Object error, DateTime? retryAt})>{};
  final _inFlight = <_Key, Future<AttachmentImage>>{};
  final _dropped = <(int, int)>{};
  var _bytes = 0;
  var _generation = 0;

  int get cachedBytes => _bytes;

  @override
  AttachmentImage? peek(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    final image = _images.remove(key);
    if (image != null) _images[key] = image;
    return image;
  }

  @override
  Future<AttachmentImage> load(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    if (peek(taskId, attachmentId, preview: preview) case final image?) {
      return Future.value(image);
    }
    final key = (taskId, attachmentId, preview);
    if (_failures[key] case (:final error, :final retryAt)) {
      if (retryAt == null || _now().isBefore(retryAt)) {
        return Future.error(error);
      }
      _failures.remove(key);
    }
    if (_inFlight[key] case final running?) return running;
    late final Future<AttachmentImage> download;
    download = _download(key).whenComplete(() {
      if (identical(_inFlight[key], download)) unawaited(_inFlight.remove(key));
    });
    return _inFlight[key] = download;
  }

  @override
  bool remembersFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final failure = _failures[(taskId, attachmentId, preview)];
    if (failure == null) return false;
    final retryAt = failure.retryAt;
    return retryAt == null || _now().isBefore(retryAt);
  }

  @override
  void forgetFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) {
    final key = (taskId, attachmentId, preview);
    if (_failures[key]?.retryAt != null) _failures.remove(key);
  }

  @override
  void forgetFailures() =>
      _failures.removeWhere((_, failure) => failure.retryAt != null);

  @override
  Future<void> drop(int taskId, int attachmentId) async {
    bool ofIt(_Key key) => key.$1 == taskId && key.$2 == attachmentId;
    for (final key in [..._images.keys.where(ofIt)]) {
      _bytes -= _images.remove(key)!.bytes.length;
    }
    _failures.removeWhere((key, _) => ofIt(key));
    _inFlight.removeWhere((key, _) => ofIt(key));
    _dropped.add((taskId, attachmentId));
    await _disk?.removeStartingWith(_diskPrefix(taskId, attachmentId));
  }

  /// Forgets everything, also what a request still running brings back.
  void clear() {
    _images.clear();
    _failures.clear();
    _inFlight.clear();
    _dropped.clear();
    _bytes = 0;
    _generation++;
  }

  Future<AttachmentImage> _download(_Key key) async {
    final generation = _generation;
    final (taskId, attachmentId, preview) = key;
    AttachmentImage image;
    var kept = false;
    try {
      final blob = await _fetch(taskId, attachmentId, preview);
      image = AttachmentImage(bytes: blob.bytes, contentType: blob.contentType);
    } on Object catch (error) {
      _log.fine('Attachment image unavailable: ${error.runtimeType}');
      final stored = attachmentImageFailureMayPass(error)
          ? await _stored(key, generation)
          : null;
      if (stored == null) {
        if (generation == _generation) _failed(key, error);
        rethrow;
      }
      image = stored;
      kept = true;
    }
    var pixels = _decodable(image) ? await _pixelsOf(image.bytes) : null;
    if (pixels == null && !kept) {
      if (await _stored(key, generation) case final stored?) {
        image = stored;
        kept = true;
        pixels = await _pixelsOf(stored.bytes);
      }
    }
    if (image.bytes.length > maxImageBytes || (pixels ?? 0) > maxPixels) {
      const tooLarge = AttachmentImageTooLarge();
      if (generation == _generation) _fail(key, tooLarge, passes: false);
      throw tooLarge;
    }
    if (generation == _generation &&
        !_dropped.contains((taskId, attachmentId))) {
      _remember(key, image);
      if (!kept) {
        unawaited(_disk?.write(_onDisk(key), image, unchanging: true));
      }
    }
    return image;
  }

  /// The copy on disk. For an `xl` preview the disk lacks while it keeps a
  /// readable original, throws a no-preview failure, so the original
  /// stands in.
  Future<AttachmentImage?> _stored(_Key key, int generation) async {
    final disk = _disk;
    if (disk == null || generation != _generation) return null;
    if (await disk.read(_onDisk(key)) case final image?) return image;
    final (taskId, attachmentId, preview) = key;
    if (preview != AttachmentPreviewSize.extraLarge) return null;
    final originalKey = (taskId, attachmentId, null);
    final original = await disk.read(_onDisk(originalKey));
    if (original == null || generation != _generation) return null;
    if (!_dropped.contains((taskId, attachmentId))) {
      _remember(originalKey, original);
      // For the session, as the server's own answer: one that may pass
      // would put the loading box over the original at every retry.
      _fail(key, _noPreview, passes: false);
    }
    throw _noPreview;
  }

  static String _diskPrefix(int taskId, int attachmentId) =>
      'attachment-$taskId-$attachmentId-';

  static String _onDisk(_Key key) {
    final (taskId, attachmentId, preview) = key;
    return '${_diskPrefix(taskId, attachmentId)}'
        '${preview?.wireName ?? 'original'}';
  }

  void _failed(_Key key, Object error) {
    _fail(key, error, passes: attachmentImageFailureMayPass(error));
    if (error is NotFound || error is Forbidden) {
      final (taskId, attachmentId, _) = key;
      unawaited(_disk?.removeStartingWith(_diskPrefix(taskId, attachmentId)));
    }
  }

  static bool _decodable(AttachmentImage image) =>
      image.contentType.startsWith('image/') && !image.isSvg;

  void _fail(_Key key, Object error, {required bool passes}) => _failures[key] =
      (error: error, retryAt: passes ? _now().add(retryAfter) : null);

  void _remember(_Key key, AttachmentImage image) {
    final size = image.bytes.length;
    if (size > maxBytes) return;
    _images[key] = image;
    _bytes += size;
    while (_bytes > maxBytes) {
      final oldest = _images.keys.first;
      _bytes -= _images.remove(oldest)!.bytes.length;
    }
  }
}
