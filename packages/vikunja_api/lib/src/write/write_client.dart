import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/label_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_api/src/write/write_ports.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Writes over `/api/v2` or `/api/v1`, chosen by
/// `connection.preferredApiVersion`. v2 patches the changed fields; v1 has
/// no partial update, so the task is read, the changes are overlaid and the
/// whole object is posted back. Labels and assignees go through the task's
/// own endpoints on both.
final class WriteClient implements VikunjaWriteClient {
  new({required Dio dio, required ServerConnection connection})
    : this._(_WriteTransport(dio, connection));

  new _(_WriteTransport transport)
    : tasks = _TasksWriteApi(transport),
      labels = _LabelsWriteApi(transport),
      notifications = _NotificationsWriteApi(transport);

  @override
  final TasksWritePort tasks;

  @override
  final LabelsWritePort labels;

  @override
  final NotificationsWritePort notifications;
}

final class _NotificationsWriteApi implements NotificationsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<void> markRead(int id, {bool read = true}) async {
    try {
      await _transport.send(
        switch (_transport.version) {
          ApiVersion.v2 => 'PUT',
          ApiVersion.v1 => 'POST',
        },
        '/notifications/$id',
        body: {'read': read},
      );
    } on Forbidden {
      // 2.7.0 answers 403, not 404, for an id that is not the caller's
      // notification, which for an id from the caller's own list means it
      // was deleted.
    } on NotFound catch (failure) {
      if (failure.routeAbsent) rethrow;
    }
  }

  @override
  Future<void> markAllRead() async {
    await _transport.send('POST', '/notifications');
  }
}

final class _LabelsWriteApi implements LabelsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<Label> create(NewLabel label) async {
    final response = await _transport.send(
      _transport.createMethod,
      '/labels',
      body: encodeNewLabel(label),
    );
    return _transport.decode<Label>(response, parseLabel);
  }
}

const _notModified = 304;
const _taskDoesNotExist = 4002;
const _labelAlreadyOnTask = 8001;
const _userAlreadyAssigned = 4021;

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
      _transport.createMethod,
      '/projects/${task.projectId}/tasks',
      body: encodeNewTask(task),
    );
    return _transport.decode<Task>(response, parseTask);
  }

  @override
  Future<Task> update(int id, TaskChanges changes) async {
    final body = encodeTaskChanges(changes);
    final answer = body.isEmpty
        ? await _read(id)
        : switch (_transport.version) {
            ApiVersion.v2 => await _patch(id, body),
            ApiVersion.v1 => await _replace(id, body),
          };
    final sentAny = await _sendLabelsAndAssignees(id, changes, answer);
    // A move is answered with the identifier of the old project (the server
    // builds it before moving). The server keeps only one reminder per
    // instant but answers with the list from before that: new reminders as
    // sent, and after a date change the relative ones it moved, which can
    // now coincide (all those of a cleared date fall on the zero instant).
    final readBack =
        sentAny ||
        changes.projectId != null ||
        changes.reminders != null ||
        changes.dueDate != null ||
        changes.startDate != null ||
        changes.endDate != null;
    return readBack ? await _read(id) : answer;
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _transport.send('DELETE', '/tasks/$id');
    } on NotFound catch (failure) {
      if (failure.code != _taskDoesNotExist) rethrow;
    }
  }

  Future<Task> _patch(int id, Map<String, Object?> body) async {
    final response = await _transport.send(
      'PATCH',
      '/tasks/$id',
      body: body,
      contentType: mergePatchContentType,
      acceptNotModified: true,
    );
    // A patch that changes nothing is answered with 304 and no body.
    if (response.statusCode == _notModified) return await _read(id);
    return _transport.decode<Task>(response, parseTask);
  }

  Future<Task> _replace(int id, Map<String, Object?> overlay) async {
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
        ...overlay,
      },
    );
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

  /// Sends only the requests whose effect [stored] does not show yet, so a
  /// call repeated after a lost answer changes nothing twice. Returns
  /// whether any request was sent.
  Future<bool> _sendLabelsAndAssignees(
    int id,
    TaskChanges changes,
    Task stored,
  ) async {
    final labels = _requestsToSend(
      changes.labels,
      held: {for (final label in stored.labels) label.id},
    );
    final assignees = _requestsToSend(
      changes.assignees,
      held: {for (final user in stored.assignees) user.id},
    );
    for (final labelId in labels.remove) {
      await _removeLabel(id, labelId);
    }
    for (final labelId in labels.add) {
      await _addLabel(id, labelId);
    }
    for (final userId in assignees.remove) {
      await _unassign(id, userId);
    }
    for (final userId in assignees.add) {
      await _assign(id, userId);
    }
    return labels.remove.isNotEmpty ||
        labels.add.isNotEmpty ||
        assignees.remove.isNotEmpty ||
        assignees.add.isNotEmpty;
  }

  Future<void> _addLabel(int taskId, int labelId) async {
    try {
      await _transport.send(
        _transport.createMethod,
        '/tasks/$taskId/labels',
        body: {'label_id': labelId},
      );
    } on DomainError catch (failure) {
      if (failure.code != _labelAlreadyOnTask) rethrow;
    }
  }

  Future<void> _removeLabel(int taskId, int labelId) async {
    try {
      await _transport.send('DELETE', '/tasks/$taskId/labels/$labelId');
    } on Forbidden {
      // The server answers 403, not 404, for a label that is not on the
      // task, as after a remove whose answer was lost.
      final task = await _read(taskId);
      if (task.labels.any((label) => label.id == labelId)) rethrow;
    }
  }

  Future<void> _assign(int taskId, int userId) async {
    try {
      await _transport.send(
        _transport.createMethod,
        '/tasks/$taskId/assignees',
        body: {'user_id': userId},
      );
    } on DomainError catch (failure) {
      if (failure.code != _userAlreadyAssigned) rethrow;
    }
  }

  // Unassigning someone who is not assigned succeeds on the server.
  Future<void> _unassign(int taskId, int userId) async {
    await _transport.send('DELETE', '/tasks/$taskId/assignees/$userId');
  }

  Future<Task> _read(int id) async {
    final response = await _transport.send('GET', '/tasks/$id');
    return _transport.decode<Task>(response, parseTask);
  }
}

/// An id both added and removed ends up added, as in [IdSetChange.applyTo].
({List<int> remove, List<int> add}) _requestsToSend(
  IdSetChange? change, {
  required Set<int> held,
}) => switch (change) {
  null => (remove: const [], add: const []),
  IdSetChange(:final added, :final removed) => (
    remove: [
      for (final id in removed.difference(added))
        if (held.contains(id)) id,
    ],
    add: [
      for (final id in added)
        if (!held.contains(id)) id,
    ],
  ),
};

final class _WriteTransport {
  new(this._dio, ServerConnection connection)
    : version = connection.preferredApiVersion,
      _base = connection.apiBaseUri(connection.preferredApiVersion);

  final Dio _dio;
  final ApiVersion version;
  final Uri _base;

  String get createMethod => switch (version) {
    ApiVersion.v2 => 'POST',
    ApiVersion.v1 => 'PUT',
  };

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
