// Records a kanban board, per-bucket paging, moves and positions into
// test/fixtures/read and test/fixtures/write, with one throwaway user:
//   dart run tool/capture_kanban_fixtures.dart \
//     [http://localhost:34527] [2.7.1]
// A project whose Kanban view has To-Do, Doing (limit 2), Done and an
// empty Later; four tasks, three in To-Do (read two per bucket; the second
// with a label, a description and a priority) and one in Doing; then a
// move filling Doing, the same move again (no change), a move into the
// full bucket, a move into Done, positions, a repeating task moved into
// Done, an unknown bucket, and a filter-mode view with its synthetic
// buckets. Writes are paced by half a second. The user is renamed
// `fixtureuser` and the email address replaced; no file may hold a token
// or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

Future<void> main(List<String> args) async {
  final root = args.elementAtOrNull(0) ?? 'http://localhost:34527';
  final serverVersion = args.elementAtOrNull(1) ?? '2.7.1';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
    ),
  );
  final user = await _register(dio, 'fixturekb');

  Future<Response<String>> request(
    String method,
    String path, [
    Object? body,
  ]) => _send(dio, user, method, path, body: body, acceptErrors: true);

  Future<Object?> send(String method, String path, [Object? body]) async {
    final response = await request(method, path, body);
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

  final projectId = await create('/api/v1/projects', {
    'title': 'Kanban fixture',
  });
  final views =
      (await send('GET', '/api/v1/projects/$projectId/views'))!
          as List<Object?>;
  int viewOf(String kind) =>
      views.cast<Map<String, Object?>>().firstWhere(
            (view) => view['view_kind'] == kind,
          )['id']!
          as int;
  final kanbanId = viewOf('kanban');
  final listId = viewOf('list');
  final kanban = '/projects/$projectId/views/$kanbanId';
  final buckets =
      (await send('GET', '/api/v1$kanban/buckets'))! as List<Object?>;
  int bucketOf(String title) =>
      buckets.cast<Map<String, Object?>>().firstWhere(
            (bucket) => bucket['title'] == title,
          )['id']!
          as int;
  final toDo = bucketOf('To-Do');
  final doing = bucketOf('Doing');
  final done = bucketOf('Done');
  await create('/api/v1$kanban/buckets', {'title': 'Later', 'position': 400});

  final labelId = await create('/api/v1/labels', {
    'title': 'home',
    'hex_color': '4caf50',
  });
  final tasks = <String, int>{};
  for (final title in [
    'Water the plants',
    'Buy milk',
    'Call the bank',
    'Book the trip',
  ]) {
    tasks[title] = await create('/api/v1/projects/$projectId/tasks', {
      'title': title,
    });
  }
  final milk = tasks['Buy milk']!;
  final bank = tasks['Call the bank']!;
  final trip = tasks['Book the trip']!;
  await send('PUT', '/api/v1/tasks/$milk/labels', {'label_id': labelId});
  final milkAsStored =
      (await send('GET', '/api/v1/tasks/$milk'))! as Map<String, Object?>;
  await send('POST', '/api/v1/tasks/$milk', {
    ...milkAsStored,
    'description': '<p>Oat, two litres</p>',
    'priority': 3,
  });
  await send('POST', '/api/v1$kanban/buckets/$doing/tasks', {'task_id': trip});
  await send('POST', '/api/v1$kanban/buckets/$doing', {
    'title': 'Doing',
    'limit': 2,
    'position': 200,
  });

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    if (scrubbed.contains('@example.com') || scrubbed.contains(user.jwt)) {
      throw StateError('a capture leaks an email or a token');
    }
    return scrubbed;
  }

  Future<void> capture(
    String directory,
    String name,
    String method,
    String path, [
    Object? body,
  ]) async {
    final response = await request(method, path, body);
    final headers = {
      for (final header in const [
        'content-type',
        'x-pagination-total-pages',
        'x-pagination-result-count',
      ])
        header: ?response.headers.value(header),
    };
    final file = File('test/fixtures/$directory/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        'status': response.statusCode,
        'headers': headers,
        'body': scrub(response.data ?? ''),
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
  }

  await capture('read', 'v1_board', 'GET', '/api/v1$kanban/tasks?per_page=2');
  await capture(
    'read',
    'v2_board',
    'GET',
    '/api/v2$kanban/buckets/tasks?per_page=2',
  );
  final nextPage =
      'filter=bucket_id+%3D+$toDo&sort_by=position&order_by=asc'
      '&page=2&per_page=2';
  for (final version in ['v1', 'v2']) {
    await capture(
      'read',
      '${version}_bucket_tasks_page',
      'GET',
      '/api/$version$kanban/tasks?$nextPage',
    );
  }

  await capture(
    'write',
    'v1_bucket_move',
    'POST',
    '/api/v1$kanban/buckets/$doing/tasks',
    {'task_id': milk},
  );
  await capture(
    'write',
    'v2_bucket_move_unchanged',
    'PUT',
    '/api/v2$kanban/buckets/$doing/tasks',
    {'task_id': milk},
  );
  await capture(
    'write',
    'v1_bucket_move_full',
    'POST',
    '/api/v1$kanban/buckets/$doing/tasks',
    {'task_id': bank},
  );
  await capture(
    'write',
    'v2_bucket_move_full',
    'PUT',
    '/api/v2$kanban/buckets/$doing/tasks',
    {'task_id': bank},
  );
  await capture(
    'write',
    'v2_bucket_move_done',
    'PUT',
    '/api/v2$kanban/buckets/$done/tasks',
    {'task_id': bank},
  );
  await capture(
    'write',
    'v1_task_position',
    'POST',
    '/api/v1/tasks/$milk/position',
    {'project_view_id': kanbanId, 'position': 300000},
  );
  await capture(
    'write',
    'v2_task_position',
    'PUT',
    '/api/v2/tasks/$trip/position',
    {'project_view_id': kanbanId, 'position': 400000},
  );
  final repeating = await create('/api/v1/projects/$projectId/tasks', {
    'title': 'Water the garden',
    'repeat_after': 86400,
    'due_date': '2026-11-02T08:00:00Z',
  });
  await capture(
    'write',
    'v2_bucket_move_repeating',
    'PUT',
    '/api/v2$kanban/buckets/$done/tasks',
    {'task_id': repeating},
  );
  await capture(
    'write',
    'v2_bucket_move_unknown',
    'PUT',
    '/api/v2$kanban/buckets/999999999/tasks',
    {'task_id': milk},
  );

  final filterViewId = await create('/api/v1/projects/$projectId/views', {
    'title': 'By state',
    'view_kind': 'kanban',
    'bucket_configuration_mode': 'filter',
    'bucket_configuration': [
      {
        'title': 'Open',
        'filter': {'filter': 'done = false'},
      },
      {
        'title': 'Closed',
        'filter': {'filter': 'done = true'},
      },
    ],
  });
  final byState = '/projects/$projectId/views/$filterViewId';
  await capture(
    'read',
    'v1_board_filter_mode',
    'GET',
    '/api/v1$byState/tasks?per_page=2',
  );
  await capture(
    'read',
    'v2_board_filter_mode',
    'GET',
    '/api/v2$byState/buckets/tasks?per_page=2',
  );
  await capture(
    'write',
    'v2_bucket_move_filter_mode',
    'PUT',
    '/api/v2$byState/buckets/0/tasks',
    {'task_id': milk},
  );
  await capture(
    'read',
    'v2_board_list_view',
    'GET',
    '/api/v2/projects/$projectId/views/$listId/buckets/tasks',
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
  bool acceptErrors = false,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
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
