import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl extends ProjectRepository {
  final ProjectDataSource _dataSource;

  ProjectRepositoryImpl(this._dataSource);

  @override
  Future<Project?> create(Project p) async {
    return (await _dataSource.create(ProjectDto.fromDomain(p)))?.toDomain();
  }

  @override
  Future delete(int projectId) async {
    return _dataSource.delete(projectId);
  }

  @override
  Future<Project?> get(int projectId) async {
    return (await _dataSource.get(projectId))?.toDomain();
  }

  @override
  Future<List<Project>> getAll() async {
    var projects = (await _dataSource.getAll())
        .map((e) => e.toDomain())
        .toList();

    var topLevelProjects = projects
        .where((e) => e.parentProjectId == 0)
        .toList();
    topLevelProjects.forEach((topLevelProject) {
      findSubproject(topLevelProject, projects);
    });

    return topLevelProjects;
  }

  findSubproject(Project project, List<Project> projects) {
    project.subprojects = projects
        .where((e) => e.parentProjectId == project.id)
        .toList();
    project.subprojects.forEach((e) => findSubproject(e, projects));
  }

  @override
  Future<Project?> update(Project p) async {
    return (await _dataSource.update(ProjectDto.fromDomain(p)))?.toDomain();
  }
}
