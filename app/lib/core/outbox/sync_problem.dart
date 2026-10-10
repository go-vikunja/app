import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

enum OutboxOperationKind { updateTask, deleteTask }

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
  });

  final String operationId;
  final OutboxOperationKind kind;
  final int taskId;
  final String taskTitle;
  final VikunjaFailure failure;
  final DateTime failedAt;
}
