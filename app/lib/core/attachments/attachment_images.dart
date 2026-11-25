import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/files/file_actions.dart' show plainMimeType;

export 'package:vikunja_api/vikunja_api.dart'
    show AttachmentPreviewSize, isNoAttachmentPreview;

@immutable
final class AttachmentImage {
  const new({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// The response's media type, e.g. `image/jpeg`; servers before 2.7.1
  /// answer a preview of what they cannot preview with the original.
  final String contentType;

  bool get isSvg => contentType == 'image/svg+xml';
}

/// An image the app does not decode: more bytes or pixels than it allows.
final class AttachmentImageTooLarge implements Exception {
  const new();

  @override
  String toString() => 'AttachmentImageTooLarge';
}

/// An answer that is no image the app draws (another type, SVG, or a header
/// it cannot read), remembered for the session without its bytes.
final class AttachmentNotAnImage implements Exception {
  const new();

  @override
  String toString() => 'AttachmentNotAnImage';
}

/// A page answered in the image's place, such as a Wi-Fi sign-in page in
/// front of a plain-http server or a login or maintenance page served as a
/// success.
final class AttachmentImagePageInstead implements Exception {
  const new();

  @override
  String toString() => 'AttachmentImagePageInstead';
}

/// The attachment images a description or comment loads by itself, in
/// the task sheet and in the editor; anyone who can write in the project
/// can name any number of the server's files in one text, each fetched
/// with the user's session (decision log: Descriptions, comments,
/// attachments).
const int maxImagesByThemselves = 10;

/// The largest image whose original stands in by itself for a preview the
/// server has none of (decision log: Descriptions, comments, attachments).
const int maxStandInBytes = 8 * 1024 * 1024;

/// Whether [attachment] is listed as an image the app draws.
bool listsDrawableImage(TaskAttachment attachment) {
  final type = plainMimeType(attachment.mime);
  return type.startsWith('image/') && type != 'image/svg+xml';
}

/// Whether [attachment] is listed as something the app does not draw as an
/// image, so it is never asked for. A listing without a type (none, or
/// `application/octet-stream`) names nothing, as for an attachment the
/// list does not have: the server may still have a preview of it.
bool listsNoImage(TaskAttachment attachment) =>
    plainMimeType(attachment.mime) != 'application/octet-stream' &&
    !listsDrawableImage(attachment);

/// Whether the original of [attachment] may stand in by itself for a
/// missing preview: an image the task's list names, of at most
/// [maxStandInBytes].
bool originalStandsIn(TaskAttachment? attachment) =>
    attachment != null &&
    listsDrawableImage(attachment) &&
    attachment.size > 0 &&
    attachment.size <= maxStandInBytes;

/// Whether asking again may bring the image: not for a missing or
/// forbidden attachment, an answer the port refused, one too large or no
/// image, nor for a preview the server says it has none of. A redirect,
/// which the client does not follow, is a proxy's or a portal's, not the
/// server's.
bool attachmentImageFailureMayPass(Object failure) => switch (failure) {
  NotFound() ||
  Forbidden() ||
  AttachmentImageTooLarge() ||
  AttachmentNotAnImage() => false,
  UnexpectedResponse(:final statusCode?)
      when statusCode >= 300 && statusCode < 400 =>
    true,
  UnexpectedResponse() => false,
  _ => !isNoAttachmentPreview(failure),
};

/// Authenticated attachment images of one account: previews of the list
/// (`medium`), inline images of descriptions and comments (`extraLarge`)
/// and originals for the full-screen viewer (null). In memory, capped by
/// bytes, one request per image at a time, and kept on disk for when the
/// server cannot be asked; a failure is remembered for a short time,
/// except one that cannot pass (see [attachmentImageFailureMayPass]) for
/// the session. Throws the `VikunjaFailure` of the request,
/// [AttachmentImageTooLarge], [AttachmentNotAnImage] or
/// [AttachmentImagePageInstead].
abstract interface class AttachmentImages {
  /// A [cancel] gives up this load: it ends at once with dio's cancel, and
  /// the request is cancelled once no load waits for it.
  Future<AttachmentImage> load(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
    CancelToken? cancel,
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

  /// Drops every size of an attachment deleted in the app, in memory and
  /// on disk; what a request still running brings back is not kept.
  Future<void> drop(int taskId, int attachmentId);
}
