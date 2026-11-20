import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum OutboxOperationKind {
  createTask,
  updateTask,
  deleteTask,
  uploadAttachment,
  createLabel,
  updateLabel,
  deleteLabel;

  bool get isLabelOp =>
      this == createLabel || this == updateLabel || this == deleteLabel;

  /// A request that may leave something on the server without an answer,
  /// which a later attempt looks for first.
  bool get createsOnServer =>
      this == createTask || this == uploadAttachment || this == createLabel;
}

/// A queued change the server rejected for good. The local edit stays
/// visible until the user retries or discards it.
@immutable
final class SyncProblem {
  const new({
    required this.operationId,
    required this.kind,
    required this.taskId,
    required this.taskTitle,
    required this.failure,
    required this.failedAt,
    this.changes,
    this.fileName,
    this.labelId,
  });

  final String operationId;
  final OutboxOperationKind kind;

  /// 0 for a label op.
  final int taskId;

  /// The task's title; for a label op the label's.
  final String taskTitle;
  final VikunjaFailure failure;
  final DateTime failedAt;

  /// What the failed update would have changed, which tells which of its
  /// requests the server refused; null for every other kind.
  final TaskChanges? changes;

  /// The name of the file a failed upload would have attached; null for
  /// every other kind.
  final String? fileName;

  /// The label of a label op; null for every other kind.
  final int? labelId;
}
