import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/project_access.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

/// [projectId] and every project below it, archived ones included: what
/// deleting it removes on the server.
Set<int> projectSubtreeIds(int projectId, List<Project> projects) {
  final childrenOf = <int, List<int>>{};
  for (final project in projects) {
    childrenOf.putIfAbsent(project.parentProjectId, () => []).add(project.id);
  }
  final ids = <int>{};
  final pending = [projectId];
  while (pending.isNotEmpty) {
    final id = pending.removeLast();
    if (ids.add(id)) pending.addAll(childrenOf[id] ?? const []);
  }
  return ids;
}

/// The projects that can hold a new or moved project, as the tree shows
/// them: neither archived nor only readable for the user (the server
/// refuses both) nor [movedProjectId] and its subprojects (a cycle).
List<ProjectTreeRow> parentCandidates(
  List<Project> projects, {
  int? movedProjectId,
}) {
  final excluded = movedProjectId == null
      ? const <int>{}
      : projectSubtreeIds(movedProjectId, projects);
  return [
    for (final row in flattenProjectTree(
      buildProjectTree([
        for (final project in projects)
          if (ProjectAccess.of(project).canCreateChild) project,
      ]),
      collapsedIds: const {},
    ))
      if (!excluded.contains(row.node.project.id)) row,
  ];
}

/// A list view's filter as its form shows it: the web's default
/// `done = false` as a "Show done tasks" switch, and what else the filter
/// says.
typedef ListFilterParts = ({bool showDone, String rest});

ListFilterParts splitListFilter(String filter) {
  final trimmed = filter.trim();
  if (_openOnly.hasMatch(trimmed)) return (showDone: false, rest: '');
  if (_openOnlyAnd.firstMatch(trimmed) case final match?) {
    final rest = match[1]!.trim();
    final group = _innerOfGroup(rest);
    // Without its own brackets the rest joins on the same level, and the
    // order of `&&` and `||` would change when joined again.
    if (group != null) return (showDone: false, rest: group);
    if (!rest.contains('||')) return (showDone: false, rest: rest);
  }
  return (showDone: true, rest: trimmed);
}

String joinListFilter(ListFilterParts parts) {
  final rest = parts.rest.trim();
  if (parts.showDone) return rest;
  if (rest.isEmpty) return 'done = false';
  return rest.contains('||')
      ? 'done = false && ($rest)'
      : 'done = false && $rest';
}

final _openOnly = RegExp(r'^done\s*=\s*(false|0)$', caseSensitive: false);
final _openOnlyAnd = RegExp(
  r'^done\s*=\s*(?:false|0)\s*&&(.+)$',
  caseSensitive: false,
  dotAll: true,
);

/// What is inside the brackets when [text] is one bracketed group.
String? _innerOfGroup(String text) {
  if (!text.startsWith('(') || !text.endsWith(')')) return null;
  var depth = 0;
  for (var index = 0; index < text.length; index++) {
    switch (text[index]) {
      case '(':
        depth++;
      case ')':
        depth--;
        if (depth == 0 && index < text.length - 1) return null;
    }
  }
  return depth == 0 ? text.substring(1, text.length - 1).trim() : null;
}
