import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/project.dart';
import 'package:vikunja_app/service/services.dart';

class ProjectAPIService extends APIService implements ProjectService {
  ProjectAPIService(super.client);

  @override
  Future<Project?> create(Project p) {
    // TODO: implement create
    throw UnimplementedError();
  }

  @override
  Future delete(int projectId) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<Project?> get(int projectId) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<List<Project>?> getAll() {
    // TODO: implement getAll
    return client.get('/projects').then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => Project.fromJson(result));
    });
  }

  @override
  Future<Project?> update(int projectId) {
    // TODO: implement update
    throw UnimplementedError();
  }

}