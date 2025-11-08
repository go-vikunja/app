import 'dart:async';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

class TaskDataSource extends RemoteDataSource {
  TaskDataSource(super.client);

  Future<Response<TaskDto>> add(int projectId, TaskDto task) {
    return client.put(
      url: '/projects/$projectId/tasks',
      body: task.toJSON(),
      mapper: (body) {
        return TaskDto.fromJson(body);
      },
    );
  }

  Future<Response<Object>> delete(int taskId) async {
    return client.delete(url: '/tasks/$taskId');
  }

  Future<Response<TaskDto>> update(TaskDto task) async {
    return await client.post(
      url: '/tasks/${task.id}',
      body: task.toJSON(),
      mapper: (body) {
        return TaskDto.fromJson(body);
      },
    );
  }

  Future<Response<List<TaskDto>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return client.get(
      url: '/projects/$projectId/tasks',
      mapper: (body) {
        return convertList(body, (result) => TaskDto.fromJson(result));
      },
      queryParameters: queryParameters,
    );
  }

  Future<Response<TaskDto>> getTask(int taskId) async {
    return await client.get(
      url: '/tasks/${taskId}',
      mapper: (body) {
        return TaskDto.fromJson(body);
      }
    );
  }

  Future<Response<List<TaskDto>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    Map<String, List<String>> parameters = {
      "filter": [filterString],
      ...?queryParameters,
    };

    return await client.get(
      url: '/tasks/all',
      mapper: (body) {
        return convertList(body, (result) => TaskDto.fromJson(result));
      },
      queryParameters: parameters,
    );
  }

  Future<String?> downloadAttachment(
    int taskId,
    TaskAttachmentDto attachment,
  ) async {
    String url = client.base;
    url += '/tasks/$taskId/attachments/${attachment.id}';

    var savedDir = (await getDownloadsDirectory())?.path;
    if (savedDir != null) {
      return await FlutterDownloader.enqueue(
        url: url,
        fileName: attachment.file.name,
        headers: client.headers,
        savedDir: savedDir,
      );
    }
    return null;
  }
}
