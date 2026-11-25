import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/bucket_codec.dart';
import 'package:vikunja_api/src/dto/comment_codec.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/label_codec.dart';
import 'package:vikunja_api/src/dto/notification_codec.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/src/dto/saved_filter_codec.dart';
import 'package:vikunja_api/src/dto/subscription_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
import 'package:vikunja_api/src/dto/task_details_codec.dart';
import 'package:vikunja_api/src/dto/user_codec.dart';
import 'package:vikunja_api/src/errors/normalize_error.dart';
import 'package:vikunja_api/src/errors/streamed_error_body.dart';
import 'package:vikunja_api/src/read/read_ports.dart';
import 'package:vikunja_api/src/read/task_query_params.dart';
import 'package:vikunja_api/src/transport/all_pages.dart';
import 'package:vikunja_api/src/transport/body_cap_adapter.dart';
import 'package:vikunja_api/src/transport/path_segment.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// Reads over `/api/v2` or `/api/v1`, chosen by
/// `connection.preferredApiVersion`. Both versions share the entity JSON;
/// they differ in the base path, the search parameter and the page shape.
final class ReadClient implements VikunjaReadClient {
  new({required Dio dio, required ServerConnection connection})
    : this._(_ReadTransport(dio, connection));

  new _(_ReadTransport transport)
    : projects = _ProjectsApi(transport),
      labels = _LabelsApi(transport),
      tasks = _TasksApi(transport),
      users = _UsersApi(transport),
      notifications = _NotificationsApi(transport),
      subscriptions = _SubscriptionsApi(transport),
      avatars = _AvatarsApi(transport),
      comments = _CommentsApi(transport),
      attachments = _AttachmentsApi(transport),
      buckets = _BucketsApi(transport),
      savedFilters = _SavedFiltersApi(transport);

  @override
  final ProjectsPort projects;

  @override
  final LabelsPort labels;

  @override
  final TasksPort tasks;

  @override
  final UsersPort users;

  @override
  final NotificationsPort notifications;

  @override
  final SubscriptionsPort subscriptions;

  @override
  final AvatarsPort avatars;

  @override
  final CommentsPort comments;

  @override
  final AttachmentsPort attachments;

  @override
  final BucketsPort buckets;

  @override
  final SavedFiltersReadPort savedFilters;
}

final class _SavedFiltersApi implements SavedFiltersReadPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<SavedFilter> read(int id) async {
    final response = await _transport.get('/filters/$id');
    return _transport.decode<SavedFilter>(response, parseSavedFilter);
  }
}

final class _BucketsApi implements BucketsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<List<BoardBucket>> board(
    int projectId,
    int viewId, {
    int perPage = 50,
    String? filterTimezone,
  }) async {
    final response = await _transport.get(
      switch (_transport.version) {
        ApiVersion.v2 => '/projects/$projectId/views/$viewId/buckets/tasks',
        ApiVersion.v1 => '/projects/$projectId/views/$viewId/tasks',
      },
      query: {
        'per_page': perPage,
        if (filterTimezone case final zone? when zone.isNotEmpty)
          'filter_timezone': zone,
      },
    );
    // v2 wraps the buckets without page fields; v1 sends them bare, with
    // paging headers that count buckets, not tasks.
    final buckets = switch ((_transport.version, response.data)) {
      (ApiVersion.v2, {'items': final List<Object?> items}) => items,
      (ApiVersion.v1, final List<Object?> items) => items,
      _ => throw UnexpectedResponse(
        response.statusCode,
        message: 'not a board',
      ),
    };
    return _transport.decode<List<BoardBucket>>(
      response,
      (_) => List.unmodifiable(
        buckets.map((json) {
          final bucket = parseBucket(json);
          return BoardBucket(
            bucket: bucket,
            tasks: bucketTasksOf(json, bucketId: bucket.id),
          );
        }),
      ),
    );
  }

  @override
  Future<Page<Task>> bucketTasks(
    int projectId,
    int viewId,
    int bucketId, {
    required int page,
    int perPage = 50,
    String? filterTimezone,
  }) async {
    final query = TaskQuery(
      filter: 'bucket_id = $bucketId',
      sort: const [TaskSort(TaskSortField.position)],
      page: page,
      perPage: perPage,
      filterTimezone: filterTimezone,
    );
    final response = await _transport.get(
      '/projects/$projectId/views/$viewId/tasks',
      query: taskQueryParameters(
        query,
        version: _transport.version,
        inView: true,
      ),
    );
    return _transport
        .page(response, page: page, perPage: perPage, parse: parseTask)
        .map((task) => task.copyWith(bucketId: bucketId));
  }
}

final class _CommentsApi implements CommentsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<TaskComment>> list(
    int taskId, {
    int page = 1,
    int? perPage,
    bool newestFirst = false,
  }) async {
    final response = await _transport.get(
      '/tasks/$taskId/comments',
      query: {
        'page': page,
        'per_page': ?perPage,
        'order_by': newestFirst ? 'desc' : 'asc',
      },
    );
    final comments = _transport.page(
      response,
      page: page,
      perPage: perPage,
      parse: parseTaskComment,
    );
    // The server sorts by `created` alone, which it keeps to the second.
    final sorted = [...comments.items]..sort(_byCreatedThenId);
    return Page(
      items: List.unmodifiable(newestFirst ? sorted.reversed : sorted),
      page: comments.page,
      perPage: comments.perPage,
      totalPages: comments.totalPages,
      total: comments.total,
    );
  }

  static int _byCreatedThenId(TaskComment a, TaskComment b) {
    final byCreated = (a.created?.microsecondsSinceEpoch ?? 0).compareTo(
      b.created?.microsecondsSinceEpoch ?? 0,
    );
    return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
  }
}

final class _AttachmentsApi implements AttachmentsPort {
  new(this._transport);

  final _ReadTransport _transport;

  // 2.7.1 made the v2 download route ignore preview_size and gave v2 a
  // preview route of its own, which older servers refuse with a 422. v1's
  // preview_size answers on 2.7.1 with a preview and before it exactly as
  // v2 did, and the stored server version can predate an upgrade, so v1
  // carries previews wherever the server offers it.
  ApiVersion get _previewApi =>
      _transport.offers(ApiVersion.v1) ? ApiVersion.v1 : _transport.version;

  bool get _previewRoute =>
      _previewApi == ApiVersion.v2 &&
      (_transport.serverVersion?.isAtLeast(2, 7, 1) ?? false);

  @override
  Future<AttachmentBlob> fetch(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
    CancelToken? cancel,
  }) async {
    final original = '/tasks/$taskId/attachments/$attachmentId';
    final (path, query) = switch (preview) {
      null => (original, const <String, Object?>{}),
      final size when _previewRoute => (
        '$original/preview',
        {'size': size.wireName},
      ),
      final size => (original, {'preview_size': size.wireName}),
    };
    final (:bytes, :contentType, statusCode: _) = await _transport
        .getCappedBytes(
          path,
          query: query,
          // Servers before 2.7.1 answer the original for anything they cannot
          // preview, so a preview request has to take any image.
          accept: preview == null ? '*/*' : 'image/*',
          maxBytes: maxAttachmentBytes,
          over: preview == null ? null : _previewApi,
          refuse: preview == null ? null : _fileInPreviewsPlace,
          cancel: cancel,
        );
    return AttachmentBlob(
      bytes: bytes,
      contentType: contentType.isEmpty
          ? 'application/octet-stream'
          : contentType,
    );
  }

  // Servers before 2.7.1 send the file itself for a preview they cannot
  // make, where 2.7.1 answers 4038; a page in the server's place is the
  // caller's to judge.
  static VikunjaFailure? _fileInPreviewsPlace(String type) =>
      type == 'text/html' ||
          type == 'application/xhtml+xml' ||
          (type.startsWith('image/') && type != 'image/svg+xml')
      ? null
      : const DomainError(422, code: 4038);

  @override
  Future<void> download(
    int taskId,
    int attachmentId, {
    required File target,
    CancelToken? cancel,
  }) => _transport.download(
    '/tasks/$taskId/attachments/$attachmentId',
    target,
    cancel: cancel,
  );
}

final class _AvatarsApi implements AvatarsPort {
  new(this._transport);

  final _ReadTransport _transport;

  // An avatar is at most a few hundred pixels across.
  static const int _maxBytes = 2 * 1024 * 1024;

  @override
  Future<AvatarImage> fetch(String username, {required int size}) async {
    final (:bytes, :contentType, :statusCode) = await _transport.getCappedBytes(
      '/avatar/${pathSegment(username)}',
      query: {'size': size},
      accept: 'image/*',
      maxBytes: _maxBytes,
    );
    final isImage =
        contentType.startsWith('image/') ||
        contentType == 'application/octet-stream';
    if (!isImage || bytes.isEmpty) {
      throw UnexpectedResponse(
        statusCode,
        message: 'not an image: $contentType',
      );
    }
    return AvatarImage(bytes: bytes, contentType: contentType);
  }
}

final class _SubscriptionsApi implements SubscriptionsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Subscription?> forTask(int taskId) =>
      _subscriptionOf('/tasks/$taskId', 'task');

  @override
  Future<Subscription?> forProject(int projectId) =>
      _subscriptionOf('/projects/$projectId', 'project');

  // Only the single reads carry the subscription.
  Future<Subscription?> _subscriptionOf(String path, String what) async {
    final response = await _transport.get(path);
    return _transport.decode<Subscription?>(
      response,
      (json) => subscriptionOf(objectOf(json, what)),
    );
  }
}

final class _NotificationsApi implements NotificationsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<ServerNotification>> list({int page = 1, int? perPage}) async {
    final response = await _transport.get(
      '/notifications',
      query: {'page': page, 'per_page': ?perPage},
    );
    return _transport.page(
      response,
      page: page,
      perPage: perPage,
      parse: parseServerNotification,
    );
  }
}

final class _UsersApi implements UsersPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<List<User>> searchProjectUsers(
    int projectId, {
    String query = '',
  }) async {
    final search = query.trim();
    final version = _transport.version;
    final response = await _transport.get(
      switch (version) {
        ApiVersion.v2 => '/projects/$projectId/users/search',
        ApiVersion.v1 => '/projects/$projectId/projectusers',
      },
      query: {if (search.isNotEmpty) searchParameterName(version): search},
    );
    // Both answer with every match at once: v2 in a page envelope, v1 as a
    // bare array, or null when nothing matches.
    final items = switch ((version, response.data)) {
      (ApiVersion.v2, {'items': final List<Object?>? items}) => items,
      (ApiVersion.v1, final List<Object?>? items) => items,
      _ => throw UnexpectedResponse(
        response.statusCode,
        message: 'not a user list',
      ),
    };
    return List.unmodifiable(objectListOf(items).map(parseUser).nonNulls);
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    final search = query.trim();
    if (search.isEmpty) return const [];
    final version = _transport.version;
    final response = await _transport.get(
      '/users',
      query: {searchParameterName(version): search},
    );
    // v2 wraps every match in one page envelope; v1 sends a bare array, or
    // null when nothing matches.
    final items = switch ((version, response.data)) {
      (ApiVersion.v2, {'items': final List<Object?>? items}) => items,
      (ApiVersion.v1, final List<Object?>? items) => items,
      _ => throw UnexpectedResponse(
        response.statusCode,
        message: 'not a user list',
      ),
    };
    return List.unmodifiable(objectListOf(items).map(parseOtherUser).nonNulls);
  }
}

final class _ProjectsApi implements ProjectsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<Project>> list({
    int page = 1,
    int? perPage,
    bool includeArchived = false,
    String? search,
  }) async {
    final response = await _transport.get(
      '/projects',
      query: {
        if (includeArchived) 'is_archived': 'true',
        if (search case final search? when search.isNotEmpty)
          searchParameterName(_transport.version): search,
        'page': page,
        'per_page': ?perPage,
        // Without it every max_permission is null (0 before 2.5/2.6).
        'expand': 'permissions',
      },
    );
    return _transport.page(
      response,
      page: page,
      perPage: perPage,
      parse: parseProject,
    );
  }

  @override
  Future<List<Project>> listAll({bool includeArchived = false}) =>
      _transport.allPages(
        (page) => list(page: page, includeArchived: includeArchived),
        idOf: (project) => project.id,
        what: '/projects',
      );

  @override
  Future<Project> read(int id) async {
    final response = await _transport.get('/projects/$id');
    final header = Permission.fromValue(
      int.tryParse(response.headers.value('x-max-permission') ?? ''),
    );
    return _transport.decode<Project>(
      response,
      (json) => parseProject(json, maxPermission: header),
    );
  }
}

final class _LabelsApi implements LabelsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<Label>> list({int page = 1, int? perPage, String? search}) async {
    if (search != null && _isIdLookup(search)) {
      return await _matchingLocally(search, page: page, perPage: perPage);
    }
    final response = await _transport.get(
      '/labels',
      query: {
        if (search case final search? when search.isNotEmpty)
          searchParameterName(_transport.version): search,
        'page': page,
        'per_page': ?perPage,
      },
    );
    return _transport.page(
      response,
      page: page,
      perPage: perPage,
      parse: parseLabel,
    );
  }

  @override
  Future<List<Label>> listAll() => _transport.allPages(
    (page) => list(page: page),
    idOf: (label) => label.id,
    what: '/labels',
  );

  // The server takes a search with a comma-separated part that is a
  // number for a list of ids, so a label titled "2026" is never found by
  // its title.
  static bool _isIdLookup(String search) => search
      .trim()
      .split(',')
      .any(
        (part) => _signedDigits.hasMatch(part) && int.tryParse(part) != null,
      );

  static final _signedDigits = RegExp(r'^[+-]?[0-9]+$');

  /// The server's text search (title or description, ignoring case) over
  /// every label, as one page.
  Future<Page<Label>> _matchingLocally(
    String search, {
    required int page,
    required int? perPage,
  }) async {
    final needle = search.trim().toLowerCase();
    final matches = page != 1
        ? const <Label>[]
        : [
            for (final label in await listAll())
              if (label.title.toLowerCase().contains(needle) ||
                  label.description.toLowerCase().contains(needle))
                label,
          ];
    return Page(
      items: List.unmodifiable(matches),
      page: page,
      perPage: perPage ?? matches.length,
      totalPages: 1,
      total: matches.length,
    );
  }
}

final class _TasksApi implements TasksPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<Task>> list(TaskQuery query) =>
      _listTasks('/tasks', query, inView: false);

  @override
  Future<Page<Task>> listInProject(int projectId, TaskQuery query) =>
      _listTasks('/projects/$projectId/tasks', query, inView: false);

  @override
  Future<Page<Task>> listInView(int projectId, int viewId, TaskQuery query) =>
      _listTasks(
        '/projects/$projectId/views/$viewId/tasks',
        query,
        inView: true,
      );

  @override
  Future<Task> read(int id, {Set<TaskExpand> expand = const {}}) async {
    final response = await _transport.get(
      '/tasks/$id',
      query: {
        if (expand.isNotEmpty)
          'expand': [for (final expand in expand) expand.wireName],
      },
    );
    return _transport.decode<Task>(response, parseTask);
  }

  @override
  Future<TaskDetails> readDetails(int id) async {
    final response = await _transport.get(
      '/tasks/$id',
      query: {
        'expand': [for (final expand in _detailExpands) expand.wireName],
      },
    );
    final details = _transport.decode<TaskDetails>(response, parseTaskDetails);
    if (details.maxPermission != null) return details;
    // v1 tells the permission of a single read in a header instead.
    final header = response.headers.value('x-max-permission');
    return switch (Permission.fromValue(int.tryParse(header ?? ''))) {
      final permission? => details.copyWith(maxPermission: permission),
      null => details,
    };
  }

  static const List<TaskExpand> _detailExpands = [
    TaskExpand.reactions,
    TaskExpand.commentCount,
    TaskExpand.isUnread,
  ];

  @override
  Future<Task> readByIndex(String project, int index) async {
    // A URI drops a `.` or `..` segment even when escaped, so such an
    // identifier cannot be named in a path; the project id still works.
    if (project == '.' || project == '..') throw const NotFound(code: 3001);
    if (!_byIndexRoute) return await _filteredByIndex(project, index);
    final response = await _transport.get(
      '/projects/${Uri.encodeComponent(project)}/tasks/by-index/$index',
      allowTemporaryRedirect: _transport.version == ApiVersion.v2,
    );
    if (response.statusCode != _temporaryRedirect) {
      return _transport.decode<Task>(response, parseTask);
    }
    final target = _byIndexLocation.firstMatch(
      response.headers.value('location') ?? '',
    );
    if (target == null) {
      throw const UnexpectedResponse(
        _temporaryRedirect,
        message: 'a redirect elsewhere than to another task index',
      );
    }
    final followed = await _transport.get(
      target[1]!,
      query: Uri(query: target[2]).queryParametersAll,
    );
    return _transport.decode<Task>(followed, parseTask);
  }

  static const _temporaryRedirect = 307;

  // The server writes its own prefix, whatever path it is served under, so
  // only the part after it is kept and joined to the account's base.
  static final _byIndexLocation = RegExp(
    r'^/api/v2(/projects/\d+/tasks/by-index/\d+)(?:\?(.*))?$',
  );

  // Vikunja 2.3 has no by-index route; it answers every such path with a
  // 404 that cannot be told from an unknown project.
  bool get _byIndexRoute => _transport.serverVersion?.isAtLeast(2, 4) ?? true;

  Future<Task> _filteredByIndex(String project, int index) async {
    final projectId = _digits.hasMatch(project)
        ? int.tryParse(project) ?? (throw const NotFound(code: 3001))
        : await _projectIdentified(project);
    final found = await listInProject(
      projectId,
      TaskQuery(
        filter: 'index = $index',
        sort: const [TaskSort(TaskSortField.id)],
        perPage: 1,
      ),
    );
    return found.items.firstOrNull ?? (throw const NotFound(code: 4002));
  }

  static final _digits = RegExp(r'^[0-9]+$');

  /// A project the user cannot read is not listed, so its identifier is
  /// `NotFound` too; an identifier that names several projects (2.3 keeps
  /// `ab` and `AB` apart) names none.
  Future<int> _projectIdentified(String identifier) async {
    final projects = await _ProjectsApi(_transport)
        .listAll(includeArchived: true);
    final named = namedByIdentifier(
      identifier,
      projects.where((project) => !project.isPseudo),
      identifierOf: (project) => project.identifier,
    );
    return named.singleOrNull?.id ?? (throw const NotFound(code: 3001));
  }

  Future<Page<Task>> _listTasks(
    String path,
    TaskQuery query, {
    required bool inView,
  }) async {
    final response = await _transport.get(
      path,
      query: taskQueryParameters(
        query,
        version: _transport.version,
        inView: inView,
      ),
    );
    return _transport.page(
      response,
      page: query.page,
      perPage: query.perPage,
      parse: parseTask,
    );
  }
}

final class _ReadTransport {
  new(this._dio, this._connection)
    : version = _connection.preferredApiVersion,
      _base = _connection.apiBaseUri(_connection.preferredApiVersion);

  final Dio _dio;
  final ServerConnection _connection;
  final ApiVersion version;
  final Uri _base;

  ServerVersion? get serverVersion => _connection.info.version;

  bool offers(ApiVersion api) => _connection.apiVersions.contains(api);

  /// [allowTemporaryRedirect] hands a 307 back instead of failing.
  Future<Response<Object?>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool allowTemporaryRedirect = false,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        _base.replace(path: '${_base.path}$path').toString(),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          listFormat: ListFormat.multi,
          validateStatus: allowTemporaryRedirect ? _successOr307 : null,
        ),
      );
      rejectNotJson(response);
      return response;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
  }

  static bool _successOr307(int? status) =>
      status != null && (status >= 200 && status < 300 || status == 307);

  /// The body as it streams in, refused once it is longer than [maxBytes]
  /// (by its `Content-Length` or by what arrives), with the media type of
  /// the response without parameters. [over] asks another API version than
  /// the preferred one. What [refuse] returns for the media type is thrown
  /// before the body is read. [cancel] ends the request.
  Future<({Uint8List bytes, String contentType, int? statusCode})>
  getCappedBytes(
    String path, {
    required Map<String, Object?> query,
    required String accept,
    required int maxBytes,
    ApiVersion? over,
    VikunjaFailure? Function(String contentType)? refuse,
    CancelToken? cancel,
  }) async {
    final base = over == null ? _base : _connection.apiBaseUri(over);
    // Only a cancel closes the connection: dio does not pass the end of a
    // subscription on to the source. The caller's token must not be
    // cancelled for a refusal of this one.
    final connection = CancelToken();
    unawaited(
      cancel?.whenCancel.then((error) {
        if (!connection.isCancelled) connection.cancel(error.error);
      }),
    );
    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        base.replace(path: '${base.path}$path').toString(),
        queryParameters: query,
        cancelToken: connection,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': accept},
          extra: {maxBodyBytesKey: maxBytes},
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(await _withReadErrorBody(error, connection));
    }
    final contentType =
        (response.headers.value(Headers.contentTypeHeader) ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
    if (refuse?.call(contentType) case final refusal?) {
      connection.cancel();
      throw refusal;
    }
    final body = response.data;
    if (body == null) {
      throw UnexpectedResponse(response.statusCode, message: 'no body');
    }
    final tooLarge = UnexpectedResponse(
      response.statusCode,
      message: 'a body larger than $maxBytes bytes',
    );
    final declared = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (declared != null && declared > maxBytes) {
      connection.cancel();
      throw tooLarge;
    }
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in body.stream) {
        bytes.add(chunk);
        if (bytes.length > maxBytes) break;
      }
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
    if (bytes.length > maxBytes) {
      connection.cancel();
      throw tooLarge;
    }
    return (
      bytes: bytes.takeBytes(),
      contentType: contentType,
      statusCode: response.statusCode,
    );
  }

  /// See [AttachmentsPort.download].
  Future<void> download(String path, File target, {CancelToken? cancel}) async {
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    final kept = part.existsSync() ? await part.length() : 0;
    final offset = kept > _resumeOverlap ? kept - _resumeOverlap : 0;
    if (kept > 0 && offset == 0) await part.delete();
    final overlap = offset > 0 ? await _bytesFrom(part, offset) : Uint8List(0);
    // Only a cancel closes the connection, see [getCappedBytes]; the
    // caller's token must not be cancelled for a failure of this one.
    final connection = CancelToken();
    unawaited(
      cancel?.whenCancel.then((error) {
        if (!connection.isCancelled) connection.cancel(error.error);
      }),
    );
    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        _base.replace(path: '${_base.path}$path').toString(),
        cancelToken: connection,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': '*/*', if (offset > 0) 'Range': 'bytes=$offset-'},
          // It goes to a file, not into memory.
          extra: {maxBodyBytesKey: null},
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      if (offset > 0 && error.response?.statusCode == _rangeNotSatisfiable) {
        connection.cancel();
        await part.delete();
        return await download(path, target, cancel: cancel);
      }
      throw normalizeError(await _withReadErrorBody(error, connection));
    }
    final body = response.data;
    if (body == null) {
      throw UnexpectedResponse(response.statusCode, message: 'no body');
    }
    final resumes = response.statusCode == _partialContent;
    if (resumes &&
        !(response.headers.value('content-range') ?? '').startsWith(
          'bytes $offset-',
        )) {
      connection.cancel();
      if (part.existsSync()) await part.delete();
      throw const UnexpectedResponse(
        _partialContent,
        message: 'a range that was not asked for',
      );
    }
    final RandomAccessFile file;
    try {
      file = await part.open(mode: resumes ? FileMode.append : FileMode.write);
    } on FileSystemException {
      connection.cancel();
      rethrow;
    }
    // The part's last bytes, read again, must match, so a part that came
    // from another answer, such as a page that broke off, is never
    // completed with the file's rest (decision log: Descriptions, comments,
    // attachments).
    var unchecked = resumes ? overlap : Uint8List(0);
    var differs = false;
    try {
      await for (final chunk in body.stream) {
        final checked = min(unchecked.length, chunk.length);
        if (!_startsWith(chunk, unchecked, checked)) {
          differs = true;
          break;
        }
        unchecked = Uint8List.sublistView(unchecked, checked);
        if (checked < chunk.length) await file.writeFrom(chunk, checked);
      }
      differs = differs || unchecked.isNotEmpty;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    } on FileSystemException {
      connection.cancel();
      rethrow;
    } on Exception catch (error) {
      // The adapters pass a body that breaks off on as their own errors.
      throw NetworkFailure(NetworkProblem.unreachable, cause: error);
    } finally {
      await file.close();
    }
    if (differs) {
      connection.cancel();
      await part.delete();
      return await download(path, target, cancel: cancel);
    }
    await part.rename(target.path);
  }

  static const _partialContent = 206;
  static const _resumeOverlap = 4096;
  static const _rangeNotSatisfiable = 416;

  static Future<Uint8List> _bytesFrom(File part, int from) async {
    final file = await part.open();
    try {
      await file.setPosition(from);
      return await file.read(_resumeOverlap);
    } finally {
      await file.close();
    }
  }

  static bool _startsWith(Uint8List chunk, Uint8List expected, int length) {
    for (var i = 0; i < length; i++) {
      if (chunk[i] != expected[i]) return false;
    }
    return true;
  }

  // An error answer to a streamed request still streams; its small JSON
  // body carries the error code.
  static Future<DioException> _withReadErrorBody(
    DioException error,
    CancelToken cancel,
  ) async {
    final response = error.response;
    final body = response?.data;
    if (response == null || body is! ResponseBody) return error;
    final bytes = await readErrorBody(body);
    if (bytes == null) return error;
    if (bytes.length > maxErrorBodyBytes) cancel.cancel();
    response.data = bytes;
    return error;
  }

  T decode<T>(Response<Object?> response, T Function(Object?) parse) {
    try {
      return parse(response.data);
    } on MalformedJson catch (error) {
      throw UnexpectedResponse(response.statusCode, message: error.message);
    }
  }

  /// v2 answers with an envelope, v1 with a bare array and pagination
  /// headers. Nothing on v1 reports the total or the page size the server
  /// applied, so the latter is the request's, capped like the server does;
  /// without its page-count header (a proxy dropped it) the page count is
  /// null.
  Page<T> page<T>(
    Response<Object?> response, {
    required int page,
    required int? perPage,
    required T Function(Object?) parse,
  }) {
    final data = response.data;
    switch (version) {
      case ApiVersion.v2:
        if (data case {
          'items': final List<Object?> items,
          'total': final int total,
          'page': final int page,
          'per_page': final int perPage,
          'total_pages': final int totalPages,
        }) {
          return Page(
            items: decode(response, (_) => _parseAll(items, parse)),
            page: page,
            perPage: perPage,
            totalPages: totalPages,
            total: total,
          );
        }
      case ApiVersion.v1:
        if (data is List<Object?>) {
          final maxPerPage = _connection.info.maxItemsPerPage;
          return Page(
            items: decode(response, (_) => _parseAll(data, parse)),
            page: page,
            perPage: min(perPage ?? maxPerPage, maxPerPage),
            totalPages: int.tryParse(
              response.headers.value('x-pagination-total-pages') ?? '',
            ),
          );
        }
    }
    throw UnexpectedResponse(response.statusCode, message: 'not a page');
  }

  Future<List<T>> allPages<T>(
    Future<Page<T>> Function(int page) fetch, {
    required int Function(T item) idOf,
    required String what,
  }) => collectAllPages(
    (page) async {
      final current = await fetch(page);
      return (
        items: current.items,
        totalPages: current.totalPages ?? (current.hasMore ? page + 1 : page),
      );
    },
    idOf: idOf,
    what: what,
  );

  static List<T> _parseAll<T>(List<Object?> items, T Function(Object?) parse) =>
      List.unmodifiable(items.map(parse));
}
