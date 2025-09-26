import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/project_dto.dart';

class ProjectDataSource extends RemoteDataSource {
  ProjectDataSource(super.client);

  Future<Response<ProjectDto>> create(ProjectDto p) {
    return client.put(
      url: '/projects',
      body: p.toJSON(),
      mapper: (body) {
        return ProjectDto.fromJson(body);
      },
    );
  }

  Future<Response<ProjectDto>> get(int projectId) {
    return client.get(
      url: '/projects/$projectId',
      mapper: (body) {
        return ProjectDto.fromJson(body);
      },
    );
  }

  Future<Response<List<ProjectDto>>> getAll() {
    return client.get(
      url: '/projects',
      mapper: (body) {
        return convertList(body, (result) => ProjectDto.fromJson(result));
      },
    );
  }

  Future<Response<ProjectDto>> update(ProjectDto p) {
    return client.post(
      url: '/projects/${p.id}',
      body: p.toJSON(),
      mapper: (body) {
        return ProjectDto.fromJson(body);
      },
    );
  }
}
