import 'package:flutter/foundation.dart';

/// A file another app shared, not read yet: a `content://` URI with what its
/// provider says about it. [displayName] comes from the other app and is
/// never used as a path.
@immutable
final class SharedFile {
  const new({
    required this.uri,
    required this.displayName,
    this.size,
    this.mimeType,
  });

  final String uri;
  final String displayName;

  /// Null when the provider does not say.
  final int? size;
  final String? mimeType;

  @override
  bool operator ==(Object other) =>
      other is SharedFile &&
      other.uri == uri &&
      other.displayName == displayName &&
      other.size == size &&
      other.mimeType == mimeType;

  @override
  int get hashCode => Object.hash(uri, displayName, size, mimeType);

  @override
  String toString() => 'SharedFile(${size ?? '?'} bytes)';
}

/// What another app shared into this app: text, a subject (a page title from
/// a browser, an email subject), files, or a mix.
@immutable
final class IncomingShare {
  const new({this.id, this.subject, this.text, this.files = const []});

  final int? id;
  final String? subject;
  final String? text;
  final List<SharedFile> files;

  bool get isEmpty =>
      (subject?.trim().isEmpty ?? true) &&
      (text?.trim().isEmpty ?? true) &&
      files.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is IncomingShare &&
      (id != null || other.id != null
          ? other.id == id
          : other.subject == subject &&
                other.text == text &&
                listEquals(other.files, files));

  @override
  int get hashCode =>
      id?.hashCode ?? Object.hash(subject, text, Object.hashAll(files));

  @override
  String toString() => 'IncomingShare(${files.length} files)';
}

/// A shared file copied into the app's share inbox.
@immutable
final class CopiedSharedFile {
  const new({required this.path, required this.size});

  final String path;
  final int size;
}

/// The shared file is larger than the limit given to the copy; nothing
/// stays behind.
final class SharedFileTooLarge implements Exception {
  const new({required this.maxBytes});

  final int maxBytes;

  @override
  String toString() => 'SharedFileTooLarge(max $maxBytes)';
}

/// The shared file cannot be read: the other app revoked the grant, the
/// file is gone, or the URI is not one the app accepts.
final class SharedFileUnreadable implements Exception {
  const new();

  @override
  String toString() => 'SharedFileUnreadable';
}

/// Shares from other apps (Android: SEND and SEND_MULTIPLE through
/// `ShareTargetActivity`). The platform keeps the latest share until
/// [clear]; it is never replayed from Recents or after a restore. Only
/// `content://` URIs of other apps are accepted, never `file://` or the
/// app's own providers. Nothing shared is ever logged.
abstract interface class ShareIntentSource {
  /// The share waiting to be handled, if any.
  Future<IncomingShare?> pending();

  /// Shares that arrive while the app runs; each is also [pending].
  Stream<IncomingShare> get shares;

  /// Copies a file into [share]'s inbox, off the main thread, under a
  /// random name. Throws [SharedFileTooLarge] above [maxBytes] and
  /// [SharedFileUnreadable] when it cannot be read or [share] is no longer
  /// pending. A returned path stays usable until [clear].
  Future<CopiedSharedFile> copy(
    IncomingShare share,
    String uri, {
    required int maxBytes,
  });

  /// Calls off a [copy] of [uri] for [share] still running, which then throws
  /// [SharedFileUnreadable]; nothing when none runs.
  Future<void> cancelCopy(IncomingShare share, String uri);

  /// Forgets [share] only if it is still pending. Calls off its copies and
  /// deletes its own inbox files that were not moved away, even when
  /// another share is pending. Call it after all use of its paths ends.
  Future<void> clear(IncomingShare share);
}
