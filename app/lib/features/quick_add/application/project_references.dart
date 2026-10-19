import 'package:vikunja_domain/vikunja_domain.dart';

/// The projects a `+project` named [name] stands for among [candidates]
/// (the ones a task can go to, in tree order): those with that title,
/// ignoring case, else those with that identifier. Quick add takes the
/// first.
List<Project> projectsNamed(String name, List<Project> candidates) {
  final lower = name.toLowerCase();
  final byTitle = [
    for (final project in candidates)
      if (project.title.toLowerCase() == lower) project,
  ];
  if (byTitle.isNotEmpty) return byTitle;
  return [
    for (final project in candidates)
      if (project.identifier.isNotEmpty &&
          project.identifier.toLowerCase() == lower)
        project,
  ];
}

/// What a `+project` has to say for quick add to take exactly [project]:
/// its title, else its identifier; null when neither tells it apart from
/// the other [candidates].
String? projectReference(Project project, List<Project> candidates) {
  for (final reference in [project.title, project.identifier]) {
    if (reference.isEmpty) continue;
    final named = projectsNamed(reference, candidates);
    if (named.length == 1 && named.single.id == project.id) return reference;
  }
  return null;
}

/// [project]'s title, after its parents' when another of [projects] has
/// the same title: `Work › Backlog`. [titleOf] names each project shown.
String projectLabel(
  Project project,
  List<Project> projects, {
  String Function(Project project) titleOf = _serverTitle,
}) {
  final lower = project.title.toLowerCase();
  final shared = projects.any(
    (other) =>
        other.id != project.id &&
        !other.isArchived &&
        other.title.toLowerCase() == lower,
  );
  if (!shared) return titleOf(project);
  final byId = {for (final other in projects) other.id: other};
  final titles = [titleOf(project)];
  final seen = {project.id};
  var parent = byId[project.parentProjectId];
  while (parent != null && seen.add(parent.id)) {
    titles.insert(0, titleOf(parent));
    parent = byId[parent.parentProjectId];
  }
  return titles.join(' › ');
}

String _serverTitle(Project project) => project.title;
