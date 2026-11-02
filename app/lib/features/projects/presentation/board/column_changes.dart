import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/bucket_repository.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/confirm_dialog.dart';

enum ColumnChange {
  create,
  rename,
  limit,
  move,
  delete,

  /// A delete that first makes another column the default, as the server
  /// would otherwise strand the column's tasks outside every column.
  deleteAfterNewDefault,
  done,
  defaultColumn,
}

String columnChangeFailureText(
  AppLocalizations l10n,
  Object error,
  ColumnChange change,
) {
  final shared = actionFailureText(l10n, error);
  return switch (error) {
    DeleteFailedAfterNewDefault(:final bucket, :final newDefault) =>
      l10n.boardColumnDeleteFailedNewDefault(newDefault.title, bucket.title),
    // The server may have made the change before the answer was lost.
    NetworkFailure(problem: NetworkProblem.timeout) =>
      l10n.boardColumnUnconfirmed,
    NetworkFailure() => l10n.boardColumnNeedsConnection,
    // Project write access is enough for the buckets themselves; the view's
    // done and default bucket need admin access.
    Forbidden() when change == ColumnChange.done => l10n.boardColumnAdminOnly,
    Forbidden() when change == ColumnChange.defaultColumn =>
      l10n.boardColumnAdminOnly,
    Forbidden() when change == ColumnChange.deleteAfterNewDefault =>
      l10n.boardColumnDeleteAdminOnly,
    Forbidden() => l10n.boardColumnForbidden,
    VikunjaFailure(code: 10003) => l10n.boardColumnLastOne,
    // 2.7.1 caps a view at 100 buckets.
    VikunjaFailure(code: 10007) => l10n.boardColumnsAtMaximum,
    VikunjaFailure(code: 10001) => l10n.syncProblemColumnMissing,
    NotFound(code: 3014) => l10n.projectViewGone,
    NotFound(code: 3001) => l10n.projectGone,
    VikunjaFailure(code: 3008) => l10n.boardColumnArchived,
    ValidationFailed() || VikunjaFailure(code: 2002) => l10n.boardColumnInvalid,
    _ when shared != null => shared,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.boardColumnChangeRefused(message.trim()),
    _ => l10n.boardColumnChangeFailed,
  };
}

/// The web's question before a delete; [tasksGoTo] names the column the
/// server moves the column's tasks to, null when it holds none. When
/// [becomesDefault], that column is made the default first, which the
/// question says too.
Future<bool> confirmDeleteColumn(
  BuildContext context, {
  required String column,
  String? tasksGoTo,
  bool becomesDefault = false,
}) {
  final l10n = context.l10n;
  return confirmAdaptive(
    context,
    title: l10n.boardDeleteColumnTitle,
    body: [
      l10n.boardDeleteColumnBody(column),
      if (tasksGoTo != null) l10n.boardDeleteColumnTasksMove(tasksGoTo),
      if (tasksGoTo != null && becomesDefault)
        l10n.boardDeleteColumnBecomesDefault(tasksGoTo),
    ].join('\n'),
    confirmLabel: l10n.boardDeleteColumnConfirm,
    destructive: true,
  );
}
