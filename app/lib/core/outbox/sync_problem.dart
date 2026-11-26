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
  /// which a later attempt must not blindly repeat.
  bool get createsOnServer =>
      this == createTask || this == uploadAttachment || this == createLabel;
}

/// Persisted diagnostic for a create or upload whose result is unknown.
const unconfirmedWrite = UnexpectedResponse(
  null,
  message: 'the server may have accepted this write; cannot verify its result',
);

bool isUnconfirmedWrite(VikunjaFailure failure) =>
    failure is UnexpectedResponse &&
    failure.statusCode == null &&
    failure.message == unconfirmedWrite.message;

const recurringScheduleConflict = UnexpectedResponse(
  null,
  message: 'the repeating task advanced; its schedule edit cannot be replayed',
);

bool isRecurringScheduleConflict(VikunjaFailure failure) =>
    failure is UnexpectedResponse &&
    failure.statusCode == null &&
    failure.message == recurringScheduleConflict.message;

/// A queued change that could not safely complete. The local edit stays
/// visible until the user resolves it, except when it names a past
/// occurrence: the task shows the current schedule instead.
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
