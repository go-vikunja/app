import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/text/html_to_text.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

/// What failed and why, for the Sync problems section. [projectName]
/// names a project a held move would go to.
String describeSyncProblem(
  AppLocalizations l10n,
  SyncProblem problem, {
  String? Function(int projectId)? projectName,
}) {
  if (isRecurringScheduleConflict(problem.failure)) {
    final changes = problem.changes ?? const TaskChanges();
    final held = _heldValues(l10n, changes, projectName);
    final schedule = _heldSchedule(l10n, changes);
    return [
      l10n.syncProblemRecurringScheduleConflict,
      if (held.isNotEmpty) l10n.syncProblemHeldChanges(held.join(', ')),
      if (schedule.isNotEmpty)
        l10n.syncProblemHeldSchedule(schedule.join(', ')),
    ].join('\n');
  }
  if (isUnconfirmedWrite(problem.failure)) {
    return switch (problem.kind) {
      OutboxOperationKind.createTask => l10n.syncProblemCreateUnconfirmed,
      OutboxOperationKind.uploadAttachment => l10n.syncProblemUploadUnconfirmed(
        problem.fileName ?? '',
      ),
      _ => l10n.syncProblemUnexpected,
    };
  }
  final what = switch (problem.kind) {
    OutboxOperationKind.createTask => l10n.syncProblemCreateFailed,
    OutboxOperationKind.updateTask => l10n.syncProblemUpdateFailed,
    OutboxOperationKind.deleteTask => l10n.syncProblemDeleteFailed,
    OutboxOperationKind.uploadAttachment => l10n.syncProblemUploadFailed(
      problem.fileName ?? '',
    ),
    OutboxOperationKind.createLabel => l10n.syncProblemLabelCreateFailed,
    OutboxOperationKind.updateLabel => l10n.syncProblemLabelUpdateFailed,
    OutboxOperationKind.deleteLabel => l10n.syncProblemLabelDeleteFailed,
  };
  if (problem.kind == OutboxOperationKind.uploadAttachment) {
    return '$what ${_whyUploadFailed(l10n, problem.failure)}';
  }
  if (problem.kind.isLabelOp) {
    return '$what ${_whyLabelOpFailed(l10n, problem)}';
  }
  final why = switch (problem.failure) {
    Forbidden() when _onlyReorders(problem.changes) =>
      l10n.syncProblemListNotReorderable,
    Forbidden() => l10n.syncProblemForbidden,
    RelatedTaskMissing() => l10n.syncProblemRelatedTaskMissing,
    // A web server's 404, not Vikunja's; the outbox gave up on it.
    NotFound(routeAbsent: true) => l10n.syncProblemUnexpected,
    NotFound(code: 3018) => l10n.syncProblemProjectInTrash,
    NotFound(code: 4040) => l10n.syncProblemTaskInTrash,
    NotFound(projectGone: true) => l10n.syncProblemProjectMissing,
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
    DomainError(code: 4029) => l10n.syncProblemRepeatTooLong,
    DomainError(code: 4007) => l10n.syncProblemRejected,
    ValidationFailed() => l10n.syncProblemRejected,
    DescriptionConflict() => l10n.syncProblemDescriptionConflict,
    ServerFailure() => l10n.syncProblemServerKeptFailing,
    _ => l10n.syncProblemUnexpected,
  };
  return '$what $why';
}

/// What a repeating task's notice held back that "Keep my version" may
/// apply, each with the value it would set where it can be told briefly.
List<String> _heldValues(
  AppLocalizations l10n,
  TaskChanges changes,
  String? Function(int projectId)? projectName,
) => [
  if (changes.title case final title?)
    l10n.syncProblemHeldValue(l10n.taskEditTitleLabel, title),
  if (changes.description case final description?)
    l10n.syncProblemHeldValue(
      l10n.taskDetailDescription,
      _excerpt(htmlToPlainText(description)),
    ),
  if (changes.projectId case final projectId?)
    switch (projectName?.call(projectId)) {
      final name? => l10n.syncProblemHeldValue(l10n.taskEditProject, name),
      null => l10n.taskEditProject,
    },
  if (changes.priority case final priority?)
    l10n.syncProblemHeldValue(
      l10n.taskDetailPriority,
      priorityLabel(l10n, TaskPriority.fromValue(priority)),
    ),
  if (changes.percentDone case final percent?)
    l10n.taskPercentDone((percent * 100).round()),
  if (changes.hexColor case final hex? when hex.isEmpty) l10n.taskEditNoColour,
  if (changes.hexColor case final hex? when hex.isNotEmpty)
    l10n.taskEditColourSemantics('#${hex.replaceFirst('#', '')}'),
  if (changes.isFavorite == true) l10n.taskAddFavourite,
  if (changes.isFavorite == false) l10n.taskRemoveFavourite,
  if (changes.repeatAfter != null || changes.repeatMode != null)
    l10n.taskEditRepeat,
  if (changes.coverImageAttachmentId != null) l10n.taskDetailCoverImage,
];

/// The dates and reminders a notice held back, which were set for the
/// previous occurrence and are never applied again.
List<String> _heldSchedule(AppLocalizations l10n, TaskChanges changes) => [
  if (changes.dueDate != null) l10n.taskDetailDueDate,
  if (changes.startDate != null) l10n.taskDetailStartDate,
  if (changes.endDate != null) l10n.taskDetailEndDate,
  if (changes.reminders != null) l10n.taskDetailReminders,
];

String _excerpt(String text) {
  final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return line.length <= 60 ? line : '${line.substring(0, 59).trimRight()}…';
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

String _whyLabelOpFailed(AppLocalizations l10n, SyncProblem problem) =>
    switch (problem.failure) {
      Forbidden() when problem.kind != OutboxOperationKind.createLabel =>
        l10n.labelsNotCreator,
      NotFound(routeAbsent: true) => l10n.syncProblemUnexpected,
      NotFound() => l10n.labelsGone,
      ValidationFailed() || VikunjaFailure(code: 2002) => l10n.labelsInvalid,
      Forbidden() || DomainError() => l10n.syncProblemRejected,
      ServerFailure() => l10n.syncProblemServerKeptFailing,
      _ => l10n.syncProblemUnexpected,
    };

String _whyUploadFailed(AppLocalizations l10n, VikunjaFailure failure) =>
    switch (failure) {
      NotFound(code: 3018) => l10n.syncProblemProjectInTrash,
      NotFound(code: 4040) => l10n.syncProblemTaskInTrash,
      ServerFailure() => l10n.syncProblemServerKeptFailing,
      _ => switch (uploadProblemReason(failure)) {
        UploadProblemReason.tooLarge => l10n.syncProblemUploadTooLarge,
        UploadProblemReason.taskGone => l10n.syncProblemTaskMissing,
        UploadProblemReason.projectArchived => l10n.syncProblemProjectArchived,
        UploadProblemReason.noPermission => l10n.syncProblemUploadForbidden,
        UploadProblemReason.attachmentsDisabled =>
          l10n.syncProblemAttachmentsDisabled,
        UploadProblemReason.fileMissing => l10n.syncProblemUploadFileMissing,
        UploadProblemReason.timedOut => l10n.syncProblemUploadTimedOut,
        UploadProblemReason.other => l10n.syncProblemUnexpected,
      },
    };
