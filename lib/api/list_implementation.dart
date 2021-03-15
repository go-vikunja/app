import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/service/services.dart';

class ListAPIService extends APIService implements ListService {
  ListAPIService(Client client) : super(client);

  @override
  Future<TaskList> create(namespaceId, TaskList tl) {
    return client
        .put('/namespaces/$namespaceId/lists', body: tl.toJSON())
        .then((map) => TaskList.fromJson(map));
  }

  @override
  Future delete(int listId) {
    return client.delete('/lists/$listId').then((_) {});
  }

  @override
  Future<TaskList> get(int listId) {
    return client.get('/lists/$listId').then((map) {
      if (map.containsKey('id')) {
        return client.get("/lists/$listId/tasks").then((tasks) => TaskList.fromJson(
            map, tasksJson: tasks));
      }
      return TaskList.fromJson(map);
    });
  }

  @override
  Future<List<TaskList>> getAll() {
    return client.get('/lists').then(
        (list) => convertList(list, (result) => TaskList.fromJson(result)));
  }

  @override
  Future<List<TaskList>> getByNamespace(int namespaceId) {
    return client.get('/namespaces/$namespaceId/lists').then(
        (list) => convertList(list, (result) => TaskList.fromJson(result)));
  }

  @override
  Future<TaskList> update(TaskList tl) {
    return client
        .post('/lists/${tl.id}', body: tl.toJSON())
        .then((map) => TaskList.fromJson(map));
  }
}
