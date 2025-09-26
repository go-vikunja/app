import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';

abstract class ProjectViewRepository {
  Future<Response<ProjectView>> update(ProjectView view);
}
