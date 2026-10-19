import 'package:vikunja_domain/vikunja_domain.dart';

/// The identifier the web shows, from [project] when it is the task's: the
/// server keeps echoing the identifier a task had before it moved, while
/// the project's identifier and the task's index are current.
String taskIdentifierIn(Task task, Project? project) {
  if (project == null || project.id != task.projectId) {
    return task.displayIdentifier;
  }
  return project.identifier.isEmpty
      ? '#${task.index}'
      : '${project.identifier}-${task.index}';
}
