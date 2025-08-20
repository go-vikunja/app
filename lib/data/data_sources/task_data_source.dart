import 'dart:async';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/network/service.dart';
import 'package:vikunja_app/core/services.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

class TaskDataSource extends RemoteDataSource {
  TaskDataSource(super.client);

  Future<TaskDto?> add(int projectId, TaskDto task) {
    return client.put('/projects/$projectId/tasks', body: task.toJSON()).then((
      response,
    ) {
      if (response == null) return null;
      return TaskDto.fromJson(response.body);
    });
  }

  Future<TaskDto?> get(int listId) {
    return client.get('/project/$listId/tasks').then((response) {
      if (response == null) return null;
      return TaskDto.fromJson(response.body);
    });
  }

  Future delete(int taskId) {
    return client.delete('/tasks/$taskId');
  }

  Future<TaskDto?> update(TaskDto task) {
    return client.post('/tasks/${task.id}', body: task.toJSON()).then((
      response,
    ) {
      if (response == null) return null;
      return TaskDto.fromJson(response.body);
    });
  }

  Future<List<TaskDto>> getAll() {
    return client.get('/tasks/all').then((response) {
      int page_n = 0;
      if (response == null) return [];
      if (response.headers["x-pagination-total-pages"] != null) {
        page_n = int.parse(response.headers["x-pagination-total-pages"]!);
      } else {
        return Future.value(response.body);
      }

      List<Future<void>> futureList = [];
      List<TaskDto> taskList = [];

      for (int i = 0; i < page_n; i++) {
        Map<String, List<String>> paramMap = {
          "page": [i.toString()],
        };
        futureList.add(
          client.get('/tasks/all', paramMap).then((pageResponse) {
            convertList(pageResponse?.body, (result) {
              taskList.add(TaskDto.fromJson(result));
            });
          }),
        );
      }
      return Future.wait(futureList).then((value) {
        return taskList;
      });
    });
  }

  Future<Response<List<TaskDto>>?> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return client.get('/projects/$projectId/tasks', queryParameters).then((
      response,
    ) {
      return response != null
          ? Response(
              convertList(response.body, (result) => TaskDto.fromJson(result)),
              response.statusCode,
              response.headers,
            )
          : null;
    });
  }

  @deprecated
  Future<List<TaskDto>?> getByOptions(TaskServiceOptions options) {
    Map<String, List<String>> optionsMap = options.getOptions();

    return client.get('/tasks/all', optionsMap).then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => TaskDto.fromJson(result));
    });
  }

  Future<List<TaskDto>?> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) {
    Map<String, List<String>> parameters = {
      "filter": [filterString],
      ...?queryParameters,
    };
    print(parameters);
    return client.get('/tasks/all', parameters).then((response) {
      if (response == null) return null;
      return convertList(response.body, (result) => TaskDto.fromJson(result));
    });
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
