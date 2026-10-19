import 'package:flutter/foundation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

export 'package:vikunja_api/vikunja_api.dart' show AttachmentPreviewSize;

@immutable
final class AttachmentImage {
  const new({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// The response's media type, e.g. `image/png`; the server answers the
  /// original for what it cannot preview.
  final String contentType;

  bool get isSvg => contentType == 'image/svg+xml';
}

/// An image the app does not decode: more bytes or pixels than it allows.
final class AttachmentImageTooLarge implements Exception {
  const new();

  @override
  String toString() => 'AttachmentImageTooLarge';
}

/// Whether asking again may bring the image: not for a missing or
/// forbidden attachment, an answer the port refused or one too large.
bool attachmentImageFailureMayPass(Object failure) =>
    failure is! NotFound &&
    failure is! Forbidden &&
    failure is! UnexpectedResponse &&
    failure is! AttachmentImageTooLarge;

/// Authenticated attachment images of one account: previews of the list
/// (`medium`), inline images of descriptions and comments (`extraLarge`)
/// and originals for the full-screen viewer (null). Memory only, capped by
/// bytes, one request per image at a time; a failure is remembered for a
/// short time, except one that cannot pass (see
/// [attachmentImageFailureMayPass]) for the session. Throws the
/// `VikunjaFailure` of the request, or [AttachmentImageTooLarge].
abstract interface class AttachmentImages {
  Future<AttachmentImage> load(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  });

  /// The image when it is already in memory.
  AttachmentImage? peek(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  });

  /// Whether a [load] of the image would fail from memory right now.
  bool remembersFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  });

  /// Lets the next [load] of the image ask again after a failure that may
  /// pass, such as no connection.
  void forgetFailure(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  });

  /// [forgetFailure] for every image.
  void forgetFailures();
}
