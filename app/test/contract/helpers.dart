import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

// The contract tests need the server of test_servers/docker-compose.yaml:
// VIKUNJA_CONTRACT=1 flutter test --tags contract
// VIKUNJA_CONTRACT_PORT points them at a server on another port.
//
// /login and /register share a limit per minute and IP that cannot be
// switched off (10 unless raised, as test_servers/docker-compose.yaml does),
// so every unauthenticated call waits out a 429 when one comes. Mirrors
// packages/vikunja_api/test/contract/helpers.dart, which a Flutter package
// cannot import.
final String? contractSkip = Platform.environment['VIKUNJA_CONTRACT'] != '1'
    ? 'Set VIKUNJA_CONTRACT=1 and start test_servers/docker-compose.yaml'
    : null;

final int contractServerPort =
    int.tryParse(Platform.environment['VIKUNJA_CONTRACT_PORT'] ?? '') ?? 34527;

/// The API versions the test server serves, known before the tests run:
/// v1 only when VIKUNJA_APP_TEST_VIKUNJA_IMAGE names a release before
/// 2.4.0, which brought /api/v2; 2.3 is the support floor
/// (decision log: Servers).
final List<ApiVersion> contractApiVersions = [
  ApiVersion.v1,
  if (_imageHasV2(Platform.environment['VIKUNJA_APP_TEST_VIKUNJA_IMAGE']))
    ApiVersion.v2,
];

bool _imageHasV2(String? image) {
  final name = image ?? '';
  final lastSegment = name.substring(name.lastIndexOf('/') + 1);
  final colon = lastSegment.indexOf(':');
  if (colon < 0) return true;
  final version = ServerVersion.tryParse(
    lastSegment.substring(colon + 1).split('@').first,
  );
  return version == null || version.isAtLeast(2, 4);
}

Dio contractDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'Vikunja app contract tests'},
  ),
);

// Parallel test files wait out the same limit and would wake up and collide
// together again.
final Random _jitter = Random();

Duration _spread(Duration wait) =>
    wait + Duration(milliseconds: _jitter.nextInt(3000));

Future<T> patiently<T>(Future<T> Function() call) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on Object catch (error) {
      final failure = switch (error) {
        final VikunjaFailure failure => failure,
        final DioException exception => normalizeError(exception),
        _ => null,
      };
      if (failure is! RateLimited || attempt == 8) rethrow;
      await Future<void>.delayed(
        _spread(
          (failure.retryAfter ?? const Duration(seconds: 10)) +
              const Duration(seconds: 1),
        ),
      );
    }
  }
}

typedef TestUser = ({int id, String username, String jwt});

/// Registers a random user and signs in with the password, which gives a
/// plain user JWT without the browser leg.
Future<TestUser> registerAndLogin(Dio dio, ServerConnection connection) async =>
    (await registerAndLoginAgainLater(dio, connection)).user;

/// [registerAndLogin], and a way to sign in again, which starts another
/// session of the user and answers its JWT. The password stays in memory.
Future<({TestUser user, Future<String> Function() loginAgain})>
registerAndLoginAgainLater(Dio dio, ServerConnection connection) async {
  final v1 = connection.apiBaseUri(ApiVersion.v1);
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'sync$suffix';
  final password = 'password-$suffix';
  final registered = await despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v1.replace(path: '${v1.path}/register'),
      data: {
        'username': username,
        'email': '$username@example.com',
        'password': password,
      },
    ),
  );
  Future<String> login() async {
    final response = await despiteWriteRaces(
      () => dio.postUri<Map<String, Object?>>(
        v1.replace(path: '${v1.path}/login'),
        data: {'username': username, 'password': password},
      ),
    );
    return response.data!['token']! as String;
  }

  return (
    user: (
      id: registered.data!['id']! as int,
      username: username,
      jwt: await login(),
    ),
    loginAgain: login,
  );
}

/// A SQLite server without the immediate transactions of
/// test_servers/docker-compose.yaml answers a lost write race ("database is
/// locked") with a 500, which test files running in parallel provoke. Raw
/// dio calls throw it as a `DioException`, the clients as a `ServerFailure`.
Future<T> despiteWriteRaces<T>(Future<T> Function() call) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await patiently(call);
    } on Object catch (error) {
      final failure = switch (error) {
        final VikunjaFailure failure => failure,
        final DioException exception => normalizeError(exception),
        _ => null,
      };
      if (failure is! ServerFailure || attempt == 8) rethrow;
      await Future<void>.delayed(_spread(Duration(seconds: attempt)));
    }
  }
}

/// The same server, with [version] as its only API, so the read client
/// under test uses it.
ServerConnection onlyApiVersion(
  ServerConnection connection,
  ApiVersion version,
) => ServerConnection(
  rootUri: connection.rootUri,
  apiVersions: {version},
  info: connection.info,
  capabilities: connection.capabilities,
);

/// A session with one long-lived JWT that cannot be refreshed.
final class StaticJwt implements AccessTokenSource {
  new(this._jwt);

  final String _jwt;

  @override
  Future<String> validAccessToken() async => _jwt;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async => null;
}

/// Raw v2 writes for seeding, with the server's message on failure (error
/// bodies carry no secrets). A server without /api/v2 (2.3) gets them on
/// /api/v1 in v1's verbs: a create (POST) is a PUT there and a replace (PUT)
/// a POST. Before 2.7 a merge patch goes the v1 way too, a read of the
/// object posted back whole with the patch applied: 2.4.0's v2 refuses a
/// patch of a followed task (subscription.entity) and has none for the
/// settings.
final class Seeder {
  new(this._dio, this._connection, this._user);

  final Dio _dio;
  final ServerConnection _connection;
  final TestUser _user;

  bool get _hasV2 => _connection.apiVersions.contains(ApiVersion.v2);

  Uri get _newest =>
      _connection.apiBaseUri(_hasV2 ? ApiVersion.v2 : ApiVersion.v1);

  bool get _patchesOnV2 =>
      _hasV2 && (_connection.info.version?.isAtLeast(2, 7) ?? true);

  Future<Map<String, Object?>> get(String path) => _send('GET', path, null);

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body);

  Future<Map<String, Object?>> put(String path, Map<String, Object?> body) =>
      _send('PUT', path, body);

  /// JSON merge patch, which v2 generates for every resource with GET + PUT.
  Future<Map<String, Object?>> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body, contentType: 'application/merge-patch+json');

  Future<int> create(String path, Map<String, Object?> body) async =>
      (await post(path, body))['id']! as int;

  Future<void> delete(String path) async {
    try {
      await despiteWriteRaces(
        () => _dio.deleteUri<Object?>(
          _newest.replace(path: '${_newest.path}$path'),
          options: Options(headers: {'Authorization': 'Bearer ${_user.jwt}'}),
        ),
      );
    } on DioException catch (error) {
      throw StateError(
        'DELETE $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path,
    Map<String, Object?>? body, {
    String contentType = Headers.jsonContentType,
  }) async {
    if (method == 'PATCH' && !_patchesOnV2) {
      const v1 = ApiVersion.v1;
      final current = path == '/user/settings/general'
          ? (await _request('GET', '/user', null, over: v1))['settings']!
                as Map<String, Object?>
          : await _request('GET', path, null, over: v1);
      return await _request(
        'POST',
        path,
        mergePatched(current, body!),
        over: v1,
      );
    }
    if (!_hasV2) {
      switch (method) {
        case 'POST':
          return await _request('PUT', path, body);
        case 'PUT':
          return await _request('POST', path, body);
      }
    }
    return await _request(method, path, body, contentType: contentType);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path,
    Map<String, Object?>? body, {
    String contentType = Headers.jsonContentType,
    ApiVersion? over,
  }) async {
    final base = over == null ? _newest : _connection.apiBaseUri(over);
    try {
      final response = await despiteWriteRaces(
        () => _dio.requestUri<Object?>(
          base.replace(path: '${base.path}$path'),
          data: body == null ? null : jsonEncode(body),
          options: Options(
            method: method,
            contentType: contentType,
            headers: {'Authorization': 'Bearer ${_user.jwt}'},
          ),
        ),
      );
      // v1 answers a list bare, v2 in a page.
      return switch (response.data) {
        final List<Object?> items => {'items': items},
        final data => data! as Map<String, Object?>,
      };
    } on DioException catch (error) {
      throw StateError(
        '$method $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }
}

/// [patch] applied to [target] as a JSON merge patch (RFC 7396).
Map<String, Object?> mergePatched(
  Map<String, Object?> target,
  Map<String, Object?> patch,
) => {
  for (final MapEntry(:key, :value) in target.entries)
    if (!patch.containsKey(key)) key: value,
  for (final MapEntry(:key, :value) in patch.entries)
    if (value != null)
      key: switch ((target[key], value)) {
        (final Map<String, Object?> current, final Map<String, Object?> v) =>
          mergePatched(current, v),
        _ => value,
      },
};

/// The items of a raw list read: v2's `items`, or v1's bare array on a
/// server without /api/v2, which takes the same path and query.
Future<List<Map<String, Object?>>> rawItems(
  Dio dio,
  ServerConnection connection,
  TestUser user,
  String path,
  Map<String, Object> query,
) async {
  final base = connection.apiBaseUri(
    connection.apiVersions.contains(ApiVersion.v2)
        ? ApiVersion.v2
        : ApiVersion.v1,
  );
  final response = await despiteWriteRaces(
    () => dio.getUri<Object?>(
      base.replace(path: '${base.path}$path', queryParameters: query),
      options: Options(headers: {'Authorization': 'Bearer ${user.jwt}'}),
    ),
  );
  final items = switch (response.data) {
    final Map<String, Object?> page => page['items'],
    final other => other,
  };
  return [
    for (final item in items! as List<Object?>) item! as Map<String, Object?>,
  ];
}

/// The saved filter "My Open Tasks" that every new user gets from 2.4; on
/// 2.3, which makes none, the seeder makes it.
Future<void> ensureMyOpenTasks(Seeder seeder, TestUser user) async {
  final projects = (await seeder.get('/projects'))['items']! as List<Object?>;
  if (projects.any((p) => (p! as Map)['id']! as int < Project.favoritesId)) {
    return;
  }
  await seeder.post('/filters', {
    'title': 'My Open Tasks',
    'filters': {'filter': 'done = false && assignees = ${user.username}'},
  });
}
