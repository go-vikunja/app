import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/common/presentation/action_failure_text.dart';

enum TrashAction {
  restoreTask,
  restoreProject,
  deleteTaskForever,
  deleteProjectForever,
  empty,
}

/// The text for [error] from a bin [action]: an Undo, a Restore from a link
/// or the bin page, a permanent delete or emptying the bin.
String trashFailureText(
  AppLocalizations l10n,
  Object error,
  TrashAction action,
) {
  final restore = switch (action) {
    TrashAction.restoreTask || TrashAction.restoreProject => true,
    _ => false,
  };
  final shared = actionFailureText(l10n, error);
  return switch (error) {
    TaskDeleteInFlight() => l10n.trashDeleteStillSending,
    // No "unconfirmed" text for a timeout: a second restore succeeds, and a
    // second permanent delete says the item is no longer in the bin.
    NetworkFailure() when restore => l10n.trashRestoreNeedsConnection,
    NetworkFailure() => l10n.trashNeedsConnection,
    NotFound(routeAbsent: true) => l10n.trashUnavailable,
    Forbidden() => switch (action) {
      TrashAction.restoreTask => l10n.trashRestoreTaskForbidden,
      TrashAction.restoreProject => l10n.trashRestoreProjectAdminOnly,
      TrashAction.deleteTaskForever ||
      TrashAction.empty => l10n.trashDeleteTaskAdminOnly,
      TrashAction.deleteProjectForever => l10n.trashDeleteProjectAdminOnly,
    },
    NotFound(code: 3018) => l10n.trashTaskProjectInTrash,
    NotFound() => switch (action) {
      TrashAction.restoreTask ||
      TrashAction.deleteTaskForever => l10n.trashTaskGone,
      TrashAction.restoreProject ||
      TrashAction.deleteProjectForever => l10n.trashProjectGone,
      TrashAction.empty => l10n.trashActionFailed,
    },
    VikunjaFailure(code: 3008) when action == TrashAction.deleteTaskForever =>
      l10n.trashDeleteArchived,
    VikunjaFailure(code: 3008) => l10n.trashRestoreArchived,
    VikunjaFailure(code: 3019) => l10n.trashRestoreParentInTrash,
    VikunjaFailure(code: 3016) => l10n.projectUnarchiveParentFirst,
    _ when shared != null => shared,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.trashActionRefused(message.trim()),
    _ => l10n.trashActionFailed,
  };
}
