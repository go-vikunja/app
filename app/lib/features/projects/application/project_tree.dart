import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

@immutable
final class ProjectNode {
  const new(this.project, {this.children = const []});

  final Project project;
  final List<ProjectNode> children;
}

/// One row of the flattened tree.
@immutable
final class ProjectTreeRow {
  const new(this.node, {required this.depth});

  final ProjectNode node;
  final int depth;
}

/// Position first, then title, like the web's sidebar.
int compareProjects(Project a, Project b) {
  final byPosition = a.position.compareTo(b.position);
  if (byPosition != 0) return byPosition;
  return compareTitles(a.title, b.title);
}

/// Hides pseudo projects, and archived ones unless [includeArchived] (the
/// Projects tab's choice; pickers and defaults never offer them). A child
/// whose parent is hidden or unknown is shown at the top level.
List<ProjectNode> buildProjectTree(
  List<Project> projects, {
  bool includeArchived = false,
}) {
  final visible = [
    for (final project in projects)
      if ((includeArchived || !project.isArchived) && !project.isPseudo)
        project,
  ]..sort(compareProjects);
  final ids = {for (final project in visible) project.id};
  final childrenOf = <int, List<Project>>{};
  for (final project in visible) {
    final parent = ids.contains(project.parentProjectId)
        ? project.parentProjectId
        : 0;
    childrenOf.putIfAbsent(parent, () => []).add(project);
  }

  final placed = <int>{};
  List<ProjectNode> nodesUnder(int parentId) => [
    for (final project in childrenOf[parentId] ?? const <Project>[])
      if (placed.add(project.id))
        ProjectNode(project, children: nodesUnder(project.id)),
  ];
  final tree = nodesUnder(0);
  // Members of a parent cycle are reachable from no root.
  return [
    ...tree,
    for (final project in visible)
      if (!placed.contains(project.id)) ProjectNode(project),
  ];
}

List<Project> favouriteProjects(List<Project> projects) => [
  for (final project in projects)
    if (project.isFavorite && !project.isArchived && !project.isPseudo) project,
]..sort(compareProjects);

List<ProjectTreeRow> flattenProjectTree(
  List<ProjectNode> nodes, {
  required Set<int> collapsedIds,
  int depth = 0,
}) => [
  for (final node in nodes) ...[
    ProjectTreeRow(node, depth: depth),
    if (!collapsedIds.contains(node.project.id))
      ...flattenProjectTree(
        node.children,
        collapsedIds: collapsedIds,
        depth: depth + 1,
      ),
  ],
];
