// Records the bucket writes and the kanban view update into
// test/fixtures/write, with one throwaway user:
//   dart run tool/capture_bucket_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// A project whose Kanban view has To-Do, Doing (holding one task) and Done:
// creates (with and without a position, an empty title), updates, the view
// read and its done and default bucket changes (v1 full replace, v2 patch,
// an unchanged patch, a bucket of another view), deletes (a bucket with a
// task, one gone already, the last of a second board) and a create in the
// archived project. Writes are paced by half a second. The user is renamed
// `fixtureuser` and the email address replaced; no file may hold a token
// or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _mergePatch = 'application/merge-patch+json';

Future<void> main(List<String> args) async {
  final root = args.elementAtOrNull(0) ?? 'http://localhost:34527';
  final serverVersion = args.elementAtOrNull(1) ?? '2.8.0';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
    ),
  );
  final user = await _register(dio, 'fixturebk');

  Future<Response<String>> request(
    String method,
    String path, {
    Object? body,
    String? contentType,
  }) => _send(
    dio,
    user,
    method,
    path,
    body: body,
    contentType: contentType,
    acceptErrors: true,
  );

  Future<Object?> send(String method, String path, [Object? body]) async {
    final response = await request(method, path, body: body);
    final status = response.statusCode ?? 0;
    if (status >= 300) {
      throw StateError('$method $path failed with $status: ${response.data}');
    }
    final data = response.data;
    return data == null || data.isEmpty ? null : jsonDecode(data);
  }

  Future<int> create(String path, Object body) async {
    final created = await send('PUT', path, body);
    return (created! as Map<String, Object?>)['id']! as int;
  }

  Future<Map<String, int>> bucketsOf(String view) async {
    final buckets =
        (await send('GET', '/api/v1$view/buckets'))! as List<Object?>;
    return {
      for (final bucket in buckets.cast<Map<String, Object?>>())
        bucket['title']! as String: bucket['id']! as int,
    };
  }

  final projectId = await create('/api/v1/projects', {
    'title': 'Bucket fixture',
  });
  final views =
      (await send('GET', '/api/v1/projects/$projectId/views'))!
          as List<Object?>;
  final kanbanId =
      views.cast<Map<String, Object?>>().firstWhere(
            (view) => view['view_kind'] == 'kanban',
          )['id']!
          as int;
  final kanban = '/projects/$projectId/views/$kanbanId';
  final buckets = await bucketsOf(kanban);
  final doing = buckets['Doing']!;
  final done = buckets['Done']!;
  await create('/api/v1/projects/$projectId/tasks', {
    'title': 'Water the plants',
  });
  final milk = await create('/api/v1/projects/$projectId/tasks', {
    'title': 'Buy milk',
  });
  await send('POST', '/api/v1$kanban/buckets/$doing/tasks', {'task_id': milk});

  final secondId = await create('/api/v1/projects/$projectId/views', {
    'title': 'Second board',
    'view_kind': 'kanban',
    'bucket_configuration_mode': 'manual',
  });
  final second = '/projects/$projectId/views/$secondId';
  final secondBuckets = await bucketsOf(second);

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    if (scrubbed.contains('@example.com') || scrubbed.contains(user.jwt)) {
      throw StateError('a capture leaks an email or a token');
    }
    return scrubbed;
  }

  Future<String> capture(
    String name,
    String method,
    String path, {
    Object? body,
    String? contentType,
  }) async {
    final response = await request(
      method,
      path,
      body: body,
      contentType: contentType,
    );
    final file = File('test/fixtures/write/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        'status': response.statusCode,
        'headers': {'content-type': ?response.headers.value('content-type')},
        'body': scrub(response.data ?? ''),
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    return response.data ?? '';
  }

  int idOf(String body) =>
      (jsonDecode(body) as Map<String, Object?>)['id']! as int;

  final later = idOf(
    await capture(
      'v1_bucket_create',
      'PUT',
      '/api/v1$kanban/buckets',
      body: {'title': 'Later', 'limit': 0},
    ),
  );
  final someday = idOf(
    await capture(
      'v2_bucket_create',
      'POST',
      '/api/v2$kanban/buckets',
      body: {'title': 'Someday', 'limit': 3, 'position': 500},
    ),
  );
  await capture(
    'v1_bucket_create_empty_title',
    'PUT',
    '/api/v1$kanban/buckets',
    body: {'title': '', 'limit': 0},
  );
  await capture(
    'v2_bucket_create_empty_title',
    'POST',
    '/api/v2$kanban/buckets',
    body: {'title': '', 'limit': 0},
  );
  await capture(
    'v1_bucket_update',
    'POST',
    '/api/v1$kanban/buckets/$later',
    body: {'title': 'Next week', 'limit': 2, 'position': 450},
  );
  await capture(
    'v2_bucket_update',
    'PUT',
    '/api/v2$kanban/buckets/$someday',
    body: {'title': 'Some day', 'limit': 0, 'position': 600},
  );

  final v1View = jsonDecode(
    await capture('v1_project_view', 'GET', '/api/v1$kanban'),
  ) as Map<String, Object?>;
  await capture(
    'v1_project_view_update',
    'POST',
    '/api/v1$kanban',
    body: {...v1View, 'done_bucket_id': doing},
  );
  await capture('v2_project_view', 'GET', '/api/v2$kanban');
  await capture(
    'v2_project_view_patch',
    'PATCH',
    '/api/v2$kanban',
    body: {'done_bucket_id': done, 'default_bucket_id': later},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_view_patch_unchanged',
    'PATCH',
    '/api/v2$kanban',
    body: {'done_bucket_id': done},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_view_patch_foreign',
    'PATCH',
    '/api/v2$kanban',
    body: {'done_bucket_id': secondBuckets.values.first},
    contentType: _mergePatch,
  );

  await capture('v1_bucket_delete', 'DELETE', '/api/v1$kanban/buckets/$doing');
  await capture(
    'v2_bucket_delete',
    'DELETE',
    '/api/v2$kanban/buckets/$someday',
  );
  await capture(
    'v1_bucket_delete_unknown',
    'DELETE',
    '/api/v1$kanban/buckets/$doing',
  );
  await capture(
    'v2_bucket_delete_unknown',
    'DELETE',
    '/api/v2$kanban/buckets/$someday',
  );

  final [...doomed, last] = secondBuckets.values.toList();
  for (final bucketId in doomed) {
    await send('DELETE', '/api/v1$second/buckets/$bucketId');
  }
  await capture(
    'v1_bucket_delete_last',
    'DELETE',
    '/api/v1$second/buckets/$last',
  );
  await capture(
    'v2_bucket_delete_last',
    'DELETE',
    '/api/v2$second/buckets/$last',
  );

  final project =
      (await send('GET', '/api/v1/projects/$projectId'))!
          as Map<String, Object?>;
  await send('POST', '/api/v1/projects/$projectId', {
    ...project,
    'is_archived': true,
  });
  await capture(
    'v2_bucket_create_archived',
    'POST',
    '/api/v2$kanban/buckets',
    body: {'title': 'Archived', 'limit': 0},
  );
  dio.close();
}

Future<_User> _register(Dio dio, String prefix) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = '$prefix$suffix';
  final email = '$username@example.com';
  final password = 'password-$suffix';
  await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/register',
      data: {'username': username, 'email': email, 'password': password},
    ),
  );
  final login = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/login',
      data: {'username': username, 'password': password},
    ),
  );
  return (
    username: username,
    email: email,
    jwt: (jsonDecode(login.data!) as Map<String, Object?>)['token']! as String,
  );
}

/// Waits out the shared limit of /register and /login.
Future<Response<String>> _unauthenticated(
  Future<Response<String>> Function() call,
) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await call();
    } on DioException catch (error) {
      if (error.response?.statusCode != 429 || attempt == 8) rethrow;
      final retryAfter = int.tryParse(
        error.response?.headers.value('retry-after') ?? '',
      );
      await Future<void>.delayed(Duration(seconds: (retryAfter ?? 14) + 1));
    }
  }
}

Future<Response<String>> _send(
  Dio dio,
  _User user,
  String method,
  String path, {
  Object? body,
  String? contentType,
  bool acceptErrors = false,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        contentType: contentType,
        headers: {'Authorization': 'Bearer ${user.jwt}'},
        validateStatus: acceptErrors ? (_) => true : null,
      ),
    );
    if (method != 'GET') {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // The SQLite server answers a write that collides with its own event
    // handlers with a 500 and changes nothing.
    if (response.statusCode == 500 && attempt < 8) {
      await Future<void>.delayed(Duration(seconds: attempt));
      continue;
    }
    if (response.statusCode == 429 && attempt < 8) {
      final retryAfter = int.tryParse(
        response.headers.value('retry-after') ?? '',
      );
      await Future<void>.delayed(Duration(seconds: (retryAfter ?? 10) + 1));
      continue;
    }
    return response;
  }
}
