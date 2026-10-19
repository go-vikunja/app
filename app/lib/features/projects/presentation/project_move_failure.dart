import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// Why moving a project failed; [parentChanged] when the move would have
/// put it under another parent, which only project admins may do.
String projectMoveFailureText(
  AppLocalizations l10n,
  Object error, {
  required bool parentChanged,
}) => switch (error) {
  // The server may have moved it before the answer was lost.
  NetworkFailure(problem: NetworkProblem.timeout) =>
    l10n.projectMoveUnconfirmed,
  NetworkFailure() => l10n.projectMoveNeedsConnection,
  Forbidden() when parentChanged => l10n.projectMoveAdminOnly,
  Forbidden() => l10n.projectMoveForbidden,
  NotFound() => l10n.projectMoveGone,
  VikunjaFailure(code: 3008) => l10n.projectMoveArchived,
  // Under itself, under one of its subprojects, under a saved filter.
  VikunjaFailure(code: 3009 || 3010 || 3011) => l10n.projectMoveNotPossible,
  VikunjaFailure(:final message) when message.trim().isNotEmpty =>
    l10n.projectMoveRefused(message.trim()),
  _ => l10n.projectMoveFailed,
};
