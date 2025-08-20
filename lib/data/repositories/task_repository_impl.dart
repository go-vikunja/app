import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/services.dart';
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
  Future<Task?> add(int projectId, Task task) async {
    return (await _dataSource.add(
      projectId,
      TaskDto.fromDomain(task),
    ))?.toDomain();
  }

  @override
  Future<Task?> get(int listId) async {
    return (await _dataSource.get(listId))?.toDomain();
  }

  @override
  Future delete(int taskId) async {
    return (await _dataSource.delete(taskId));
  }

  @override
  Future<Task?> update(Task task) async {
    return (await _dataSource.update(TaskDto.fromDomain(task)))?.toDomain();
  }

  @override
  Future<List<Task>> getAll() async {
    return (await _dataSource.getAll()).map((e) => e.toDomain()).toList();
  }

  @override
  Future<Response<List<Task>>?> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    var response = await _dataSource.getAllByProject(projectId);

    return response != null
        ? Response(
            response.body.map((e) => e.toDomain()).toList(),
            response.statusCode,
            response.headers,
          )
        : null;
  }

  @override
  @deprecated
  Future<List<Task>?> getByOptions(TaskServiceOptions options) async {
    return (await _dataSource.getByOptions(
      options,
    ))?.map((e) => e.toDomain()).toList();
  }

  @override
  Future<List<Task>?> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    return (await _dataSource.getByFilterString(
      filterString,
    ))?.map((e) => e.toDomain()).toList();
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
