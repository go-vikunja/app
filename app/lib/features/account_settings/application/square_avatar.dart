import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Matrix4;

/// The server keeps avatars at most this many pixels wide.
const avatarMaxSide = 1024;

/// A picture far larger than any avatar is decoded smaller, which keeps a
/// camera photo's memory in bounds and still leaves room to zoom in.
const _maxDecodedSide = 4096;

/// [bytes] decoded with the photo's orientation applied, at most 4096
/// pixels on its longer side; throws when it is no picture this device can
/// decode.
Future<ui.Image> decodeAvatarSource(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final longer = math.max(width, height);
      if (longer <= _maxDecodedSide) return const ui.TargetImageSize();
      final scale = _maxDecodedSide / longer;
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// The largest square in the middle of a [width] × [height] picture.
ui.Rect centreSquare(int width, int height) {
  final side = math.min(width, height).toDouble();
  return ui.Rect.fromLTWH((width - side) / 2, (height - side) / 2, side, side);
}

/// The part of a [imageWidth] × [imageHeight] picture a square viewport of
/// [viewportSide] shows, when the picture covers the viewport at scale 1
/// and [transform] is the viewer's pan and zoom; in the picture's pixels.
ui.Rect cropInViewport({
  required Matrix4 transform,
  required double viewportSide,
  required int imageWidth,
  required int imageHeight,
}) {
  final cover = viewportSide / math.min(imageWidth, imageHeight);
  final zoom = transform.getMaxScaleOnAxis();
  final translation = transform.getTranslation();
  final scale = cover * zoom;
  final side = math.min(
    viewportSide / scale,
    math.min(imageWidth, imageHeight).toDouble(),
  );
  final left = (-translation.x / scale).clamp(0, imageWidth - side).toDouble();
  final top = (-translation.y / scale).clamp(0, imageHeight - side).toDouble();
  return ui.Rect.fromLTWH(left, top, side, side);
}

/// [crop] of [image] as a PNG of at most [avatarMaxSide] pixels a side,
/// what the web uploads too.
Future<Uint8List> encodeSquareAvatar(ui.Image image, ui.Rect crop) async {
  final side = math.max(1, math.min(crop.width.round(), avatarMaxSide));
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    crop,
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final square = await picture.toImage(side, side);
  picture.dispose();
  try {
    final data = await square.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('The avatar could not be encoded');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    square.dispose();
  }
}
