import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/services.dart';
import 'package:vikunja_app/domain/entities/task.dart';

abstract class TaskRepository {
  Future<Task?> add(int projectId, Task task);

  Future<Task?> get(int listId);

  Future delete(int taskId);

  Future<Task?> update(Task task);

  Future<List<Task>?> getAll();

  Future<Response?> getAllByProject(int projectId,
      [Map<String, List<String>>? queryParameters]);

  @deprecated
  Future<List<Task>?> getByOptions(TaskServiceOptions options);

  Future<List<Task>?> getByFilterString(String filterString,
      [Map<String, List<String>>? queryParameters]);

  // TODO: implement maxPages
  int get maxPages => maxPages;
}
