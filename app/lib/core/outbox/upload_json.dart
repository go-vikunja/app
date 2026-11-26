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

/// [payload], a queued upload, with [id] as the highest attachment id its
/// task had before the upload's first request. Attachment ids only grow, so
/// whatever that request stored has a larger one; a fence already recorded
/// stays, as an earlier request may have stored the file.
String withAttachmentsBefore(String payload, int id) {
  final decoded = jsonDecode(payload) as Map<String, Object?>;
  if (decoded[_attachmentsBeforeKey] is int) return payload;
  return jsonEncode({...decoded, _attachmentsBeforeKey: id});
}

/// The fence [withAttachmentsBefore] recorded; null for an upload never
/// posted, and for one an earlier version posted.
int? attachmentsBeforeOf(String payload) => switch (jsonDecode(payload)) {
  {_attachmentsBeforeKey: final int id} => id,
  _ => null,
};

const _attachmentsBeforeKey = 'attachments_before';
