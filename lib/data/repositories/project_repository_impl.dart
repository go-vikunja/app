import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl extends ProjectRepository {
  ProjectDataSource _dataSource;

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
  Future<List<Project>?> getAll() async {
    return (await _dataSource.getAll())?.map((e) => e.toDomain()).toList();
  }

  @override
  Future<Project?> update(Project p) async {
    return (await _dataSource.update(ProjectDto.fromDomain(p)))?.toDomain();
  }

  @override
  Future<String> getDisplayDoneTasks(int listId) async {
    return _dataSource.getDisplayDoneTasks(listId);
  }

  @override
  void setDisplayDoneTasks(int listId, String value) {
    _dataSource.setDisplayDoneTasks(listId, value);
  }
}
