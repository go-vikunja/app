import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

/// Where a new task goes unless the user picks: [currentProjectId], else
/// the user's [defaultProjectId] (`UserSettings.defaultProjectId`), each
/// only when it is a project the task can live in and the user may add
/// tasks to, else the project titled Inbox, else the first project of the
/// tree. Null without any project.
Project? defaultProjectFor(
  List<Project> projects, {
  int? currentProjectId,
  int? defaultProjectId,
}) {
  final tree = buildProjectTree(writableProjects(projects));
  if (tree.isEmpty) return null;
  final candidates = [for (final node in tree) ..._flatten(node)];
  for (final preferred in [currentProjectId, defaultProjectId].nonNulls) {
    for (final project in candidates) {
      if (project.id == preferred) return project;
    }
  }
  for (final project in candidates) {
    if (project.title.trim().toLowerCase() == 'inbox') return project;
  }
  return candidates.first;
}

Iterable<Project> _flatten(ProjectNode node) sync* {
  yield node.project;
  for (final child in node.children) {
    yield* _flatten(child);
  }
}

/// [projects] without those the user may only read, where the server
/// refuses new tasks and tasks moved in.
List<Project> writableProjects(List<Project> projects) => [
  for (final project in projects)
    if (ProjectAccess.of(project).canAddTasks) project,
];

/// The projects a task can be moved to or created in, as the tree shows
/// them, with their depth for indentation.
List<ProjectTreeRow> selectableProjects(List<Project> projects) =>
    flattenProjectTree(buildProjectTree(projects), collapsedIds: const {});
