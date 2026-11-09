import 'package:vikunja_domain/vikunja_domain.dart';

/// The server's trash (Vikunja 2.8.0 and later), online only and never
/// stored. Every call throws the `VikunjaFailure`, offline a
/// `NetworkFailure`. Restores go through `TaskRepository.restoreTask` and
/// `ProjectRepository.restoreProject`, which store what comes back.
abstract interface class TrashRepository {
  /// The trashed tasks of the projects the user may write to, newest
  /// deletion first.
  Future<List<TrashedTask>> tasks();

  /// The topmost trashed projects the user is admin of, newest deletion
  /// first, each with its trashed subprojects.
  Future<List<TrashedProject>> projects();

  /// What [emptyTasks] would delete for good.
  Future<TrashCount> taskCount();

  /// What [emptyProjects] would delete for good.
  Future<TrashCount> projectCount();

  /// Deletes for good the trashed tasks in the projects the user is admin
  /// of, those other people moved there included.
  Future<void> emptyTasks();

  /// Deletes for good the trashed projects the user is admin of, those
  /// other people moved there included.
  Future<void> emptyProjects();

  Future<void> deleteTaskForever(int taskId);

  Future<void> deleteProjectForever(int projectId);
}
