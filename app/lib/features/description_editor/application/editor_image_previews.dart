import 'dart:convert';
import 'dart:ui' as ui;

import 'package:logging/logging.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show parseAttachmentUrl;
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';

final _log = Logger('EditorImagePreviews');

/// The previews of a document's attachment images for one load of the
/// editor page, loaded by the app with the account's session, as the page
/// itself loads nothing (D52). Each image is sent once, at the preview size
/// the detail sheet shows, its original where the server has no preview;
/// an image that cannot be had keeps its placeholder.
final class EditorImagePreviews {
  new({
    required this._images,
    required this._apiRoot,
    this.maxTotalChars = 16 * 1024 * 1024,
  });

  final AttachmentImages _images;
  final Uri _apiRoot;

  /// What one page load gets in all; the images after it keep their
  /// placeholders.
  final int maxTotalChars;

  final _sent = <String>{};
  var _total = 0;

  /// Loads the images of [urls] not sent yet and hands each to [send] as
  /// it arrives.
  Future<void> provide(
    List<String> urls,
    Future<void> Function(Map<String, String> previews) send,
  ) async {
    for (final url in urls) {
      if (!_sent.add(url)) continue;
      final attachment = parseAttachmentUrl(url, apiRoot: _apiRoot);
      if (attachment == null) continue;
      final preview = await _preview(
        attachment.taskId,
        attachment.attachmentId,
      );
      if (preview == null) continue;
      if (_total + preview.length > maxTotalChars) {
        _log.info('Image previews over the budget are left out');
        return;
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
/// raster image of at most [maxBytes] as it came, a larger one decoded at
/// most [maxWidth] wide as PNG, and null for an SVG or what does not
/// decode.
Future<String?> editorPreviewDataUrl(
  AttachmentImage image, {
  int maxBytes = 1024 * 1024,
  int maxWidth = 1024,
}) async {
  if (image.isSvg) return null;
  if (_passedAsIs.contains(image.contentType) &&
      image.bytes.length <= maxBytes) {
    return 'data:${image.contentType};base64,${base64Encode(image.bytes)}';
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
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
