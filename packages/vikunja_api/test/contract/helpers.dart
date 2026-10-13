import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

// The contract tests need the servers of test_servers/docker-compose.yaml:
// VIKUNJA_CONTRACT=1 flutter test --tags contract
//
// /login, /register and, before 2.7.0, /api/v1/oauth/token share a limit of
// 10 requests per minute and IP that cannot be switched off, so each server
// gets one user per run and every unauthenticated call waits out a 429.
final String? contractSkip = Platform.environment['VIKUNJA_CONTRACT'] != '1'
    ? 'Set VIKUNJA_CONTRACT=1 and start test_servers/docker-compose.yaml'
    : null;

const List<({int port, String version})> contractServers = [
  (port: 34527, version: '2.7.0'),
];

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
Future<TestUser> registerAndLogin(Dio dio, ServerConnection connection) async {
  final v1 = connection.apiBaseUri(ApiVersion.v1);
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'contract$suffix';
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
  final login = await despiteWriteRaces(
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

/// Test files run in parallel and register at the same moment, and a write
/// right after an assignee change collides with the server's own listener
/// that bumps the task; the SQLite test server answers a lost write race
/// with a 500. Raw dio calls throw it as a `DioException`, the clients as a
/// `ServerFailure`.
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

/// Retries every call over the lost write races of [despiteWriteRaces]. A
/// write the SQLite server refused with "database is locked" changed
/// nothing, and an update is safe to repeat anyway.
final class RetryingTasksWrites implements TasksWritePort {
  new(this._writes);

  final TasksWritePort _writes;

  @override
  Future<Task> create(NewTask task) =>
      despiteWriteRaces(() => _writes.create(task));

  @override
  Future<Task> update(int id, TaskChanges changes) =>
      despiteWriteRaces(() => _writes.update(id, changes));

  @override
  Future<void> delete(int id) => despiteWriteRaces(() => _writes.delete(id));

  @override
  Future<Task> duplicate(int id) => _writes.duplicate(id);
}

final class RetryingLabelsWrites implements LabelsWritePort {
  new(this._labels);

  final LabelsWritePort _labels;

  @override
  Future<Label> create(NewLabel label) =>
      despiteWriteRaces(() => _labels.create(label));
}

/// [connection] restricted to [version], so a client built over it uses
/// that API version.
ServerConnection onlyVersion(ServerConnection connection, ApiVersion version) =>
    ServerConnection(
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
