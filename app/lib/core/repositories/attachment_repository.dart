import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';

export 'package:dio/dio.dart' show CancelToken;
export 'package:vikunja_mobile/core/attachments/pending_upload.dart'
    show UploadTooLarge;

/// A task's attachments on the server, online only like bucket management
/// (D48): nothing is queued, a failure is the `VikunjaFailure` of the
/// request (offline a `NetworkFailure`), and a task whose create is still
/// queued throws `TaskNotSyncedYet` without a request. Queued uploads go
/// through `TaskRepository.queueUpload` instead.
abstract interface class AttachmentRepository {
  /// Whether the server takes uploads (`task_attachments_enabled`); when it
  /// does not, upload, delete and cover routes are absent there.
  bool get uploadsEnabled;

  /// The largest file the server takes, as it enforces it.
  int get maxUploadBytes;

  /// Deletes the attachment; when it is the task's cover ([isCover]), the
  /// cover is cleared first, because the server would keep pointing at the
  /// deleted id and refuse every later edit of the task. An attachment
  /// that is already gone counts as deleted. Its downloaded copy goes too.
  Future<void> delete(int taskId, int attachmentId, {bool isCover = false});

  /// Makes [attachmentId] the task's cover, or clears it for null.
  Future<void> setCover(int taskId, int? attachmentId);

  /// The attachment's original as a file in the account's download cache,
  /// reused while its size matches; named after the attachment, sanitised.
  Future<File> download(
    int taskId,
    TaskAttachment attachment, {
    CancelToken? cancel,
  });

  /// Uploads [file] at once (the description editor needs the attachment's
  /// id to insert it). Throws `FileTooLarge` when the server refuses its
  /// size, [UploadTooLarge] before any request when the limit is known to
  /// be exceeded.
  Future<TaskAttachment> uploadNow(
    int taskId,
    File file, {
    required String fileName,
    String? mimeType,
    CancelToken? cancel,
  });
}
