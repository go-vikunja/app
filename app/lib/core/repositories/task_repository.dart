import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/paged_list.dart';

/// Tasks as this device knows them; the same stream and error rules as
/// `ProjectRepository`. Project tasks are paged: [loadMoreProjectTasks]
/// appends the next page and throws on failure.
abstract interface class TaskRepository {
  /// Open tasks across all projects, nearest due date first.
  Stream<List<Task>> watchOpenTasks();

  Stream<PagedList<Task>> watchProjectTasks(
    int projectId, {
    required bool showDone,
  });

  Future<void> refreshOpenTasks();

  Future<void> refreshProjectTasks(int projectId, {required bool showDone});

  Future<void> loadMoreProjectTasks(int projectId, {required bool showDone});

  void dispose();
}
