import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';

final _log = Logger('AttachmentImages');

typedef AttachmentFetch = Future<AttachmentBlob> Function(
  int taskId,
  int attachmentId,
  AttachmentPreviewSize? preview,
);

/// The pixels an encoded image decodes to, null when its header cannot be
/// read.
typedef ImagePixelCount = Future<int?> Function(Uint8List bytes);

typedef _Key = (int taskId, int attachmentId, AttachmentPreviewSize? preview);

const int _megabyte = 1024 * 1024;

/// [AttachmentImages] in memory: the most recently used images up to
/// [maxBytes] together, one request per image at a time. A failure that
/// may pass (no connection, a server error) is answered from memory for
/// [retryAfter]; a missing or forbidden attachment, an answer the port
/// could not take (one larger than its limit among them), one larger
/// than [maxImageBytes] and an image of more than [maxPixels] for the
/// session.
final class AttachmentImageCache implements AttachmentImages {
  new(
    this._fetch, {
    this.maxBytes = 32 * _megabyte,
    this.maxImageBytes = maxAttachmentBytes,
    this.maxPixels = 40 * 1000 * 1000,
    this.retryAfter = const Duration(minutes: 2),
    ImagePixelCount? pixelsOf,
    DateTime Function()? now,
  }) : _pixelsOf = pixelsOf ?? encodedImagePixels,
       _now = now ?? DateTime.now;

  final AttachmentFetch _fetch;
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

  /// Forgets everything, also what a request still running brings back.
  void clear() {
    _images.clear();
    _failures.clear();
    _inFlight.clear();
    _bytes = 0;
    _generation++;
  }

  Future<AttachmentImage> _download(_Key key) async {
    final generation = _generation;
    final (taskId, attachmentId, preview) = key;
    final AttachmentBlob blob;
    try {
      blob = await _fetch(taskId, attachmentId, preview);
    } on Object catch (error) {
      _log.fine('Attachment image unavailable: ${error.runtimeType}');
      if (generation == _generation) {
        _fail(key, error, passes: attachmentImageFailureMayPass(error));
      }
      rethrow;
    }
    if (blob.bytes.length > maxImageBytes ||
        (_decodable(blob) && (await _pixelsOf(blob.bytes) ?? 0) > maxPixels)) {
      const tooLarge = AttachmentImageTooLarge();
      if (generation == _generation) _fail(key, tooLarge, passes: false);
      throw tooLarge;
    }
    final image = AttachmentImage(
      bytes: blob.bytes,
      contentType: blob.contentType,
    );
    if (generation == _generation) _remember(key, image);
    return image;
  }

  static bool _decodable(AttachmentBlob blob) =>
      blob.contentType.startsWith('image/') && !blob.isSvg;

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

/// Reads only the header of [bytes], decoding nothing.
Future<int?> encodedImagePixels(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final pixels = descriptor.width * descriptor.height;
    descriptor.dispose();
    return pixels;
  } on Object {
    return null;
  } finally {
    buffer.dispose();
  }
}
