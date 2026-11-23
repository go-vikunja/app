import 'dart:convert';
import 'dart:ui' as ui;

import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show parseAttachmentUrl;
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';

final _log = Logger('EditorImagePreviews');

/// The previews of a document's attachment images for one load of the
/// editor page, loaded by the app with the account's session, as the page
/// itself loads nothing (decision log: Descriptions, comments, attachments).
/// An image counts under any of the roots given (the server root and
/// `/info`'s `frontend_url`), and is loaded by its ids, never from its
/// address.
/// Each image is sent once, at the preview size the detail sheet shows, its
/// original where the server has no preview; an image that cannot be had keeps
/// its placeholder. [close] ends it with the page load.
final class EditorImagePreviews {
  new({
    required this._images,
    required this._roots,
    this.maxTotalChars = 16 * 1024 * 1024,
  });

  final AttachmentImages _images;
  final List<Uri> _roots;

  /// What one page load gets in all; an image that would go past it keeps
  /// its placeholder.
  final int maxTotalChars;

  final _sent = <String>{};
  var _total = 0;
  var _closed = false;

  /// Loads nothing more and sends nothing more, also of a load running.
  void close() => _closed = true;

  /// Loads the images of [urls] not sent yet and hands each to [send] as
  /// it arrives.
  Future<void> provide(
    List<String> urls,
    Future<void> Function(Map<String, String> previews) send,
  ) async {
    for (final url in urls) {
      if (_closed) return;
      if (!_sent.add(url)) continue;
      final attachment = parseAttachmentUrl(url, roots: _roots);
      if (attachment == null) continue;
      final preview = await _preview(
        attachment.taskId,
        attachment.attachmentId,
      );
      if (_closed) return;
      if (preview == null) continue;
      if (_total + preview.length > maxTotalChars) {
        _log.info('An image preview over the budget is left out');
        continue;
      }
      _total += preview.length;
      await send({url: preview});
    }
  }

  Future<String?> _preview(int taskId, int attachmentId) async {
    try {
      final AttachmentImage image;
      try {
        image = await _images.load(
          taskId,
          attachmentId,
          preview: AttachmentPreviewSize.extraLarge,
        );
      } on Object catch (failure) {
        if (!isNoAttachmentPreview(failure)) rethrow;
        return await editorPreviewDataUrl(
          await _images.load(taskId, attachmentId),
        );
      }
      return await editorPreviewDataUrl(image);
    } on Object catch (failure) {
      _log.info('No preview for the editor: ${failure.runtimeType}');
      return null;
    }
  }
}

const _passedAsIs = {'image/png', 'image/jpeg', 'image/gif', 'image/webp'};

/// [image] as a `data:` URL the page's content security policy allows: a
/// PNG, JPEG, GIF or WebP as it came when it is at most [maxBytes] or at
/// most [maxWidth] wide, else decoded [maxWidth] wide as PNG; another image
/// type decoded as PNG at most [maxWidth] wide; null for an SVG, what is no
/// image and what does not decode.
Future<String?> editorPreviewDataUrl(
  AttachmentImage image, {
  int maxBytes = 1024 * 1024,
  int maxWidth = 1024,
}) async {
  // The cache counts the pixels of `image/*` only; anything else could
  // decode to gigabytes.
  if (!image.contentType.startsWith('image/') || image.isSvg) return null;
  final passable = _passedAsIs.contains(image.contentType);
  if (passable && image.bytes.length <= maxBytes) return _asIs(image);
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      // As a PNG of the same width it would be no smaller.
      if (passable && descriptor.width <= maxWidth) return _asIs(image);
      final codec = await descriptor.instantiateCodec(
        targetWidth: descriptor.width > maxWidth ? maxWidth : null,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final png = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (png == null) return null;
          return 'data:image/png;base64,'
              '${base64Encode(png.buffer.asUint8List())}';
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

String _asIs(AttachmentImage image) =>
    'data:${image.contentType};base64,${base64Encode(image.bytes)}';
