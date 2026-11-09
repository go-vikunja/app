import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

/// Of [tasks], those a share can go into: outside archived projects (the
/// server refuses their writes), with the trimmed [query] in the title or
/// the identifier, ignoring case and accents. At most [limit].
List<Task> shareTargets(
  Iterable<Task> tasks, {
  required String query,
  required Map<int, Project> projectsById,
  int limit = 50,
}) {
  final needle = foldForSearch(query.trim());
  bool matches(Task task) =>
      needle.isEmpty ||
      foldForSearch(task.title).contains(needle) ||
      (task.id > 0 && foldForSearch(task.displayIdentifier).contains(needle));
  return [
    for (final task in tasks)
      if (!isArchivedInTree(task.projectId, projectsById) && matches(task))
        task,
  ].take(limit).toList();
}
