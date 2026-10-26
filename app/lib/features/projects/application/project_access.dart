import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/projects_provider.dart';

part 'project_access.g.dart';

/// What the signed-in user may do with a project, from the `max_permission`
/// the last sync stored, by the server's rules (`project_permissions.go`,
/// `project_view_permissions.go`, `kanban_permissions.go`,
/// `project_duplicate.go`). An unknown permission allows everything, as
/// before the app stored it: the server's refusal is then mapped. The rules
/// for archived projects stay where they are and apply on top.
@immutable
final class ProjectAccess {
  const new(this.permission);

  factory of(Project project) => ProjectAccess(project.maxPermission);

  /// Before the project is stored, or without a stored permission.
  static const unknown = ProjectAccess(null);

  final Permission? permission;

  bool get isKnown => permission != null;

  bool get canWrite => permission?.canWrite ?? true;

  bool get isAdmin => permission == null || permission == Permission.admin;

  /// Known to be read only, for the "Read only" notes.
  bool get isReadOnly => permission == Permission.read;

  /// Title, identifier, colour, description, archiving, favourite order.
  bool get canEdit => canWrite;

  bool get canArchive => canWrite;

  /// Moving it under another parent; reordering among its siblings needs
  /// [canWrite] only.
  bool get canChangeParent => isAdmin;

  bool get canDelete => isAdmin;

  bool get canManageViews => isAdmin;

  /// User, team and link shares; reading the user and team shares needs
  /// read access only.
  bool get canManageShares => isAdmin;

  /// As the parent of a new, moved or duplicated project.
  bool get canCreateChild => canWrite;

  /// Read access is enough for the source; the copy's parent needs
  /// [canCreateChild].
  bool get canDuplicate => true;

  /// Creating tasks here, or moving tasks here.
  bool get canAddTasks => canWrite;

  bool get canChangeTasks => canWrite;

  /// Manual order in a list view, cards and columns on a board.
  bool get canReorderOrBoard => canWrite;

  bool get canComment => canWrite;

  bool get canReact => canWrite;

  @override
  bool operator ==(Object other) =>
      other is ProjectAccess && other.permission == permission;

  @override
  int get hashCode => permission.hashCode;

  @override
  String toString() => 'ProjectAccess(${permission?.name ?? 'unknown'})';
}

/// The stored project's access, following each sync; [ProjectAccess.unknown]
/// while the project is not stored (or nobody is signed in).
@riverpod
ProjectAccess projectAccess(Ref ref, int projectId) => switch (ref.watch(
  projectByIdProvider(projectId).select((project) => project?.maxPermission),
)) {
  final permission? => ProjectAccess(permission),
  null => ProjectAccess.unknown,
};
