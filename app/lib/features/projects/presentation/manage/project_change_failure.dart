import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/project_view_repository.dart';

enum ProjectChange {
  create,
  edit,

  /// An edit that also puts the project under another parent, which only
  /// project admins may do.
  editWithParent,
  favourite,
  archive,
  unarchive,
  delete,
  duplicate,
  view,
}

/// [titleTooLong]: the project's stored title is over the server's limit,
/// which the server checks on every change of the project.
String projectChangeFailureText(
  AppLocalizations l10n,
  Object error,
  ProjectChange change, {
  bool titleTooLong = false,
}) {
  final createsUnderParent = switch (change) {
    ProjectChange.create ||
    ProjectChange.duplicate ||
    ProjectChange.editWithParent => true,
    _ => false,
  };
  // Of the places these changes start, only the project screen can be
  // pulled down to refresh.
  final fromProjectScreen = switch (change) {
    ProjectChange.favourite ||
    ProjectChange.archive ||
    ProjectChange.unarchive ||
    ProjectChange.delete => true,
    _ => false,
  };
  return switch (error) {
    LastViewNotDeletable() => l10n.projectViewLastOne,
    // The server may have made the change before the answer was lost.
    NetworkFailure(problem: NetworkProblem.timeout) when fromProjectScreen =>
      l10n.projectChangeUnconfirmed,
    NetworkFailure(problem: NetworkProblem.timeout) =>
      l10n.projectFormUnconfirmed,
    NetworkFailure() => l10n.projectChangeNeedsConnection,
    Forbidden() when change == ProjectChange.view => l10n.projectViewsAdminOnly,
    Forbidden() when change == ProjectChange.delete =>
      l10n.projectDeleteAdminOnly,
    Forbidden() when change == ProjectChange.editWithParent =>
      l10n.projectMoveAdminOnly,
    Forbidden() when createsUnderParent => l10n.projectCreateForbidden,
    Forbidden() => l10n.projectChangeForbidden,
    VikunjaFailure(code: 4024 || 4019 || 4016, :final message) =>
      l10n.projectViewFilterInvalid(message.trim()),
    NotFound() when change == ProjectChange.view => l10n.projectViewGone,
    NotFound() => l10n.projectGone,
    VikunjaFailure(code: 3007) => l10n.projectIdentifierTaken,
    VikunjaFailure(code: 3012) => l10n.projectDeleteDefault,
    VikunjaFailure(code: 3013) => l10n.projectArchiveDefault,
    VikunjaFailure(code: 3016) => l10n.projectUnarchiveParentFirst,
    VikunjaFailure(code: 3008) when createsUnderParent =>
      l10n.projectParentArchived,
    VikunjaFailure(code: 3008) => l10n.projectChangeArchived,
    // Under itself, under one of its subprojects, under a saved filter.
    VikunjaFailure(code: 3009 || 3010 || 3011) => l10n.projectMoveNotPossible,
    ValidationFailed() || VikunjaFailure(code: 2002)
        when change == ProjectChange.view =>
      l10n.projectViewInvalid,
    ValidationFailed() || VikunjaFailure(code: 2002) when titleTooLong =>
      l10n.projectTitleTooLongToChange,
    ValidationFailed() ||
    VikunjaFailure(code: 2002) => l10n.projectChangeInvalid,
    VikunjaFailure(:final message) when message.trim().isNotEmpty =>
      l10n.projectChangeRefused(message.trim()),
    _ => l10n.projectChangeFailed,
  };
}

/// Whether [error] is the server refusing a view's filter, which its form
/// shows at the filter field.
bool isInvalidViewFilter(Object error) =>
    error is VikunjaFailure && const {4024, 4019, 4016}.contains(error.code);
