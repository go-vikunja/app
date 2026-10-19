/// The web's `attachmentPreview.ts`, all case-insensitive on name and mime.
enum AttachmentPreviewKind { image, pdf, video }

const _imageExtensions = ['.jpeg', '.jpg', '.png', '.bmp', '.gif'];

/// Extension `.jpeg|.jpg|.png|.bmp|.gif`, mime `image/*` other than
/// `image/svg+xml`: the server makes a PNG preview and the app can draw it.
bool canPreviewImage(String name, String mime) {
  final lowerName = name.toLowerCase();
  final lowerMime = mime.toLowerCase();
  return _imageExtensions.any(lowerName.endsWith) &&
      lowerMime.startsWith('image/') &&
      lowerMime != 'image/svg+xml';
}

/// Extension `.pdf` and mime `application/pdf`.
bool canPreviewPdf(String name, String mime) =>
    name.toLowerCase().endsWith('.pdf') &&
    mime.toLowerCase() == 'application/pdf';

/// Mime `audio/*`, whatever the name.
bool canPreviewAudio(String mime) => mime.toLowerCase().startsWith('audio/');

/// Mime `video/*`, whatever the name.
bool canPreviewVideo(String mime) => mime.toLowerCase().startsWith('video/');

/// Image, pdf, video in that order; null otherwise, audio included.
AttachmentPreviewKind? attachmentPreviewKind(String name, String mime) {
  if (canPreviewImage(name, mime)) return AttachmentPreviewKind.image;
  if (canPreviewPdf(name, mime)) return AttachmentPreviewKind.pdf;
  if (canPreviewVideo(mime)) return AttachmentPreviewKind.video;
  return null;
}

const _sizeUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

/// The web's `getHumanSize`: divide by 1024 while the size is strictly
/// above 1024, round to two decimals, units `B`, `KB`, `MB`, `GB`, `TB`:
/// `0 B`, `1024 B`, `1 KB` for 1025, `1.5 KB`, `117.74 MB`. A negative
/// size counts as 0; sizes beyond TB stay in TB (the web has no unit
/// there). [formatNumber] writes the rounded value, e.g. with the locale's
/// decimal separator; the default writes it like the web.
String humanSize(int bytes, {String Function(num value)? formatNumber}) {
  var size = bytes < 0 ? 0.0 : bytes.toDouble();
  var unit = 0;
  while (size > 1024 && unit < _sizeUnits.length - 1) {
    size /= 1024;
    unit++;
  }
  // Through the decimal text like the web's `Number(size + 'e2')`, so that
  // 1.005 rounds up as written instead of as stored.
  final hundredths = double.parse('${size}e2').round();
  final rounded = double.parse('${hundredths}e-2');
  final value = rounded == rounded.truncateToDouble()
      ? rounded.toInt()
      : rounded;
  final text = formatNumber?.call(value) ?? '$value';
  return '$text ${_sizeUnits[unit]}';
}
