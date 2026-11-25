import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

/// Below it the server renumbers every sibling of the project, at the top
/// level those of every user on the instance.
const minProjectPosition = 0.1;

/// What moving a project to a place in the tree comes to.
@immutable
sealed class ProjectMovePlan {
  const new();
}

final class MoveProject extends ProjectMovePlan {
  const new({
    required this.projectId,
    required this.position,
    required this.parentProjectId,
  });

  final int projectId;
  final double position;

  /// 0 for the top level.
  final int parentProjectId;

  @override
  bool operator ==(Object other) =>
      other is MoveProject &&
      other.projectId == projectId &&
      other.position == position &&
      other.parentProjectId == parentProjectId;

  @override
  int get hashCode => Object.hash(projectId, position, parentProjectId);

  /// [project], when it is the one moved, as it is once moved.
  Project applyTo(Project project) => project.id != projectId
      ? project
      : project.copyWith(parentProjectId: parentProjectId, position: position);

  @override
  String toString() =>
      'MoveProject($projectId, at $position under $parentProjectId)';
}

final class ProjectStays extends ProjectMovePlan {
  const new();

  @override
  bool operator ==(Object other) => other is ProjectStays;

  @override
  int get hashCode => (ProjectStays).hashCode;

  @override
  String toString() => 'ProjectStays';
}

/// Not allowed: into itself or below itself, an archived project moved or
/// taking it, a project the user may only read moved, a parent the user
/// may only read taking it, a place whose position would fall below
/// [minProjectPosition] or not sort between its neighbours, or another
/// parent for a project the user is no admin of.
final class ProjectMoveRefused extends ProjectMovePlan {
  const new({this.reason = ProjectMoveRefusal.notAllowed});

  final ProjectMoveRefusal reason;

  @override
  bool operator ==(Object other) =>
      other is ProjectMoveRefused && other.reason == reason;

  @override
  int get hashCode => Object.hash(ProjectMoveRefused, reason);

  @override
  String toString() => 'ProjectMoveRefused(${reason.name})';
}

enum ProjectMoveRefusal {
  notAllowed,

  /// Another parent for a project the user is no admin of.
  adminOnly,

  /// Above the first project of a level, whose position leaves no room
  /// above [minProjectPosition] (decision log: Projects, manual order),
  /// where the user can move that project down to make room.
  noRoomAtTop,
}

/// The project tree as the Projects tab shows it, for moving projects in
/// it: among their siblings and under other projects.
final class ProjectTreeMoves {
  new(List<ProjectNode> roots, {required List<Project> all})
    : _roots = [for (final node in roots) node.project],
      _all = {for (final project in all) project.id: project} {
    void index(ProjectNode node, int parentId) {
      _shownParents[node.project.id] = parentId;
      _children[node.project.id] = [
        for (final child in node.children) child.project,
      ];
      for (final child in node.children) {
        index(child, node.project.id);
      }
    }

    for (final root in roots) {
      index(root, 0);
    }
  }

  final List<Project> _roots;
  final Map<int, Project> _all;
  final _shownParents = <int, int>{};
  final _children = <int, List<Project>>{};

  bool shows(int projectId) => _shownParents.containsKey(projectId);

  /// The parent the project shows under, 0 at the top level: an orphan,
  /// whose parent is not shown, shows there too.
  int shownParentOf(int projectId) => _shownParents[projectId] ?? 0;

  /// The projects shown under [parentId], 0 for the top level, in order.
  List<Project> childrenOf(int parentId) =>
      parentId == 0 ? _roots : _children[parentId] ?? const [];

  Project? projectOf(int projectId) => _all[projectId];

  bool isArchived(int projectId) => isArchivedInTree(projectId, _all);

  /// [projectId] is [ancestorId] or shows below it.
  bool isWithin(int projectId, int ancestorId) {
    final seen = <int>{};
    for (var id = projectId; id != 0 && seen.add(id); id = shownParentOf(id)) {
      if (id == ancestorId) return true;
    }
    return false;
  }

  /// Moving [projectId] under [parentId] (0: the top level) to [index]
  /// among its children as shown, counted without the project. The
  /// position lies between the new neighbours as the web computes it, or
  /// is a neighbour's own when both share it and the title sorts between
  /// theirs. An orphan put among the top-level projects keeps its parent,
  /// as the web does: its user may lack the right to detach it. The stored
  /// permissions decide as the server would ([ProjectAccess]).
  ProjectMovePlan plan(
    int projectId, {
    required int parentId,
    required int index,
  }) {
    final moved = _all[projectId];
    if (moved == null ||
        !shows(projectId) ||
        isArchived(projectId) ||
        !ProjectAccess.of(moved).canReorder) {
      return const ProjectMoveRefused();
    }
    if (parentId != 0 &&
        (!shows(parentId) ||
            isWithin(parentId, projectId) ||
            isArchived(parentId))) {
      return const ProjectMoveRefused();
    }
    final shown = childrenOf(parentId);
    final current = shown.indexWhere((project) => project.id == projectId);
    final parentProjectId = parentId == 0 && current >= 0
        ? moved.parentProjectId
        : parentId;
    if (parentProjectId != moved.parentProjectId) {
      if (!ProjectAccess.of(moved).canChangeParent) {
        return const ProjectMoveRefused(reason: ProjectMoveRefusal.adminOnly);
      }
      if (_all[parentProjectId] case final parent?
          when !ProjectAccess.of(parent).canCreateChild) {
        return const ProjectMoveRefused();
      }
    }
    final others = [
      for (final project in shown)
        if (project.id != projectId) project,
    ];
    final to = index.clamp(0, others.length);
    if (to == current) return const ProjectStays();
    final before = to > 0 ? others[to - 1] : null;
    final after = to < others.length ? others[to] : null;
    bool fits(double position) =>
        position >= minProjectPosition &&
        (before == null ||
            _compare(before.position, before.title, position, moved.title) <
                0) &&
        (after == null ||
            _compare(position, moved.title, after.position, after.title) < 0);

    final between = calculateItemPosition(before?.position, after?.position);
    final position = fits(between)
        ? between
        : before != null && after != null && fits(before.position)
        ? before.position
        : null;
    if (position == null) {
      return ProjectMoveRefused(
        reason:
            before == null &&
                between < minProjectPosition &&
                after != null &&
                !isArchived(after.id) &&
                ProjectAccess.of(after).canReorder
            ? ProjectMoveRefusal.noRoomAtTop
            : ProjectMoveRefusal.notAllowed,
      );
    }
    return MoveProject(
      projectId: projectId,
      position: position,
      parentProjectId: parentProjectId,
    );
  }
}

/// `compareProjects` for a project at another position.
int _compare(double aPosition, String aTitle, double bPosition, String bTitle) {
  final byPosition = aPosition.compareTo(bPosition);
  return byPosition != 0 ? byPosition : compareTitles(aTitle, bTitle);
}
