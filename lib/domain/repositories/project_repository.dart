import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<Response<Project>> create(Project p);

  Future<Response<List<Project>>> getAll();

  Future<Response<Project>> update(Project p);
}
