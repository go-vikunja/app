import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/task_attachment_dto.dart';
import 'package:vikunja_app/data/models/task_dto.dart';

class TaskDataSource extends RemoteDataSource {
  final Future<String> Function(DownloadTask task) _attachmentPath;
  final Future<void> Function(String path, Stream<List<int>> bytes)
  _writeAttachment;

  TaskDataSource(
    super.client, {
    Future<String> Function(DownloadTask task)? attachmentPath,
    Future<void> Function(String path, Stream<List<int>> bytes)?
    writeAttachment,
  }) : _attachmentPath = attachmentPath ?? _defaultAttachmentPath,
       _writeAttachment = writeAttachment ?? _defaultWriteAttachment;

  static Future<String> _defaultAttachmentPath(DownloadTask task) {
    return task.filePath();
  }

  static Future<void> _defaultWriteAttachment(
    String path,
    Stream<List<int>> bytes,
  ) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final partial = File('$path.part');
    try {
      if (await partial.exists()) await partial.delete();
      await bytes.pipe(partial.openWrite());
      if (await file.exists()) await file.delete();
      await partial.rename(path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

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
      url: '/tasks/$taskId',
      mapper: (body) {
        return TaskDto.fromJson(body);
      },
    );
  }

  Future<Response<List<TaskDto>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return client.get(
      url: '/projects/$projectId/views/$view/tasks',
      mapper: (body) {
        return convertList(body, (result) => TaskDto.fromJson(result));
      },
      queryParameters: queryParameters,
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
      url: '/tasks',
      mapper: (body) {
        return convertList(body, (result) => TaskDto.fromJson(result));
      },
      queryParameters: parameters,
    );
  }

  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachmentDto attachment,
  ) async {
    final relativeUrl = '/tasks/$taskId/attachments/${attachment.id}';

    final task = DownloadTask(
      url: '${client.apiBase}$relativeUrl',
      baseDirectory: BaseDirectory.applicationSupport,
      filename: attachment.file.name,
      headers: await client.getHeaders(),
      updates: Updates.statusAndProgress,
    );

    try {
      final response = await client.getRawStream(url: relativeUrl);
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final path = await _attachmentPath(task);
        await _writeAttachment(path, response.stream);
        return TaskStatusUpdate(
          task,
          TaskStatus.complete,
          null,
          null,
          response.headers,
          response.statusCode,
        );
      }

      final buffered = await http.Response.fromStream(response);

      if (response.statusCode == HttpStatus.notFound) {
        return TaskStatusUpdate(
          task,
          TaskStatus.notFound,
          null,
          buffered.body,
          response.headers,
          response.statusCode,
        );
      }

      return TaskStatusUpdate(
        task,
        TaskStatus.failed,
        TaskHttpException(
          'Attachment download failed with HTTP ${response.statusCode}',
          response.statusCode,
        ),
        buffered.body,
        response.headers,
        response.statusCode,
      );
    } catch (e, s) {
      reportSwallowedError('Attachment download failed', e, s);
      return TaskStatusUpdate(
        task,
        TaskStatus.failed,
        TaskException(e.toString()),
      );
    }
  }
}
