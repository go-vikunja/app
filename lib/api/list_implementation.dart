import 'dart:async';

import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/api/service.dart';
import 'package:fluttering_vikunja/models/task.dart';
import 'package:fluttering_vikunja/service/services.dart';

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
    return client.get('/lists/$listId').then((map) => TaskList.fromJson(map));
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
        .put('/lists/${tl.id}', body: tl.toJSON())
        .then((map) => TaskList.fromJson(map));
  }
}
