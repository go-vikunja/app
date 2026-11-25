import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/attachments/pending_upload.dart';

export 'package:dio/dio.dart' show CancelToken;
export 'package:vikunja_mobile/core/attachments/pending_upload.dart'
    show UploadTooLarge;

/// A task's attachments on the server. Uploading now, deleting and
/// downloading are online, like bucket management: a failure is the
/// `VikunjaFailure` of the request (offline a `NetworkFailure`). The cover
/// is a change of the task and queued like one. A task whose create is
/// still queued throws `TaskNotSyncedYet` without a request. Queued uploads
/// go through `TaskRepository.queueUpload`.
abstract interface class AttachmentRepository {
  /// Whether the server takes uploads (`task_attachments_enabled`); when it
  /// does not, upload, delete and cover routes are absent there.
  bool get uploadsEnabled;

  /// The largest file the server takes, as it enforces it.
  int get maxUploadBytes;

  /// Deletes the attachment; one that is already gone counts as deleted.
  /// Its downloaded copy goes too. A cover change of the task still queued
  /// is sent first, and while it cannot go the delete is refused with the
  /// failure the queue waits out (offline a `NetworkFailure`), else
  /// `TaskNotSyncedYet`. The cover is left as it is, so a cover is cleared
  /// with [setCover] first.
  Future<void> delete(int taskId, int attachmentId);

  /// Makes [attachmentId] the task's cover, or clears it for null. Queued
  /// like a task edit, it shows in the stored details at once, offline too,
  /// and is sent behind the task's queued changes. `NotFound` 4002 when the
  /// task is no longer here or its delete is queued.
  Future<void> setCover(int taskId, int? attachmentId);

  /// The attachment's original as a file in the account's download cache,
  /// reused while its size matches; named after the attachment, sanitised.
  /// A file whose length is not the listed size, such as a captive portal's
  /// page in its place, is deleted and fails with `UnexpectedResponse`; a
  /// listed size of 0 is not checked.
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
