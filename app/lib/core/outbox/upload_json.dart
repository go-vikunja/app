import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The payload of an `uploadAttachment` op: [file] names the stored copy in
/// the account's uploads folder (a random name), [fileName] is what the
/// attachment will be called.
@immutable
final class QueuedUpload {
  const new({
    required this.file,
    required this.fileName,
    required this.size,
    this.mimeType,
  });

  final String file;
  final String fileName;
  final int size;
  final String? mimeType;
}

String encodeQueuedUpload(QueuedUpload upload) => jsonEncode({
  'file': upload.file,
  'name': upload.fileName,
  'size': upload.size,
  'mime': ?upload.mimeType,
});

QueuedUpload decodeQueuedUpload(String json) => switch (jsonDecode(json)) {
  {'file': final String file, 'name': final String name} &&
      final Map<String, Object?> map =>
    QueuedUpload(
      file: file,
      fileName: name,
      size: switch (map['size']) {
        final int size => size,
        _ => 0,
      },
      mimeType: map['mime'] as String?,
    ),
  _ => const QueuedUpload(file: '', fileName: '', size: 0),
};
