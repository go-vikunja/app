import 'dart:async';
import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/service/services.dart';

class ListAPIService extends APIService implements ListService {
  FlutterSecureStorage _storage;
  ListAPIService(Client client, FlutterSecureStorage storage) : _storage = storage, super(client);

  @override
  Future<TaskList> create(namespaceId, TaskList tl) {
    tl.namespaceId = namespaceId;
    return client
        .put('/namespaces/$namespaceId/lists', body: tl.toJSON())
        .then((response) => TaskList.fromJson(response.body));
  }

  @override
  Future delete(int listId) {
    return client.delete('/lists/$listId').then((_) {});
  }

  @override
  Future<TaskList> get(int listId) {
    return client.get('/lists/$listId').then((response) {
      final map = response.body;
      if (map.containsKey('id')) {
        return client
            .get("/lists/$listId/tasks")
            .then((tasks) {
              map['tasks'] = tasks.body;
              return TaskList.fromJson(map);
            });
      }
      return TaskList.fromJson(map);
    });
  }

  @override
  Future<List<TaskList>> getAll() {
    return client.get('/lists').then(
        (list) => convertList(list.body, (result) => TaskList.fromJson(result)));
  }

  @override
  Future<List<TaskList>> getByNamespace(int namespaceId) {
    // TODO there needs to be a better way for this. /namespaces/-2/lists should
    // return favorite lists
    if(namespaceId == -2) {
      // Favourites.
      return getAll().then((value) {value.removeWhere((element) => !element.isFavorite); return value;});
    }
    return client.get('/namespaces/$namespaceId/lists').then(
        (list) => convertList(list.body, (result) => TaskList.fromJson(result)));
  }

  @override
  Future<TaskList> update(TaskList tl) {
    return client
        .post('/lists/${tl.id}', body: tl.toJSON())
        .then((response) => TaskList.fromJson(response.body));
  }

  @override
  Future<String> getDisplayDoneTasks(int listId) {
    return _storage.read(key: "display_done_tasks_list_$listId").then((value)
    {
      if(value == null) {
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
