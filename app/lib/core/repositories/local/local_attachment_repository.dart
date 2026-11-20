import 'dart:io';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';

final _log = Logger('Attachments');

/// The server's attachments, addressed by the task's server id; the
/// download cache is per account. What the server took also changes the
/// task's stored details; a failure to change them leaves the write
/// standing. A delete also drops the attachment's download and its images
/// in memory and on disk.
final class LocalAttachmentRepository implements AttachmentRepository {
  new(
    this._db,
    this._read,
    this._write,
    this._downloads, {
    required this._accountId,
    required this._images,
    required this.uploadsEnabled,
    required this.maxUploadBytes,
  });

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;
  final AttachmentDownloads _downloads;
  final String _accountId;
  final AttachmentImages _images;

  @override
  final bool uploadsEnabled;

  @override
  final int maxUploadBytes;

  @override
  Future<void> delete(
    int taskId,
    int attachmentId, {
    bool isCover = false,
  }) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    if (isCover) {
      await _write.tasks.update(
        id,
        const TaskChanges(coverImageAttachmentId: 0),
      );
    }
    await _write.attachments.delete(id, attachmentId);
    await _keep(() => _db.taskDetailsDao.removeAttachment(id, attachmentId));
    try {
      await _downloads.forget(_accountId, id, attachmentId);
    } on FileSystemException catch (error) {
      _log.info('Could not delete a download: ${error.osError?.errorCode}');
    }
    await _images.drop(id, attachmentId);
  }

  @override
  Future<void> setCover(int taskId, int? attachmentId) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    await _write.tasks.update(
      id,
      TaskChanges(coverImageAttachmentId: attachmentId ?? 0),
    );
    await _keep(() => _db.taskDetailsDao.storeCover(id, attachmentId ?? 0));
  }

  @override
  Future<File> download(
    int taskId,
    TaskAttachment attachment, {
    CancelToken? cancel,
  }) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    if (await _downloads.cached(_accountId, id, attachment) case final file?) {
      return file;
    }
    final target = await _downloads.fileFor(_accountId, id, attachment);
    await _read.attachments.download(
      id,
      attachment.id,
      target: target,
      cancel: cancel,
    );
    return target;
  }

  @override
  Future<TaskAttachment> uploadNow(
    int taskId,
    File file, {
    required String fileName,
    String? mimeType,
    CancelToken? cancel,
  }) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    final size = await file.length();
    if (size > maxUploadBytes) {
      throw UploadTooLarge(size: size, maxBytes: maxUploadBytes);
    }
    final attachment = await _write.attachments.upload(
      id,
      fileName: safeFileName(fileName),
      bytes: file.openRead(),
      length: size,
      mimeType: mimeType,
      timeout: uploadTimeoutFor(size),
      cancel: cancel,
    );
    await _keep(() => _db.taskDetailsDao.addAttachment(id, attachment));
    return attachment;
  }

  Future<void> _keep(Future<void> Function() change) async {
    try {
      await change();
    } on Object catch (error) {
      _log.warning(
        'Could not store an attachment change: ${error.runtimeType}',
      );
    }
  }
}
