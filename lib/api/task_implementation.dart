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
  Future<Response> getAll(int listId,
      [Map<String, List<String>> queryParameters]) {
    return client.get('/lists/$listId/tasks', queryParameters).then(
        (response) => new Response(
            convertList(response.body, (result) => Task.fromJson(result)),
            response.statusCode,
            response.headers));
  }

  @override
  int get maxPages => throw UnimplementedError();
}
