import 'package:vikunja_app/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<Project?> create(Project p);

  Future delete(int projectId);

  Future<Project?> get(int projectId);

  Future<List<Project>?> getAll();

  Future<Project?> update(Project p);

  Future<String> getDisplayDoneTasks(int listId);

  void setDisplayDoneTasks(int listId, String value);
}
