import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/project.dart';
import 'package:vikunja_app/service/services.dart';

class ProjectAPIService extends APIService implements ProjectService {
  FlutterSecureStorage _storage;

  ProjectAPIService(client, storage)
      : _storage = storage,
        super(client);

  @override
  Future<Project?> create(Project p) {
    return client.put('/projects', body: p.toJSON()).then((response) {
      if (response == null) return null;
      return Project.fromJson(response.body);
    });
  }

  @override
  Future delete(int projectId) {
    return client.delete('/projects/$projectId').then((_) {});
  }

  @override
  Future<Project?> get(int projectId) {
    return client.get('/projects/$projectId').then((response) {
      if (response == null) return null;
      final map = response.body;
      /*if (map.containsKey('id')) {
        return client
            .get("/lists/$projectId/tasks")
            .then((tasks) {
          map['tasks'] = tasks?.body;
          return Project.fromJson(map);
        });
      }*/
      return Project.fromJson(map);
    });
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
  Future<Project?> update(Project p) {
    return client.post('/projects/${p.id}', body: p.toJSON()).then((response) {
      if (response == null) return null;
      return Project.fromJson(response.body);
    });
  }

  @override
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

  @override
  void setDisplayDoneTasks(int listId, String value) {
    _storage.write(key: "display_done_tasks_list_$listId", value: value);
  }

  @override
  Future<String?> getDefaultList() {
    return _storage.read(key: "default_list_id");
  }

  @override
  void setDefaultList(int? listId) {
    _storage.write(key: "default_list_id", value: listId.toString());
  }
}
