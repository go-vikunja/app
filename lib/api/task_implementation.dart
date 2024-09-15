import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/response.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/service/services.dart';

class TaskAPIService extends APIService implements TaskService {
  TaskAPIService(Client client) : super(client);

  @override
  Future<Task?> add(int projectId, Task task) {
    return client
        .put('/projects/$projectId/tasks', body: task.toJSON())
        .then((response) {
      if (response == null) return null;
      return Task.fromJson(response.body);
    });
  }

  @override
  Future<Task?> get(int listId) {
    return client.get('/project/$listId/tasks').then((response) {
      if (response == null) return null;
      return Task.fromJson(response.body);
    });
  }

  @override
  Future delete(int taskId) {
    return client.delete('/tasks/$taskId');
  }

  @override
  Future<Task?> update(Task task) {
    return client
        .post('/tasks/${task.id}', body: task.toJSON())
        .then((response) {
      if (response == null) return null;
      return Task.fromJson(response.body);
    });
  }

  @override
  Future<List<Task>?> getAll() {
    return client.get('/tasks/all').then((response) {
      int page_n = 0;
      if (response == null) return null;
      if (response.headers["x-pagination-total-pages"] != null) {
        page_n = int.parse(response.headers["x-pagination-total-pages"]!);
      } else {
        return Future.value(response.body);
      }

      List<Future<void>> futureList = [];
      List<Task> taskList = [];

      for (int i = 0; i < page_n; i++) {
        Map<String, List<String>> paramMap = {
          "page": [i.toString()]
        };
        futureList.add(client.get('/tasks/all', paramMap).then((pageResponse) {
          convertList(pageResponse?.body, (result) {
            taskList.add(Task.fromJson(result));
          });
        }));
      }
      return Future.wait(futureList).then((value) {
        return taskList;
      });
    });
  }

  @override
  Future<Response?> getAllByProject(int projectId,
      [Map<String, List<String>>? queryParameters]) {
    return client
        .get('/projects/$projectId/tasks', queryParameters)
        .then((response) {
      return response != null
          ? new Response(
              convertList(response.body, (result) => Task.fromJson(result)),
              response.statusCode,
              response.headers)
          : null;
    });
  }

  @override
  @deprecated
  Future<List<Task>?> getByOptions(TaskServiceOptions options) {
    Map<String, List<String>> optionsMap = options.getOptions();
    //optionString = "?sort_by[]=due_date&sort_by[]=id&order_by[]=asc&order_by[]=desc&filter_by[]=done&filter_value[]=false&filter_comparator[]=equals&filter_concat=and&filter_include_nulls=false&page=1";
    //print(optionString);

    return client.get('/tasks/all', optionsMap).then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => Task.fromJson(result));
    });
  }

  @override
  Future<List<Task>?> getByFilterString(String filterString,
      [Map<String, List<String>>? queryParameters]) {
    Map<String, List<String>> parameters = {
      "filter": [filterString],
      ...?queryParameters
    };
    print(parameters);
    return client.get('/tasks/all', parameters).then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => Task.fromJson(result));
    });
  }

  @override
  // TODO: implement maxPages
  int get maxPages => maxPages;
}
