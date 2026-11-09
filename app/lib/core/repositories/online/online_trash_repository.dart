import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository.dart';

final class OnlineTrashRepository implements TrashRepository {
  new({required this._port});

  final TrashPort _port;

  @override
  Future<List<TrashedTask>> tasks() => _port.tasks();

  @override
  Future<List<TrashedProject>> projects() => _port.projects();

  @override
  Future<TrashCount> taskCount() => _port.taskCount();

  @override
  Future<TrashCount> projectCount() => _port.projectCount();

  @override
  Future<void> emptyTasks() => _port.emptyTasks();

  @override
  Future<void> emptyProjects() => _port.emptyProjects();

  @override
  Future<void> deleteTaskForever(int taskId) => _port.deleteTaskForever(taskId);

  @override
  Future<void> deleteProjectForever(int projectId) =>
      _port.deleteProjectForever(projectId);
}
