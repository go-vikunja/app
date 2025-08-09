import 'package:vikunja_app/domain/entities/project_view.dart';

abstract class ProjectViewRepository {
  Future<ProjectView?> update(ProjectView view);
}
