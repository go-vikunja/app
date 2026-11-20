import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

// The contract tests need the servers of test_servers/docker-compose.yaml:
// VIKUNJA_CONTRACT=1 flutter test --tags contract
//
// /login, /register, the /ws upgrade and, before 2.7.0, /api/v1/oauth/token
// share a limit per minute and IP that cannot be switched off (10 unless
// raised, as test_servers/docker-compose.yaml does), so every
// unauthenticated call waits out a 429 when one comes.
final String? contractSkip = Platform.environment['VIKUNJA_CONTRACT'] != '1'
    ? 'Set VIKUNJA_CONTRACT=1 and start test_servers/docker-compose.yaml'
    : null;

/// The image of test_servers/docker-compose.yaml when
/// VIKUNJA_APP_TEST_VIKUNJA_IMAGE is unset or empty.
const defaultTestServerImage =
    'vikunja/vikunja:2.8.0@sha256:35d937baf3b5d5803bed6b9e11d007448b7b536df9e4346dc35551e1072636c3';

/// The release the test server runs: the tag of
/// VIKUNJA_APP_TEST_VIKUNJA_IMAGE, which test_servers/docker-compose.yaml
/// starts instead of [defaultTestServerImage].
final ServerVersion contractServerVersion = testServerVersion(
  Platform.environment['VIKUNJA_APP_TEST_VIKUNJA_IMAGE'],
);

ServerVersion testServerVersion(String? image) {
  final name = (image == null || image.isEmpty)
      ? defaultTestServerImage
      : image;
  final lastSegment = name.substring(name.lastIndexOf('/') + 1);
  final colon = lastSegment.indexOf(':');
  final version = colon < 0
      ? null
      : ServerVersion.tryParse(lastSegment.substring(colon + 1));
  if (version == null || version.isDevelopmentBuild) {
    throw ArgumentError.value(
      image,
      'VIKUNJA_APP_TEST_VIKUNJA_IMAGE',
      'needs a release tag, for example vikunja/vikunja:2.7.1',
    );
  }
  return version;
}

/// The test server's port; VIKUNJA_CONTRACT_PORT points the tests at a
/// server on another port, as it does the app's.
final int contractPort =
    int.tryParse(Platform.environment['VIKUNJA_CONTRACT_PORT'] ?? '') ?? 34527;

final List<({int port, String version})> contractServers = [
  (port: contractPort, version: contractServerVersion.display),
];

/// Vikunja serves /api/v2 from 2.4.0; 2.3, the support floor (D13), has
/// /api/v1 only.
final bool contractServerHasV2 = contractServerVersion.isAtLeast(2, 4);

/// The skip reason of a group or test over [apiVersion] on a test server
/// without it.
String? skipWithout(ApiVersion apiVersion) =>
    apiVersion == ApiVersion.v2 && !contractServerHasV2
    ? 'servers before 2.4.0 have no /api/v2'
    : null;

final List<ApiVersion> contractApiVersions = [
  for (final apiVersion in ApiVersion.values)
    if (skipWithout(apiVersion) == null) apiVersion,
];

/// [path] on /api/v2, or on /api/v1 on a server without it, for a raw
/// request that is the same on both.
Uri newestApi(ServerConnection connection, String path) {
  final base = connection.apiBaseUri(
    connection.apiVersions.contains(ApiVersion.v2)
        ? ApiVersion.v2
        : ApiVersion.v1,
  );
  return base.replace(path: '${base.path}$path');
}

/// A raw seeding request written for /api/v2. A server without it (2.3)
/// gets it on /api/v1 in v1's verbs: a create (POST) is a PUT there and a
/// replace (PUT) a POST; a merge patch becomes a read of the object, posted
/// back whole with the patch applied. A POST that creates nothing goes
/// through [newestApi] instead.
Future<Response<T>> seedRequest<T>(
  Dio dio,
  ServerConnection connection,
  String jwt,
  String method,
  String path, {
  Object? data,
  String? contentType,
}) async {
  final hasV2 = connection.apiVersions.contains(ApiVersion.v2);
  final uri = newestApi(connection, path);
  Options options(String verb, [String? type]) => Options(
    method: verb,
    contentType: type,
    headers: {'Authorization': 'Bearer $jwt'},
  );
  if (hasV2) {
    return await dio.requestUri<T>(
      uri,
      data: data,
      options: options(method, contentType),
    );
  }
  if (method == 'PATCH') {
    final current = await dio.getUri<Map<String, Object?>>(
      uri,
      options: options('GET'),
    );
    return await dio.requestUri<T>(
      uri,
      data: mergePatched(current.data!, data! as Map<String, Object?>),
      options: options('POST'),
    );
  }
  final verb = switch (method) {
    'POST' => 'PUT',
    'PUT' => 'POST',
    _ => method,
  };
  return await dio.requestUri<T>(
    uri,
    data: data,
    options: options(verb, contentType),
  );
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
        RealtimeUpgradeRefused(statusCode: 429, :final retryAfter) =>
          RateLimited(retryAfter: retryAfter),
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

/// Test files run in parallel and register at the same moment, and a write
/// right after an assignee change collides with the server's own listener
/// that bumps the task; a SQLite server without the immediate transactions
/// of test_servers/docker-compose.yaml answers a lost write race with a
/// 500. Raw dio calls throw it as a `DioException`, the clients as a
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
/// write a SQLite server refused with "database is locked" changed
/// nothing, and an update is safe to repeat anyway.
final class RetryingTasksWrites implements TasksWritePort {
  new(this._writes);

  final TasksWritePort _writes;

  @override
  Future<Task> create(NewTask task) =>
      despiteWriteRaces(() => _writes.create(task));

  @override
  Future<Task> update(
    int id,
    TaskChanges changes, {
    String Function(String current)? rebaseDescription,
  }) => despiteWriteRaces(
    () => _writes.update(id, changes, rebaseDescription: rebaseDescription),
  );

  @override
  Future<void> delete(int id) => despiteWriteRaces(() => _writes.delete(id));

  @override
  Future<Task> duplicate(int id) => _writes.duplicate(id);

  @override
  Future<void> markRead(int id) => _writes.markRead(id);
}

final class RetryingLabelsWrites implements LabelsWritePort {
  new(this._labels);

  final LabelsWritePort _labels;

  @override
  Future<Label> create(NewLabel label) =>
      despiteWriteRaces(() => _labels.create(label));

  @override
  Future<Label> update(int id, LabelChanges changes) =>
      despiteWriteRaces(() => _labels.update(id, changes));

  @override
  Future<void> delete(int id) => despiteWriteRaces(() => _labels.delete(id));
}

final class RetryingBucketsWrites implements BucketsWritePort {
  new(this._buckets);

  final BucketsWritePort _buckets;

  @override
  Future<Bucket> create(
    int projectId,
    int viewId, {
    required String title,
    int limit = 0,
    double? position,
  }) => despiteWriteRaces(
    () => _buckets.create(
      projectId,
      viewId,
      title: title,
      limit: limit,
      position: position,
    ),
  );

  @override
  Future<Bucket> update(
    int projectId,
    int viewId, {
    required int bucketId,
    required String title,
    required int limit,
    required double position,
  }) => despiteWriteRaces(
    () => _buckets.update(
      projectId,
      viewId,
      bucketId: bucketId,
      title: title,
      limit: limit,
      position: position,
    ),
  );

  @override
  Future<void> delete(int projectId, int viewId, int bucketId) =>
      despiteWriteRaces(() => _buckets.delete(projectId, viewId, bucketId));
}

final class RetryingProjectViewsWrites implements ProjectViewsWritePort {
  new(this._views);

  final ProjectViewsWritePort _views;

  @override
  Future<ProjectView> setBuckets(
    int projectId,
    int viewId, {
    int? doneBucketId,
    int? defaultBucketId,
  }) => despiteWriteRaces(
    () => _views.setBuckets(
      projectId,
      viewId,
      doneBucketId: doneBucketId,
      defaultBucketId: defaultBucketId,
    ),
  );

  @override
  Future<ProjectView> create(int projectId, ViewDraft view) =>
      despiteWriteRaces(() => _views.create(projectId, view));

  @override
  Future<ProjectView> update(int projectId, int viewId, ViewDraft view) =>
      despiteWriteRaces(() => _views.update(projectId, viewId, view));

  @override
  Future<ProjectView> move(
    int projectId,
    int viewId, {
    required double position,
  }) => despiteWriteRaces(
    () => _views.move(projectId, viewId, position: position),
  );

  @override
  Future<void> delete(int projectId, int viewId) =>
      despiteWriteRaces(() => _views.delete(projectId, viewId));
}

final class RetryingProjectsWrites implements ProjectsWritePort {
  new(this._projects);

  final ProjectsWritePort _projects;

  @override
  Future<Project> move(
    int projectId, {
    required double position,
    required int parentProjectId,
  }) => despiteWriteRaces(
    () => _projects.move(
      projectId,
      position: position,
      parentProjectId: parentProjectId,
    ),
  );

  @override
  Future<Project> create(NewProject project) =>
      despiteWriteRaces(() => _projects.create(project));

  @override
  Future<Project> update(
    int projectId,
    ProjectChanges changes, {
    String Function(String current)? rebaseDescription,
  }) => despiteWriteRaces(
    () => _projects.update(
      projectId,
      changes,
      rebaseDescription: rebaseDescription,
    ),
  );

  @override
  Future<void> delete(int projectId) =>
      despiteWriteRaces(() => _projects.delete(projectId));

  @override
  Future<Project> duplicate(
    int projectId, {
    required int parentProjectId,
    required bool copyShares,
  }) => _projects.duplicate(
    projectId,
    parentProjectId: parentProjectId,
    copyShares: copyShares,
  );
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

/// A session that signs in again once the server rejects its JWT. A login
/// JWT lives ten minutes, and a file that registers several users can wait
/// out the login limit for longer than that before its tests start.
final class RenewedJwt implements AccessTokenSource {
  new(this._jwt, this._loginAgain);

  String _jwt;
  final Future<String> Function() _loginAgain;
  Future<String>? _renewal;

  @override
  Future<String> validAccessToken() async => _jwt;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async {
    if (rejectedToken != _jwt) return _jwt;
    final renewal = _renewal ??= _loginAgain();
    try {
      return _jwt = await renewal;
    } finally {
      _renewal = null;
    }
  }
}
