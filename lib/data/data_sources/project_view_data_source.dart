import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/project_view_dto.dart';

class ProjectViewDataSource extends RemoteDataSource {
  ProjectViewDataSource(client) : super(client);

  Future<ProjectViewDto?> update(ProjectViewDto view) {
    print(view.toJSON());
    return client
        .post(
          '/projects/${view.projectId}/views/${view.id}',
          body: view.toJSON(),
        )
        .then((response) {
          if (response == null) return null;
          return ProjectViewDto.fromJson(response.body);
        });
  }
}
