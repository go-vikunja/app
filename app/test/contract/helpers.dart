import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

// The contract tests need the server of test_servers/docker-compose.yaml:
// VIKUNJA_CONTRACT=1 flutter test --tags contract
//
// /login and /register share a limit of 10 requests per minute and IP that
// cannot be switched off, so a run registers one user and every
// unauthenticated call waits out a 429. Mirrors
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
        (failure.retryAfter ?? const Duration(seconds: 10)) +
            const Duration(seconds: 1),
      );
    }
  }
}

typedef TestUser = ({int id, String username, String jwt});

/// Registers a random user and signs in with the password, which gives a
/// plain user JWT without the browser leg.
Future<TestUser> registerAndLogin(Dio dio, ServerConnection connection) async {
  final v1 = connection.apiBaseUri(ApiVersion.v1);
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'sync$suffix';
  final password = 'password-$suffix';
  final registered = await _despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v1.replace(path: '${v1.path}/register'),
      data: {
        'username': username,
        'email': '$username@example.com',
        'password': password,
      },
    ),
  );
  final login = await _despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v1.replace(path: '${v1.path}/login'),
      data: {'username': username, 'password': password},
    ),
  );
  return (
    id: registered.data!['id']! as int,
    username: username,
    jwt: login.data!['token']! as String,
  );
}

// The SQLite test server answers a lost write race with a 500.
Future<T> _despiteWriteRaces<T>(Future<T> Function() call) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await patiently(call);
    } on DioException catch (error) {
      if (normalizeError(error) is! ServerFailure || attempt == 5) rethrow;
      await Future<void>.delayed(Duration(seconds: attempt));
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

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) =>
      _send('POST', path, body);

  /// JSON merge patch, which v2 generates for every resource with GET + PUT.
  Future<Map<String, Object?>> patch(String path, Map<String, Object?> body) =>
      _send('PATCH', path, body, contentType: 'application/merge-patch+json');

  Future<int> create(String path, Map<String, Object?> body) async =>
      (await post(path, body))['id']! as int;

  Future<void> delete(String path) async {
    try {
      await _despiteWriteRaces(
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
    Map<String, Object?> body, {
    String contentType = Headers.jsonContentType,
  }) async {
    try {
      final response = await _despiteWriteRaces(
        () => _dio.requestUri<Map<String, Object?>>(
          _v2.replace(path: '${_v2.path}$path'),
          data: jsonEncode(body),
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
