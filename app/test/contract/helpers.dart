import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

// The contract tests need the server of test_servers/docker-compose.yaml:
// VIKUNJA_CONTRACT=1 flutter test --tags contract
//
// /login and /register share a limit per minute and IP that cannot be
// switched off (10 unless raised, as test_servers/docker-compose.yaml does),
// so every unauthenticated call waits out a 429 when one comes. Mirrors
// packages/vikunja_api/test/contract/helpers.dart, which a Flutter package
// cannot import.
final String? contractSkip = Platform.environment['VIKUNJA_CONTRACT'] != '1'
    ? 'Set VIKUNJA_CONTRACT=1 and start test_servers/docker-compose.yaml'
    : null;

const contractServerPort = 34527;

Dio contractDio() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'Rurana contract tests'},
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
/// bodies carry no secrets).
final class Seeder {
  new(this._dio, this._connection, this._user);

  final Dio _dio;
  final ServerConnection _connection;
  final TestUser _user;

  Uri get _v2 => _connection.apiBaseUri(ApiVersion.v2);

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
          _v2.replace(path: '${_v2.path}$path'),
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
    try {
      final response = await despiteWriteRaces(
        () => _dio.requestUri<Map<String, Object?>>(
          _v2.replace(path: '${_v2.path}$path'),
          data: body == null ? null : jsonEncode(body),
          options: Options(
            method: method,
            contentType: contentType,
            headers: {'Authorization': 'Bearer ${_user.jwt}'},
          ),
        ),
      );
      return response.data!;
    } on DioException catch (error) {
      throw StateError(
        '$method $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }
}
