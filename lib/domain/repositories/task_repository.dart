import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';

abstract class TaskRepository {
  Future<Response<Task>> add(int projectId, Task task);

  Future delete(int taskId);

  Future<Response<Task>> update(Task task);

  Future<Response<Task>> getTask(int id);

  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]);

  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]);

  Future<String?> downloadAttachment(int taskId, TaskAttachment attachment);
}
