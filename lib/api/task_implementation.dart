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
  Future<Task> get(int listId) {
    return client
        .get('/list/$listId/tasks')
        .then((response) => Task.fromJson(response.body));
  }

  @override
  Future delete(int taskId) {
    return client
        .delete('/tasks/$taskId');
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
        .then((response) {
          int page_n = 0;
          if (response.headers["x-pagination-total-pages"] != null) {
            page_n = int.parse(response.headers["x-pagination-total-pages"]);
          } else {
            return Future.value(response.body);
          }

          List<Future<void>> futureList = [];
          List<Task> taskList = [];

          for(int i = 0; i < page_n; i++) {
            Map<String, List<String>> paramMap = {
              "page": [i.toString()]
            };
            futureList.add(client.get('/tasks/all', paramMap).then((pageResponse) { convertList(pageResponse.body, (result) {taskList.add(Task.fromJson(result));});}));
          }
          return Future.wait(futureList).then((value) {
            return taskList;
          });
    });
  }

  @override
  Future<Response> getAllByList(int listId,
      [Map<String, List<String>> queryParameters]) {
    return client
        .get('/lists/$listId/tasks', queryParameters).then(
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
          return  convertList(value.body, (result) => Task.fromJson(result));
    });
  }

  @override
  // TODO: implement maxPages
  int get maxPages => maxPages;

}
