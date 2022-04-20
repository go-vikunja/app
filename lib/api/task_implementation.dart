import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/service/services.dart';

class TaskAPIService extends APIService implements TaskService {
  TaskAPIService(Client client) : super(client);

  @override
  Future<Task> add(int listId, Task task) {
    return client
        .put('/lists/$listId', body: task.toJSON())
        .then((response) => Task.fromJson(response.body));
  }

  @override
  Future<Response> get(int listId) {
    return client.get('/list/$listId/tasks');
  }

  @override
  Future delete(int taskId) {
    return client.delete('/tasks/$taskId');
  }

  @override
  Future<Task> update(Task task) {
    return client
        .post('/tasks/${task.id}', body: task.toJSON())
        .then((response) => Task.fromJson(response.body));
  }

  @override
  Future<List<Task>> getAll() {
    return client
        .get('/tasks/all')
        .then((value) => value.body.map<Task>((taskJson) => Task.fromJson(taskJson)).toList());
  }

  @override
  Future<Response> getAllByList(int listId,
      [Map<String, List<String>> queryParameters]) {
    return client.get('/lists/$listId/tasks', queryParameters).then(
            (response) => new Response(
            convertList(response.body, (result) => Task.fromJson(result)),
            response.statusCode,
            response.headers));
  }

  @override
  Future<List<Task>> getByOptions(TaskServiceOptions options) {
    String optionString = options.getOptions();
    return client
        .get('/tasks/all?$optionString')
        .then((value) {
          return  value.body.map<Task>((taskJson) => Task.fromJson(taskJson)).toList();
    });
  }

  @override
  // TODO: implement maxPages
  int get maxPages => maxPages;

}
