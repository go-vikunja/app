import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/src/dto/json_values.dart';
import 'package:vikunja_api/src/dto/label_codec.dart';
import 'package:vikunja_api/src/dto/project_codec.dart';
import 'package:vikunja_api/src/dto/task_codec.dart';
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
      users = _UsersApi(transport);

  @override
  final ProjectsPort projects;

  @override
  final LabelsPort labels;

  @override
  final TasksPort tasks;

  @override
  final UsersPort users;
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

  Future<Response<Object?>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    try {
      return await _dio.get<Object?>(
        _base.replace(path: '${_base.path}$path').toString(),
        queryParameters: query,
        options: Options(
          responseType: ResponseType.json,
          headers: {'Accept': 'application/json'},
          listFormat: ListFormat.multi,
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
