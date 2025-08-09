import 'dart:async';

import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/core/services.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

class TaskRepositoryImpl extends TaskRepository {
  TaskDataSource _dataSource;

  TaskRepositoryImpl(this._dataSource);

  Future<Task?> add(int projectId, Task task) async {
    return (await _dataSource.add(projectId, TaskDto.fromDomain(task)))
        ?.toDomain();
  }

  Future<Task?> get(int listId) async {
    return (await _dataSource.get(listId))?.toDomain();
  }

  Future delete(int taskId) async {
    return (await _dataSource.delete(taskId))?.toDomain();
  }

  Future<Task?> update(Task task) async {
    return (await _dataSource.update(TaskDto.fromDomain(task)))?.toDomain();
  }

  Future<List<Task>?> getAll() async {
    return (await _dataSource.getAll())?.map((e) => e.toDomain()).toList();
  }

  Future<Response?> getAllByProject(int projectId,
      [Map<String, List<String>>? queryParameters]) async {
    return _dataSource.getAllByProject(projectId);
  }

  @deprecated
  Future<List<Task>?> getByOptions(TaskServiceOptions options) async {
    return (await _dataSource.getByOptions(options))
        ?.map((e) => e.toDomain())
        .toList();
  }

  Future<List<Task>?> getByFilterString(String filterString,
      [Map<String, List<String>>? queryParameters]) async {
    return (await _dataSource.getByFilterString(filterString))
        ?.map((e) => e.toDomain())
        .toList();
  }

  // TODO: implement maxPages
  int get maxPages => maxPages;
}
