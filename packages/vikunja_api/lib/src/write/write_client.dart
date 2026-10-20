import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/bucket_codec.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/label_codec.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/src/dto/saved_filter_codec.dart';
import 'package:vikunja_api/src/dto/subscription_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_api/src/write/write_ports.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Writes over `/api/v2` or `/api/v1`, chosen by
/// `connection.preferredApiVersion`. v2 patches the changed fields; v1 has
/// no partial update, so the task is read, the changes are overlaid and the
/// whole object is posted back. Labels, assignees and relations go through
/// the task's own endpoints on both.
final class WriteClient implements VikunjaWriteClient {
  new({required Dio dio, required ServerConnection connection})
    : this._(_WriteTransport(dio, connection));

  new _(_WriteTransport transport)
    : tasks = _TasksWriteApi(transport),
      labels = _LabelsWriteApi(transport),
      notifications = _NotificationsWriteApi(transport),
      subscriptions = _SubscriptionsWriteApi(transport),
      buckets = _BucketsWriteApi(transport),
      views = _ProjectViewsWriteApi(transport),
      projects = _ProjectsWriteApi(transport),
      savedFilters = _SavedFiltersApi(transport);

  @override
  final TasksWritePort tasks;

  @override
  final LabelsWritePort labels;

  @override
  final NotificationsWritePort notifications;

  @override
  final SubscriptionsWritePort subscriptions;

  @override
  final BucketsWritePort buckets;

  @override
  final ProjectViewsWritePort views;

  @override
  final ProjectsWritePort projects;

  @override
  final SavedFiltersPort savedFilters;
}

final class _SavedFiltersApi implements SavedFiltersPort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<SavedFilter> read(int id) async =>
      _parse(await _transport.send('GET', '/filters/$id'));

  @override
  Future<SavedFilter> create(SavedFilterDraft draft) async => _parse(
    await _transport.send(
      _transport.createMethod,
      '/filters',
      body: encodeSavedFilterDraft(draft),
    ),
  );

  @override
  Future<SavedFilter> update(int id, SavedFilterDraft draft) async => _parse(
    await _transport.patchOrReplace(
      '/filters/$id',
      'saved filter',
      encodeSavedFilterDraft(draft),
    ),
  );

  @override
  Future<SavedFilter> setFavorite(int id, {required bool favorite}) async =>
      _parse(
        await _transport.patchOrReplace('/filters/$id', 'saved filter', {
          'is_favorite': favorite,
        }),
      );

  @override
  Future<void> delete(int id) async {
    try {
      await _transport.send('DELETE', '/filters/$id');
    } on NotFound catch (failure) {
      if (failure.code != _savedFilterDoesNotExist) rethrow;
    }
  }

  SavedFilter _parse(Response<Object?> response) =>
      _transport.decode<SavedFilter>(response, parseSavedFilter);
}

final class _ProjectsWriteApi implements ProjectsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<Project> move(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) async {
    if (!position.isFinite || position < _minProjectPosition) {
      throw ArgumentError.value(
        position,
        'position',
        'Below $_minProjectPosition the server renumbers every sibling',
      );
    }
    return _parse(
      await _transport.patchOrReplace('/projects/$projectId', 'project', {
        'position': position,
        'parent_project_id': parentProjectId,
      }),
    );
  }

  @override
  Future<Project> create(NewProject project) async => _parse(
    await _transport.send(
      _transport.createMethod,
      '/projects',
      body: encodeNewProject(project),
    ),
  );

  @override
  Future<Project> update(
    int projectId,
    ProjectChanges changes, {
    String Function(String current)? rebaseDescription,
  }) async {
    if (changes.position case final position?
        when !position.isFinite || position < _minProjectPosition) {
      throw ArgumentError.value(
        position,
        'changes.position',
        'Below $_minProjectPosition the server renumbers every sibling',
      );
    }
    final path = '/projects/$projectId';
    final body = encodeProjectChanges(changes);
    if (body.isEmpty) return _parse(await _transport.send('GET', path));
    final rebase = changes.description == null ? null : rebaseDescription;
    if (rebase == null) {
      return _parse(await _transport.patchOrReplace(path, 'project', body));
    }
    final current = _transport.decode<Map<String, Object?>>(
      await _transport.send('GET', path),
      (json) => objectOf(json, 'project'),
    );
    final rebased = {
      ...body,
      'description': rebase(current['description'] as String? ?? ''),
    };
    return _parse(switch (_transport.version) {
      ApiVersion.v2 => await _transport.patchOrReplace(
        path,
        'project',
        rebased,
      ),
      ApiVersion.v1 => await _transport.send(
        'POST',
        path,
        body: {...current, ...rebased},
      ),
    });
  }

  @override
  Future<void> delete(int projectId) async {
    try {
      await _transport.send('DELETE', '/projects/$projectId');
    } on NotFound catch (failure) {
      if (failure.code != _projectDoesNotExist) rethrow;
    }
  }

  @override
  Future<Project> duplicate(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  }) async {
    if (projectId < 1) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'A pseudo project cannot be duplicated',
      );
    }
    final response = await _transport.send(
      _transport.createMethod,
      '/projects/$projectId/duplicate',
      body: {
        'parent_project_id': parentProjectId,
        'duplicate_shares': copyShares,
      },
    );
    return _transport.decode<Project>(
      response,
      (json) => parseProject(objectOf(json, 'duplicate')['duplicated_project']),
    );
  }

  Project _parse(Response<Object?> response) =>
      _transport.decode<Project>(response, parseProject);
}

final class _BucketsWriteApi implements BucketsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<Bucket> create(
    int projectId,
    int viewId, {
    required String title,
    int limit = 0,
    double? position,
  }) async {
    final response = await _transport.send(
      _transport.createMethod,
      '/projects/$projectId/views/$viewId/buckets',
      body: encodeBucket(title: title, limit: limit, position: position),
    );
    return _transport.decode<Bucket>(response, parseBucket);
  }

  @override
  Future<Bucket> update(
    int projectId,
    int viewId, {
    required int bucketId,
    required String title,
    required int limit,
    required double position,
  }) async {
    await _transport.send(
      _transport.updateMethod,
      '/projects/$projectId/views/$viewId/buckets/$bucketId',
      body: encodeBucket(title: title, limit: limit, position: position),
    );
    return Bucket(
      id: bucketId,
      viewId: viewId,
      title: title,
      limit: limit,
      position: position,
    );
  }

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) async {
    try {
      await _transport.send(
        'DELETE',
        '/projects/$projectId/views/$viewId/buckets/$bucketId',
      );
    } on NotFound catch (failure) {
      if (failure.code != _bucketDoesNotExist) rethrow;
    }
  }
}

final class _ProjectViewsWriteApi implements ProjectViewsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<ProjectView> setBuckets(
    int projectId,
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  }) async {
    final path = '/projects/$projectId/views/$viewId';
    final changes = {
      'done_bucket_id': ?doneBucketId,
      'default_bucket_id': ?defaultBucketId,
    };
    if (changes.isEmpty) return _parse(await _transport.send('GET', path));
    return _parse(
      await _transport.patchOrReplace(path, 'project view', changes),
    );
  }

  @override
  Future<ProjectView> create(int projectId, ViewDraft view) async => _parse(
    await _transport.send(
      _transport.createMethod,
      '/projects/$projectId/views',
      body: encodeNewView(view),
    ),
  );

  @override
  Future<ProjectView> update(int projectId, int viewId, ViewDraft view) async =>
      _parse(
        await _transport.patchOrReplace(
          '/projects/$projectId/views/$viewId',
          'project view',
          encodeViewChanges(view),
        ),
      );

  @override
  Future<ProjectView> move(
    int projectId,
    int viewId, {
    required double position,
  }) async => _parse(
    await _transport.patchOrReplace(
      '/projects/$projectId/views/$viewId',
      'project view',
      {'position': position},
    ),
  );

  @override
  Future<void> delete(int projectId, int viewId) async {
    try {
      await _transport.send('DELETE', '/projects/$projectId/views/$viewId');
    } on NotFound catch (failure) {
      if (failure.code != _viewDoesNotExist) rethrow;
    }
  }

  ProjectView _parse(Response<Object?> response) =>
      _transport.decode<ProjectView>(
        response,
        (json) =>
            parseProjectView(json) ??
            (throw const MalformedJson('project view of an unknown kind')),
      );
}

final class _SubscriptionsWriteApi implements SubscriptionsWritePort {
  new(this._transport);

  final _WriteTransport _transport;

  @override
  Future<void> subscribe(SubscriptionEntity entity, int id) async {
    try {
      await _transport.send(
        _transport.createMethod,
        '/subscriptions/${entity.wireName}/$id',
      );
    } on DomainError catch (failure) {
      if (failure.code != _alreadySubscribed) rethrow;
    }
  }

  @override
  Future<void> unsubscribe(SubscriptionEntity entity, int id) async {
    try {
      await _transport.send('DELETE', '/subscriptions/${entity.wireName}/$id');
    } on Forbidden catch (failure) {
      // 403 without a code is the answer when there is nothing to delete
      // (never followed, or unfollowed before); it also means no access,
      // which the read tells apart by failing itself.
      if (failure.code != null) rethrow;
      final path = switch (entity) {
        SubscriptionEntity.task => '/tasks/$id',
        SubscriptionEntity.project => '/projects/$id',
      };
      final current = _transport.decode(
        await _transport.send('GET', path),
        (json) => subscriptionOf(objectOf(json, entity.wireName)),
      );
      if (current != null) rethrow;
    }
  }
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
const _relationAlreadyExists = 4008;
const _relationDoesNotExist = 4009;
const _alreadySubscribed = 12002;
const _bucketDoesNotExist = 10001;
const _projectDoesNotExist = 3001;
const _viewDoesNotExist = 3014;
const _savedFilterDoesNotExist = 11001;
const _minProjectPosition = 0.1;

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
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  }) async {
    final relations = changes.relations;
    if (relations != null) _checkServerIds(relations);
    final body = encodeTaskChanges(changes);
    final rebase = changes.description == null ? null : rebaseDescription;
    final answer = body.isEmpty
        ? await _read(id)
        : switch (_transport.version) {
            ApiVersion.v2 => await _patch(
              id,
              rebase == null
                  ? body
                  : {
                      ...body,
                      'description': rebase((await _read(id)).description),
                    },
            ),
            ApiVersion.v1 => await _replace(id, body, rebase),
          };
    final sentLabelsOrAssignees = await _sendLabelsAndAssignees(
      id,
      changes,
      answer,
    );
    final sentRelations =
        relations != null && await _sendRelations(id, relations, answer);
    final changedByMoves = await _sendPlacements(id, changes.kanban, answer);
    await _sendPositions(id, changes.positions);
    final sentAny = sentLabelsOrAssignees || sentRelations || changedByMoves;
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

  @override
  Future<Task> duplicate(int id) async {
    final response = await _transport.send(
      _transport.createMethod,
      '/tasks/$id/duplicate',
    );
    return _transport.decode<Task>(
      response,
      (json) => parseTask(objectOf(json, 'duplicate')['duplicated_task']),
    );
  }

  @override
  Future<void> markRead(int id) async {
    await _transport.send(switch (_transport.version) {
      ApiVersion.v2 => 'PUT',
      ApiVersion.v1 => 'POST',
    }, '/tasks/$id/read');
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

  Future<Task> _replace(
    int id,
    Map<String, Object?> overlay,
    String Function(String current)? rebaseDescription,
  ) async {
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
        if (rebaseDescription != null)
          'description': rebaseDescription(
            current['description'] as String? ?? '',
          ),
      },
    );
    // The v1 update cannot change labels or relations and answers without
    // them (relations as `{}` or null), so the read just made has the real
    // ones.
    return _transport.decode<Task>(response, (json) {
      final stored = objectOf(json, 'task');
      return parseTask({
        ...stored,
        'labels': stored['labels'] ?? current['labels'],
        'related_tasks': current['related_tasks'],
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

  void _checkServerIds(RelationChange relations) {
    for (final ref in [...relations.added, ...relations.removed]) {
      if (ref.otherTaskId <= 0) {
        throw ArgumentError.value(
          ref.otherTaskId,
          'otherTaskId',
          'A temporary task id must be resolved before the update is sent',
        );
      }
    }
  }

  /// Like [_sendLabelsAndAssignees], for the task's relation edges: removes
  /// first, then adds. A missing other task does not hold back the edges
  /// after it; its [RelatedTaskMissing] is thrown once all were tried.
  Future<bool> _sendRelations(
    int id,
    RelationChange relations,
    Task stored,
  ) async {
    final held = _edgesOf(stored);
    final remove = [
      for (final ref in relations.removed.difference(relations.added))
        if (held.contains(ref)) ref,
    ];
    final add = [
      for (final ref in relations.added)
        if (!held.contains(ref)) ref,
    ];
    RelatedTaskMissing? missing;
    Future<void> trying(Future<void> Function() send) async {
      try {
        await send();
      } on RelatedTaskMissing catch (failure) {
        missing ??= failure;
      }
    }

    for (final ref in remove) {
      await trying(() => _removeRelation(id, ref));
    }
    for (final ref in add) {
      await trying(() => _addRelation(id, ref));
    }
    if (missing case final failure?) throw failure;
    return remove.isNotEmpty || add.isNotEmpty;
  }

  Future<void> _addRelation(int taskId, TaskRelationRef ref) async {
    try {
      await _transport.send(
        _transport.createMethod,
        '/tasks/$taskId/relations',
        body: {
          'other_task_id': ref.otherTaskId,
          'relation_kind': ref.kind.wireName,
        },
      );
    } on DomainError catch (failure) {
      // 409 also for an edge that exists only because its inverse was
      // added from the other task.
      if (failure.code != _relationAlreadyExists) rethrow;
    } on NotFound catch (failure) {
      if (failure.code != _taskDoesNotExist) rethrow;
      // The code does not say which of the two tasks is missing; the read
      // fails with it when this one is.
      await _read(taskId);
      throw RelatedTaskMissing(ref.otherTaskId, message: failure.message);
    }
  }

  Future<void> _removeRelation(int taskId, TaskRelationRef ref) async {
    try {
      await _transport.send(
        'DELETE',
        '/tasks/$taskId/relations/${ref.kind.wireName}/${ref.otherTaskId}',
      );
    } on NotFound catch (failure) {
      switch (failure.code) {
        case _relationDoesNotExist:
          return;
        case _taskDoesNotExist:
          // Deleting the other task takes its edges along.
          if (!_edgesOf(await _read(taskId)).contains(ref)) return;
          throw RelatedTaskMissing(ref.otherTaskId, message: failure.message);
        default:
          rethrow;
      }
    }
  }

  /// Per view, the move and then, when the task landed where it was sent,
  /// the position. Returns whether a move changed the task itself (into or
  /// out of a done bucket, a repeating task reopened), which bumps its
  /// `updated`; a plain move leaves the task as it is and costs no read.
  Future<bool> _sendPlacements(
    int id,
    Map<int, BucketPlacement>? placements,
    Task stored,
  ) async {
    var changed = false;
    for (final MapEntry(key: viewId, value: placement)
        in (placements ?? const {}).entries) {
      final move = _transport.decode(
        await _transport.send(
          _transport.updateMethod,
          '/projects/${stored.projectId}/views/$viewId/buckets/'
          '${placement.bucketId}/tasks',
          body: {'task_id': id},
        ),
        parseBucketMove,
      );
      if (move.task case final echoed? when echoed.updated != stored.updated) {
        changed = true;
      }
      // A repeating task moved into the done bucket is reopened in the
      // default bucket; a position would be for the wrong bucket.
      if (placement.position case final position?
          when move.bucketId == placement.bucketId) {
        await _transport.send(
          _transport.updateMethod,
          '/tasks/$id/position',
          body: {'project_view_id': viewId, 'position': position},
        );
      }
    }
    return changed;
  }

  Future<void> _sendPositions(int id, Map<int, double>? positions) async {
    for (final MapEntry(key: viewId, value: position)
        in (positions ?? const {}).entries) {
      await _transport.send(
        _transport.updateMethod,
        '/tasks/$id/position',
        body: {'project_view_id': viewId, 'position': position},
      );
    }
  }

  Future<Task> _read(int id) async {
    final response = await _transport.send('GET', '/tasks/$id');
    return _transport.decode<Task>(response, parseTask);
  }
}

Set<TaskRelationRef> _edgesOf(Task task) => {
  for (final MapEntry(key: kind, value: others) in task.relatedTasks.entries)
    for (final other in others) TaskRelationRef(kind, other.id),
};

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

  /// The verb of the kanban move and position writes, the reverse of
  /// [createMethod].
  String get updateMethod => switch (version) {
    ApiVersion.v2 => 'PUT',
    ApiVersion.v1 => 'POST',
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

  /// Writes [changes] to the object at [path]: a v2 merge-patch, read when
  /// the server answers 304 for no change, or on v1 a read of the object
  /// posted back whole with [changes] overlaid. The v1 update is a full
  /// replace that clears or resets what it is not sent (a project's colour,
  /// identifier, favourite and archive state, and its position, which
  /// renumbers the siblings; a view's kind, which turns a board into a
  /// list).
  Future<Response<Object?>> patchOrReplace(
    String path,
    String what,
    Map<String, Object?> changes,
  ) async {
    switch (version) {
      case ApiVersion.v2:
        final response = await send(
          'PATCH',
          path,
          body: changes,
          contentType: mergePatchContentType,
          acceptNotModified: true,
        );
        if (response.statusCode != _notModified) return response;
        return await send('GET', path);
      case ApiVersion.v1:
        final current = decode<Map<String, Object?>>(
          await send('GET', path),
          (json) => objectOf(json, what),
        );
        return await send('POST', path, body: {...current, ...changes});
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
