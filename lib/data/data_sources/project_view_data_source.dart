import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/view.dart';
import 'package:vikunja_app/core/services.dart';

class ProjectViewAPIService extends RemoteDataSource
    implements ProjectViewService {
  ProjectViewAPIService(client) : super(client);

  @override
  Future<ProjectView?> create(ProjectView view) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future delete(int projectId, int viewId) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<ProjectView?> get(int projectId, int viewId) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<ProjectView?> update(ProjectView view) {
    print(view.toJSON());
    return client
        .post('/projects/${view.projectId}/views/${view.id}',
            body: view.toJSON())
        .then((response) {
      if (response == null) return null;
      return ProjectView.fromJson(response.body);
    });
  }
}
