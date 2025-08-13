import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/data/models/project_dto.dart';

class ProjectDataSource extends RemoteDataSource {
  FlutterSecureStorage _storage;

  ProjectDataSource(client, storage)
      : _storage = storage,
        super(client);

  Future<ProjectDto?> create(ProjectDto p) {
    return client.put('/projects', body: p.toJSON()).then((response) {
      if (response == null) return null;
      return ProjectDto.fromJson(response.body);
    });
  }

  Future delete(int projectId) {
    return client.delete('/projects/$projectId').then((_) {});
  }

  Future<ProjectDto?> get(int projectId) {
    return client.get('/projects/$projectId').then((response) {
      if (response == null) return null;
      final map = response.body;
      return ProjectDto.fromJson(map);
    });
  }

  Future<List<ProjectDto>> getAll() {
    return client.get('/projects').then((response) {
      if (response == null) return [];
      return convertList(
          response.body, (result) => ProjectDto.fromJson(result));
    });
  }

  Future<ProjectDto?> update(ProjectDto p) {
    return client.post('/projects/${p.id}', body: p.toJSON()).then((response) {
      if (response == null) return null;
      return ProjectDto.fromJson(response.body);
    });
  }

  Future<String> getDisplayDoneTasks(int listId) {
    return _storage.read(key: "display_done_tasks_list_$listId").then((value) {
      if (value == null) {
        // TODO: implement default value
        setDisplayDoneTasks(listId, "1");
        return Future.value("1");
      }
      return value;
    });
  }

  void setDisplayDoneTasks(int listId, String value) {
    _storage.write(key: "display_done_tasks_list_$listId", value: value);
  }
}
