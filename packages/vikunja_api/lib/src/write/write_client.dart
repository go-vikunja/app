import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_api/src/write/write_ports.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Writes over `/api/v2` or `/api/v1`, chosen by
/// `connection.preferredApiVersion`. v2 patches the changed fields; v1 has
/// no partial update, so the task is read, the changes are overlaid and the
/// whole object is posted back.
final class WriteClient implements VikunjaWriteClient {
  new({required Dio dio, required ServerConnection connection})
    : tasks = _TasksWriteApi(_WriteTransport(dio, connection));

  @override
  final TasksWritePort tasks;
}

const _notModified = 304;
const _taskDoesNotExist = 4002;

// A v1 update replaces the task with the body: every field the server sent
// goes back so that assignees, reminders and the fields this client does not
// model keep their values. Labels have their own endpoints and are ignored
// in the body; the other read-only collections would only add bulk.
const _notSentBack = {
  'labels',
  'related_tasks',
  'attachments',
  'comments',
  'buckets',
  'reactions',
  'subscription',
};

final class _TasksWriteApi implements TasksWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<Task> create(NewTask task) async {
    final response = await _transport.send(
      switch (_transport.version) {
        ApiVersion.v2 => 'POST',
        ApiVersion.v1 => 'PUT',
      },
      '/projects/${task.projectId}/tasks',
      body: encodeNewTask(task),
    );
    return _transport.decode<Task>(response, parseTask);
  }

  @override
  Future<Task> update(int id, TaskChanges changes) {
    if (changes.isEmpty) return _read(id);
    return switch (_transport.version) {
      ApiVersion.v2 => _patch(id, changes),
      ApiVersion.v1 => _replace(id, changes),
    };
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _transport.send('DELETE', '/tasks/$id');
    } on NotFound catch (failure) {
      if (failure.code != _taskDoesNotExist) rethrow;
    }
  }

  Future<Task> _patch(int id, TaskChanges changes) async {
    final response = await _transport.send(
      'PATCH',
      '/tasks/$id',
      body: encodeTaskChanges(changes),
      contentType: mergePatchContentType,
      acceptNotModified: true,
    );
    // A patch that changes nothing is answered with 304 and no body. A move
    // is answered with the identifier of the old project (the server builds
    // it before moving), so the stored task is read back.
    if (response.statusCode == _notModified || changes.projectId != null) {
      return await _read(id);
    }
    return _transport.decode<Task>(response, parseTask);
  }

  Future<Task> _replace(int id, TaskChanges changes) async {
    final current = _transport.decode<Map<String, Object?>>(
      await _transport.send('GET', '/tasks/$id'),
      (json) => objectOf(json, 'task'),
    );
    final response = await _transport.send(
      'POST',
      '/tasks/$id',
      body: {
        for (final MapEntry(:key, :value) in current.entries)
          if (!_notSentBack.contains(key)) key: value,
        ...encodeTaskChanges(changes),
      },
    );
    // After a move the answer still carries the old project's identifier.
    if (changes.projectId != null) return await _read(id);
    // The v1 update answers without the labels, which it cannot change; the
    // read just made has them.
    return _transport.decode<Task>(response, (json) {
      final stored = objectOf(json, 'task');
      return parseTask({
        ...stored,
        'labels': stored['labels'] ?? current['labels'],
      });
    });
  }

  Future<Task> _read(int id) async {
    final response = await _transport.send('GET', '/tasks/$id');
    return _transport.decode<Task>(response, parseTask);
  }
}

final class _WriteTransport {
  new(this._dio, ServerConnection connection)
    : version = connection.preferredApiVersion,
      _base = connection.apiBaseUri(connection.preferredApiVersion);

  final Dio _dio;
  final ApiVersion version;
  final Uri _base;

  Future<Response<Object?>> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? contentType,
    bool acceptNotModified = false,
  }) async {
    try {
      return await _dio.requestUri<Object?>(
        _base.replace(path: '${_base.path}$path'),
        data: body,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          contentType: contentType,
          headers: {'Accept': 'application/json'},
          validateStatus: acceptNotModified ? _okOrNotModified : null,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
  }

  T decode<T>(Response<Object?> response, T Function(Object?) parse) {
    try {
      return parse(response.data);
    } on MalformedJson catch (error) {
      throw UnexpectedResponse(response.statusCode, message: error.message);
    }
  }

  static bool _okOrNotModified(int? status) =>
      status != null &&
      (status >= 200 && status < 300 || status == _notModified);
}
