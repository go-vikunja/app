import 'dart:typed_data';
import 'dart:ui' as ui;

/// The most pixels an image the app decodes may have.
const int maxImagePixels = 40 * 1000 * 1000;

/// The pixels an encoded image decodes to, null when its header cannot be
/// read.
typedef ImagePixelCount = Future<int?> Function(Uint8List bytes);

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
