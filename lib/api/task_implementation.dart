import 'dart:async';

import 'package:fluttering_vikunja/api/client.dart';
import 'package:fluttering_vikunja/api/service.dart';
import 'package:fluttering_vikunja/models/task.dart';
import 'package:fluttering_vikunja/service/services.dart';

class TaskAPIService extends APIService implements TaskService {
  TaskAPIService(Client client) : super(client);

  @override
  Future<Task> add(int listId, Task task) {
    return client
        .put('/lists/$listId', body: task.toJSON())
        .then((map) => Task.fromJson(map));
  }

  @override
  Future delete(int taskId) {
    return client.delete('/tasks/$taskId');
  }

  @override
  Future<Task> update(Task task) {
    return client
        .post('/tasks/${task.id}', body: task.toJSON())
        .then((map) => Task.fromJson(map));
  }
}
