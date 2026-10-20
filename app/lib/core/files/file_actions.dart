import 'dart:io';
import 'dart:ui' show Rect;

/// What the user can do with a downloaded attachment besides viewing it
/// in the app. Android: "open with" (`ACTION_VIEW` through the app's file
/// provider, read-only and temporary) and "save as" (the system's document
/// picker); iOS: both through the share sheet ("Open in…", "Save to
/// Files"). An `origin` anchors the share sheet on an iPad.
abstract interface class FileActions {
  /// False when no app can open the file.
  Future<bool> openWith(File file, {required String mimeType, Rect? origin});

  /// False when the user cancelled.
  Future<bool> saveAs(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  });

  Future<void> share(
    File file, {
    required String fileName,
    required String mimeType,
    Rect? origin,
  });
}

/// [mimeType] without parameters (the server's `text/plain;
/// charset=utf-8`), and a type any app may take when it is unknown.
String plainMimeType(String mimeType) {
  final plain = mimeType.split(';').first.trim().toLowerCase();
  return RegExp(r'^[a-z0-9.+-]+/[a-z0-9.+*-]+$').hasMatch(plain)
      ? plain
      : 'application/octet-stream';
}
