import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';

/// What failed and why, for the Sync problems section.
String describeSyncProblem(AppLocalizations l10n, SyncProblem problem) {
  final what = switch (problem.kind) {
    OutboxOperationKind.createTask => l10n.syncProblemCreateFailed,
    OutboxOperationKind.updateTask => l10n.syncProblemUpdateFailed,
    OutboxOperationKind.deleteTask => l10n.syncProblemDeleteFailed,
  };
  final why = switch (problem.failure) {
    Forbidden() => l10n.syncProblemForbidden,
    NotFound(code: 3001) => l10n.syncProblemProjectMissing,
    NotFound() => l10n.syncProblemTaskMissing,
    DomainError(code: 3008) => l10n.syncProblemProjectArchived,
    ValidationFailed() => l10n.syncProblemRejected,
    _ => l10n.syncProblemUnexpected,
  };
  return '$what $why';
}
