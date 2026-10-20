import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum PendingUploadState {
  /// Queued: offline, behind the task's create, or waiting out a backoff.
  waiting,
  sending,

  /// Rejected for good; a sync problem until it is retried or discarded.
  failed,
}

/// A file queued for upload to a task, one outbox op per file. Its own
/// type, so a queued file never passes for a server attachment.
@immutable
final class PendingUpload {
  const new({
    required this.operationId,
    required this.taskId,
    required this.fileName,
    required this.size,
    required this.state,
    required this.queuedAt,
    this.mimeType,
    this.lastFailure,
  });

  final String operationId;

  /// Negative while the task's create has not been answered.
  final int taskId;
  final String fileName;
  final int size;
  final String? mimeType;
  final PendingUploadState state;
  final DateTime queuedAt;

  /// Why the last attempt failed: the final reason when [state] is failed,
  /// the transient one a waiting upload waits out, else null.
  final VikunjaFailure? lastFailure;

  PendingUpload withState(PendingUploadState state) => PendingUpload(
    operationId: operationId,
    taskId: taskId,
    fileName: fileName,
    size: size,
    state: state,
    queuedAt: queuedAt,
    mimeType: mimeType,
    lastFailure: lastFailure,
  );

  @override
  bool operator ==(Object other) =>
      other is PendingUpload &&
      other.operationId == operationId &&
      other.taskId == taskId &&
      other.fileName == fileName &&
      other.size == size &&
      other.mimeType == mimeType &&
      other.state == state &&
      other.queuedAt == queuedAt &&
      other.lastFailure?.runtimeType == lastFailure?.runtimeType &&
      other.lastFailure?.code == lastFailure?.code;

  @override
  int get hashCode => Object.hash(
    operationId,
    taskId,
    fileName,
    size,
    mimeType,
    state,
    queuedAt,
    lastFailure?.runtimeType,
    lastFailure?.code,
  );

  @override
  String toString() => 'PendingUpload($operationId, task $taskId, $state)';
}

/// A file above the server's upload limit; nothing was stored or queued.
final class UploadTooLarge implements Exception {
  const new({required this.size, required this.maxBytes});

  final int size;
  final int maxBytes;

  @override
  String toString() => 'UploadTooLarge($size > $maxBytes)';
}
