import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

class TaskRepositoryImpl extends TaskRepository {
  final TaskDataSource _dataSource;

  TaskRepositoryImpl(this._dataSource);

  @override
  Future<Response<Task>> add(int projectId, Task task) async {
    return (await _dataSource.add(
      projectId,
      TaskDto.fromDomain(task),
    )).toDomain();
  }

  @override
  Future<Response<Object>> delete(int taskId) async {
    return _dataSource.delete(taskId);
  }

  @override
  Future<Response<Task>> update(Task task) async {
    return (await _dataSource.update(TaskDto.fromDomain(task))).toDomain();
  }

  @override
  Future<Response<Task>> getTask(int id) async {
    return (await _dataSource.getTask(id)).toDomain();
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    var response = await _dataSource.getAllByProject(
      projectId,
      queryParameters,
    );

    return response.toDomain();
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    return (await _dataSource.getByFilterString(filterString)).toDomain();
  }

  @override
  Future<String?> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) async {
    return _dataSource.downloadAttachment(
      taskId,
      TaskAttachmentDto.fromDomain(attachment),
    );
  }
}
