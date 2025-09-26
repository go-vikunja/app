import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';

class ProjectViewDataSource extends RemoteDataSource {
  ProjectViewDataSource(super.client);

  Future<Response<ProjectViewDto>> update(ProjectViewDto view) {
    return client.post(
      url: '/projects/${view.projectId}/views/${view.id}',
      body: view.toJSON(),
      mapper: (body) {
        return ProjectViewDto.fromJson(body);
      },
    );
  }
}
