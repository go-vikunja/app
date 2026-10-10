import 'package:vikunja_domain/vikunja_domain.dart';

/// Archived projects and their descendants, ascending: `GET /tasks` leaves
/// their tasks out, so they are pulled through their project.
List<int> archivedProjectIds(Iterable<Project> projects) {
  final parentOf = {for (final p in projects) p.id: p.parentProjectId};
  final archived = {
    for (final p in projects)
      if (p.isArchived) p.id,
  };
  bool isArchived(int id) {
    final seen = <int>{};
    for (var current = id; seen.add(current); current = parentOf[current]!) {
      if (archived.contains(current)) return true;
      if (!parentOf.containsKey(current)) return false;
    }
    return false;
  }

  return [
    for (final p in projects)
      if (isArchived(p.id)) p.id,
  ]..sort();
}
