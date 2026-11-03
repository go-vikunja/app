import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/offline/offline_controller.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/local/offline_codec.dart';
import 'package:vikunja_app/data/local/offline_database.dart';
import 'package:vikunja_app/data/models/project_dto.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl extends ProjectRepository {
  final ProjectDataSource _dataSource;
  final OfflineDatabase? _offline;
  final bool isOffline;
  final Future<void> Function()? onQueued;

  ProjectRepositoryImpl(
    this._dataSource, {
    OfflineDatabase? offline,
    this.isOffline = false,
    this.onQueued,
  }) : _offline = offline;

  @override
  Future<Response<Project>> create(Project p) async {
    if (isOffline && _offline != null) {
      final localId = await _offline.nextLocalId('cached_projects');
      final stored = p.copyWith(id: localId);
      await _offline.upsertProject(stored);
      await _offline.enqueue('project.create', {
        'localId': localId,
        'project': projectToCache(stored),
      });
      await onQueued?.call();
      return offlineSuccess<Project>(stored);
    }

    final response = (await _dataSource.create(
      ProjectDto.fromDomain(p),
    )).toDomain<Project>();
    if (response.isSuccessful) {
      await _offline?.upsertProject(response.toSuccess().body);
    }
    return response;
  }

  @override
  Future<Response<List<Project>>> getAll({int page = 1}) async {
    if (isOffline && _offline != null) {
      return offlineSuccess<List<Project>>(await _offline.allProjects());
    }

    Response<List<Project>> projectsResponse = (await _dataSource.getAll(
      page: page,
    )).toDomain();

    if (projectsResponse.isSuccessful) {
      var successResponse = (projectsResponse as SuccessResponse);
      await _offline?.upsertProjects(successResponse.body);

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
    if (isOffline && _offline != null) {
      await _offline.upsertProject(p);
      await _offline.enqueue('project.update', {'project': projectToCache(p)});
      await onQueued?.call();
      return offlineSuccess<Project>(p);
    }

    final response = (await _dataSource.update(
      ProjectDto.fromDomain(p),
    )).toDomain<Project>();
    if (response.isSuccessful) {
      await _offline?.upsertProject(response.toSuccess().body);
    }
    return response;
  }
}
