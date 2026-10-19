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
    Forbidden() when _onlyReorders(problem.changes) =>
      l10n.syncProblemListNotReorderable,
    Forbidden() => l10n.syncProblemForbidden,
    RelatedTaskMissing() => l10n.syncProblemRelatedTaskMissing,
    NotFound(code: 3001) => l10n.syncProblemProjectMissing,
    NotFound(code: 8002) => l10n.syncProblemLabelMissing,
    NotFound(code: 1005) => l10n.syncProblemUserMissing,
    NotFound(code: 3014) when _namesOnlyListViews(problem.changes) =>
      l10n.syncProblemListMissing,
    NotFound(code: 10001 || 3014) ||
    DomainError(code: 10002) => l10n.syncProblemColumnMissing,
    NotFound() => l10n.syncProblemTaskMissing,
    DomainError(code: 3008) => l10n.syncProblemProjectArchived,
    DomainError(code: 10004) => l10n.syncProblemColumnFull,
    DomainError(code: 4023) => l10n.syncProblemRelationCycle,
    DomainError(code: 4010) => l10n.syncProblemRelationToItself,
    DomainError(code: 4007) => l10n.syncProblemRejected,
    ValidationFailed() => l10n.syncProblemRejected,
    _ => l10n.syncProblemUnexpected,
  };
  return '$what $why';
}

/// The update changes list positions and nothing else, so its only write
/// is the position's.
bool _onlyReorders(TaskChanges? changes) =>
    changes != null &&
    (changes.positions?.isNotEmpty ?? false) &&
    changes == TaskChanges(positions: changes.positions);

/// Of the update's requests only the list positions name a view.
bool _namesOnlyListViews(TaskChanges? changes) =>
    changes != null &&
    (changes.positions?.isNotEmpty ?? false) &&
    (changes.kanban?.isEmpty ?? true);
