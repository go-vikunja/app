import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl extends ProjectRepository {
  final ProjectDataSource _dataSource;

  ProjectRepositoryImpl(this._dataSource);

  @override
  Future<Response<Project>> create(Project p) async {
    return (await _dataSource.create(ProjectDto.fromDomain(p))).toDomain();
  }

  @override
  Future<Response<List<Project>>> getAll({int page = 1}) async {
    Response<List<Project>> projectsResponse = (await _dataSource.getAll(
      page: page,
    )).toDomain();

    if (projectsResponse.isSuccessful) {
      var successResponse = (projectsResponse as SuccessResponse);

      return SuccessResponse(
        successResponse.body,
        successResponse.statusCode,
        successResponse.headers,
      );
    } else {
      return projectsResponse;
    }
  }

  @override
  Future<Response<Project>> update(Project p) async {
    return (await _dataSource.update(ProjectDto.fromDomain(p))).toDomain();
  }
}
