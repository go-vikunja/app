import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/attachment_images.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/outbox/outbox_sender.dart';
import 'package:vikunja_mobile/core/repositories/attachment_repository.dart';
import 'package:vikunja_mobile/core/repositories/repository_helpers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

final _log = Logger('Attachments');

/// The server's attachments, addressed by the task's server id; the
/// download cache is per account. What the server took also changes the
/// task's stored details; a failure to change them leaves the write
/// standing. A delete also drops the attachment's download and its images
/// in memory and on disk. The cover is queued like a task edit and sent by
/// [OutboxSender].
final class LocalAttachmentRepository implements AttachmentRepository {
  new(
    this._db,
    this._read,
    this._write,
    this._downloads, {
    required this._outbox,
    required this._accountId,
    required this._images,
    required this.uploadsEnabled,
    required this.maxUploadBytes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const _taskGone = 4002;

  final AppDatabase _db;
  final VikunjaReadClient _read;
  final VikunjaWriteClient _write;
  final AttachmentDownloads _downloads;
  final OutboxSender _outbox;
  final String _accountId;
  final AttachmentImages _images;
  final DateTime Function() _now;

  @override
  final bool uploadsEnabled;

  @override
  final int maxUploadBytes;

  @override
  Future<void> delete(int taskId, int attachmentId) async {
    final id = await serverTaskId(_db.tasksDao, taskId);
    await _sendQueuedCover(taskId, id);
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
    await _queueCover(id, attachmentId ?? 0);
    _drainQuietly();
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

  Future<void> _queueCover(int id, int attachmentId) async {
    final queued = await _db.outboxDao.queueUpdate(
      id,
      TaskChanges(coverImageAttachmentId: attachmentId),
      now: _now(),
    );
    if (!queued) throw const NotFound(code: _taskGone);
  }

  Future<void> _sendQueuedCover(int taskId, int id) async {
    // The server would keep naming a deleted cover and refuse every later
    // edit of the task (decision log: Outbox).
    if (!await _queuesCover(id)) return;
    final blockedBy = await _outbox.sendQueueNow();
    if (await _queuesCover(id)) throw blockedBy ?? TaskNotSyncedYet(taskId);
  }

  Future<bool> _queuesCover(int id) async =>
      (await _db.outboxDao.pendingChangesFor(id))?.coverImageAttachmentId !=
      null;

  void _drainQuietly() => unawaited(
    _outbox.drain().then<void>(
      (_) {},
      onError: (Object error) =>
          _log.warning('Outbox drain failed: ${error.runtimeType}'),
    ),
  );

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
