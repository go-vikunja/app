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
import 'package:vikunja_api/src/read/read_ports.dart';
import 'package:vikunja_api/src/read/task_query_params.dart';
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

  @override
  Future<AttachmentBlob> fetch(
    int taskId,
    int attachmentId, {
    AttachmentPreviewSize? preview,
  }) async {
    final (:bytes, :contentType) = await _transport.getCappedBytes(
      '/tasks/$taskId/attachments/$attachmentId',
      query: {'preview_size': ?preview?.wireName},
      // The server answers the original for anything it cannot preview,
      // so a preview request has to take any image.
      accept: preview == null ? '*/*' : 'image/*',
      maxBytes: maxAttachmentBytes,
    );
    return AttachmentBlob(
      bytes: bytes,
      contentType: contentType.isEmpty
          ? 'application/octet-stream'
          : contentType,
    );
  }

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

  @override
  Future<AvatarImage> fetch(String username, {required int size}) async {
    final response = await _transport.getBytes(
      '/avatar/${Uri.encodeComponent(username)}',
      query: {'size': size},
      accept: 'image/*',
    );
    final contentType =
        (response.headers.value(Headers.contentTypeHeader) ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
    final bytes = response.data;
    final isImage =
        contentType.startsWith('image/') ||
        contentType == 'application/octet-stream';
    if (!isImage || bytes == null || bytes.isEmpty) {
      throw UnexpectedResponse(
        response.statusCode,
        message: 'not an image: $contentType',
      );
    }
    return AvatarImage(
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      contentType: contentType,
    );
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
      );

  @override
  Future<Project> read(int id) async {
    final response = await _transport.get('/projects/$id');
    return _transport.decode<Project>(response, parseProject);
  }
}

final class _LabelsApi implements LabelsPort {
  new(this._transport);

  final _ReadTransport _transport;

  @override
  Future<Page<Label>> list({int page = 1, int? perPage, String? search}) async {
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
  );
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

  /// [allowTemporaryRedirect] hands a 307 back instead of failing.
  Future<Response<Object?>> get(
    String path, {
    Map<String, Object?> query = const {},
    bool allowTemporaryRedirect = false,
  }) async {
    try {
      return await _dio.get<Object?>(
        _base.replace(path: '${_base.path}$path').toString(),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          listFormat: ListFormat.multi,
          validateStatus: allowTemporaryRedirect ? _successOr307 : null,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(error);
    }
  }

  static bool _successOr307(int? status) =>
      status != null && (status >= 200 && status < 300 || status == 307);

  /// The body as it streams in, refused once it is longer than [maxBytes]
  /// (by its `Content-Length` or by what arrives), with the media type of
  /// the response without parameters.
  Future<({Uint8List bytes, String contentType})> getCappedBytes(
    String path, {
    required Map<String, Object?> query,
    required String accept,
    required int maxBytes,
  }) async {
    // Only a cancel closes the connection: dio does not pass the end of a
    // subscription on to the source.
    final cancel = CancelToken();
    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        _base.replace(path: '${_base.path}$path').toString(),
        queryParameters: query,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': accept},
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw normalizeError(await _withReadErrorBody(error, cancel));
    }
    final contentType =
        (response.headers.value(Headers.contentTypeHeader) ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
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
      cancel.cancel();
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
      cancel.cancel();
      throw tooLarge;
    }
    return (bytes: bytes.takeBytes(), contentType: contentType);
  }

  /// See [AttachmentsPort.download].
  Future<void> download(String path, File target, {CancelToken? cancel}) async {
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    final offset = part.existsSync() ? await part.length() : 0;
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
      await part.delete();
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
    try {
      await for (final chunk in body.stream) {
        await file.writeFrom(chunk);
      }
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
    await part.rename(target.path);
  }

  static const _partialContent = 206;
  static const _rangeNotSatisfiable = 416;

  // An error answer to a streamed request still streams; its small JSON
  // body carries the error code.
  static Future<DioException> _withReadErrorBody(
    DioException error,
    CancelToken cancel,
  ) async {
    final response = error.response;
    final body = response?.data;
    if (response == null || body is! ResponseBody) return error;
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in body.stream) {
        bytes.add(chunk);
        if (bytes.length > _maxErrorBodyBytes) break;
      }
    } on Object {
      return error;
    }
    if (bytes.length > _maxErrorBodyBytes) cancel.cancel();
    response.data = bytes.takeBytes();
    return error;
  }

  static const int _maxErrorBodyBytes = 64 * 1024;

  Future<Response<List<int>>> getBytes(
    String path, {
    required Map<String, Object?> query,
    required String accept,
  }) async {
    try {
      return await _dio.get<List<int>>(
        _base.replace(path: '${_base.path}$path').toString(),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': accept},
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

  /// v2 answers with an envelope, v1 with a bare array and pagination
  /// headers. Nothing on v1 reports the total or the page size the server
  /// applied, so the latter is the request's, capped like the server does.
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
          final totalPages = int.tryParse(
            response.headers.value('x-pagination-total-pages') ?? '',
          );
          return Page(
            items: decode(response, (_) => _parseAll(data, parse)),
            page: page,
            perPage: min(perPage ?? maxPerPage, maxPerPage),
            totalPages: totalPages ?? page,
          );
        }
    }
    throw UnexpectedResponse(response.statusCode, message: 'not a page');
  }

  Future<List<T>> allPages<T>(
    Future<Page<T>> Function(int page) fetch, {
    required int Function(T item) idOf,
  }) async {
    // Pseudo projects repeat on every page.
    final byId = <int, T>{};
    for (var page = 1; ; page++) {
      final current = await fetch(page);
      for (final item in current.items) {
        byId.putIfAbsent(idOf(item), () => item);
      }
      if (!current.hasMore) return List.unmodifiable(byId.values);
    }
  }

  static List<T> _parseAll<T>(List<Object?> items, T Function(Object?) parse) =>
      List.unmodifiable(items.map(parse));
}
