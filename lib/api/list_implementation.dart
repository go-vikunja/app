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
    return client.get('/lists/$listId').then((listmap) {
      return client.get('/lists/$listId/tasks').then((value) {
        listmap["tasks"] = value;
        return TaskList.fromJson(listmap);
      });
    }
  );
  }

  @override
  Future<List<TaskList>> getAll() {
    return client.get('/lists').then(
        (list) => convertList(list, (result) => TaskList.fromJson(result)));
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
        (list) => convertList(list, (result) => TaskList.fromJson(result)));
  }

  @override
  Future<TaskList> update(TaskList tl) {
    return client
        .post('/lists/${tl.id}', body: tl.toJSON())
        .then((map) => TaskList.fromJson(map));
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
}
