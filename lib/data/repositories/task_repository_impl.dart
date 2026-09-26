import 'dart:async';

import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate;
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/offline/offline_controller.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/local/offline_codec.dart';
import 'package:vikunja_app/data/local/offline_database.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

class TaskRepositoryImpl extends TaskRepository {
  final TaskDataSource _dataSource;
  final OfflineDatabase? _offline;
  final bool isOffline;
  final Future<void> Function()? onQueued;

  TaskRepositoryImpl(
    this._dataSource, {
    OfflineDatabase? offline,
    this.isOffline = false,
    this.onQueued,
  }) : _offline = offline;

  @override
  Future<Response<Task>> add(int projectId, Task task) async {
    if (isOffline && _offline != null) {
      final localId = await _offline.nextLocalId('cached_tasks');
      final stored = task.copyWith(id: localId, projectId: projectId);
      await _offline.upsertTask(stored);
      await _offline.enqueue('task.create', {
        'projectId': projectId,
        'task': taskToCache(stored),
      });
      await onQueued?.call();
      return offlineSuccess<Task>(stored);
    }

    final response = (await _dataSource.add(
      projectId,
      TaskDto.fromDomain(task),
    )).toDomain<Task>();
    if (response.isSuccessful) {
      await _offline?.upsertTask(response.toSuccess().body);
    }
    return response;
  }

  @override
  Future<Response<Object>> delete(int taskId) async {
    if (isOffline && _offline != null) {
      await _offline.deleteTask(taskId);
      if (taskId < 0) {
        await _offline.deleteMutationsForTask(taskId);
      } else {
        await _offline.enqueue('task.delete', {'id': taskId});
      }
      await onQueued?.call();
      return offlineSuccess<Object>(Object());
    }

    final response = await _dataSource.delete(taskId);
    if (response.isSuccessful) {
      await _offline?.deleteTask(taskId);
    }
    return response;
  }

  @override
  Future<Response<Task>> update(Task task) async {
    if (isOffline && _offline != null) {
      await _offline.upsertTask(task);
      await _offline.enqueue('task.update', {'task': taskToCache(task)});
      await onQueued?.call();
      return offlineSuccess<Task>(task);
    }

    final response = (await _dataSource.update(
      TaskDto.fromDomain(task),
    )).toDomain<Task>();
    if (response.isSuccessful) {
      await _offline?.upsertTask(response.toSuccess().body);
    }
    return response;
  }

  @override
  Future<Response<Task>> getTask(int id) async {
    if (isOffline && _offline != null) {
      final cached = await _offline.getTask(id);
      if (cached != null) return offlineSuccess<Task>(cached);
      return ExceptionResponse<Task>(
        StateError('Task $id not cached'),
        StackTrace.current,
      );
    }

    final response = (await _dataSource.getTask(id)).toDomain<Task>();
    if (response.isSuccessful) {
      await _offline?.upsertTask(response.toSuccess().body);
    }
    return response;
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    if (isOffline && _offline != null) {
      return offlineSuccess<List<Task>>(
        await _offline.tasksByProject(projectId),
      );
    }

    var response = await _dataSource.getAllByProject(
      projectId,
      queryParameters,
    );
    final mapped = response.toDomain<Task>();
    if (mapped.isSuccessful) {
      await _offline?.upsertTasks(mapped.toSuccess().body);
    }
    return mapped;
  }

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    if (isOffline && _offline != null) {
      return offlineSuccess<List<Task>>(
        await _offline.tasksByProject(projectId),
      );
    }

    var response = await _dataSource.getAllByProjectView(
      projectId,
      view,
      queryParameters,
    );
    final mapped = response.toDomain<Task>();
    if (mapped.isSuccessful) {
      await _offline?.upsertTasks(mapped.toSuccess().body);
    }
    return mapped;
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    if (isOffline && _offline != null) {
      return offlineSuccess<List<Task>>(
        await _offline.tasksByFilter(filterString),
      );
    }

    final mapped = (await _dataSource.getByFilterString(
      filterString,
      queryParameters,
    )).toDomain<Task>();
    if (mapped.isSuccessful) {
      await _offline?.upsertTasks(mapped.toSuccess().body);
    }
    return mapped;
  }

  @override
  Future<Response<List<Task>>> search(String query) async {
    if (isOffline && _offline != null) {
      final needle = query.toLowerCase();
      final matches = (await _offline.allTasks())
          .where(
            (task) =>
                task.title.toLowerCase().contains(needle) ||
                task.identifier.toLowerCase().contains(needle),
          )
          .toList();
      return offlineSuccess<List<Task>>(matches);
    }

    return (await _dataSource.search(query)).toDomain<Task>();
  }

  @override
  Future<Response<Object>> addRelation({
    required int taskId,
    required int otherTaskId,
    required RelationKind kind,
  }) async {
    if (isOffline) {
      return ExceptionResponse<Object>(
        StateError('Relations require an online connection'),
        StackTrace.current,
      );
    }
    return _dataSource.addRelation(
      taskId: taskId,
      otherTaskId: otherTaskId,
      relationKind: kind.apiValue,
    );
  }

  @override
  Future<Response<Object>> deleteRelation({
    required int taskId,
    required int otherTaskId,
    required RelationKind kind,
  }) async {
    if (isOffline) {
      return ExceptionResponse<Object>(
        StateError('Relations require an online connection'),
        StackTrace.current,
      );
    }
    return _dataSource.deleteRelation(
      taskId: taskId,
      otherTaskId: otherTaskId,
      relationKind: kind.apiValue,
    );
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) async {
    return _dataSource.downloadAttachment(
      taskId,
      TaskAttachmentDto.fromDomain(attachment),
    );
  }
}
