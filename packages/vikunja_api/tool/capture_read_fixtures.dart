// Records the read endpoints of a local test server into test/fixtures/read
// with a throwaway user:
//   dart run tool/capture_read_fixtures.dart [http://localhost:34527] [2.8.0]
// The user's name is replaced by `fixtureuser` in every file; no file may
// hold a token or an email address.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

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
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'fixture$suffix';
  final password = 'password-$suffix';
  final user = await dio.post<String>(
    '/api/v1/register',
    data: {
      'username': username,
      'email': '$username@example.com',
      'password': password,
    },
  );
  final userId = (jsonDecode(user.data!) as Map<String, Object?>)['id']! as int;
  final login = await dio.post<String>(
    '/api/v1/login',
    data: {'username': username, 'password': password},
  );
  final jwt = (jsonDecode(login.data!) as Map<String, Object?>)['token']!;
  dio.options.headers['Authorization'] = 'Bearer $jwt';

  Future<Map<String, Object?>> send(
    String method,
    String path, [
    Object? body,
  ]) async {
    final Response<String> response;
    try {
      response = await dio.request<String>(
        path,
        data: body,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      // Project identifiers are unique server-wide: a collision means an
      // earlier capture's project still exists.
      throw StateError(
        '$method $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
    return switch (jsonDecode(response.data ?? '{}')) {
      final Map<String, Object?> json => json,
      _ => const {},
    };
  }

  final now = DateTime.now().toUtc();
  String at(Duration offset) => now.add(offset).toIso8601String();

  final project = await send('POST', '/api/v2/projects', {
    'title': 'Fixture project',
    'identifier': 'FX',
    'hex_color': '1973ff',
    'description': '<p>Captured for the read fixtures</p>',
  });
  final projectId = project['id']! as int;
  await send('POST', '/api/v2/projects', {
    'title': 'Fixture child',
    'parent_project_id': projectId,
  });
  final urgent = await send('POST', '/api/v2/labels', {
    'title': 'urgent',
    'hex_color': 'e8323c',
  });
  final home = await send('POST', '/api/v2/labels', {
    'title': 'home',
    'hex_color': '#4CAF50',
    'description': 'Things at home',
  });

  final parent = await send('POST', '/api/v2/projects/$projectId/tasks', {
    'title': 'Parent task',
    'description': '<p>Hello <strong>world</strong> &amp; friends</p>',
    'due_date': at(const Duration(days: 1)),
    'start_date': at(Duration.zero),
    'end_date': at(const Duration(days: 2)),
    'priority': 3,
    'percent_done': 0.25,
    'hex_color': 'ff00aa',
    'repeat_after': 604800,
    'reminders': [
      {'relative_period': -3600, 'relative_to': 'due_date'},
      {'reminder': at(const Duration(hours: 2))},
    ],
  });
  final parentId = parent['id']! as int;
  final subtask = await send('POST', '/api/v2/projects/$projectId/tasks', {
    'title': 'Subtask',
    'is_favorite': true,
  });
  final subtaskId = subtask['id']! as int;
  final done = await send('POST', '/api/v2/projects/$projectId/tasks', {
    'title': 'Done task',
    'done': true,
    'repeat_mode': 1,
  });
  await send('POST', '/api/v2/tasks/$subtaskId/relations', {
    'other_task_id': parentId,
    'relation_kind': 'parenttask',
  });
  for (final label in [urgent, home]) {
    await send('POST', '/api/v2/tasks/$parentId/labels', {
      'label_id': label['id'],
    });
  }
  await send('POST', '/api/v2/tasks/$parentId/assignees', {'user_id': userId});
  if (done['done'] != true) {
    await send('PATCH', '/api/v2/tasks/${done['id']}', {'done': true});
  }

  final outDir = Directory('test/fixtures/read');
  await outDir.create(recursive: true);
  for (final version in ['v1', 'v2']) {
    final captures = {
      'projects_page': '/api/$version/projects?per_page=2&page=1',
      'project_with_views': '/api/$version/projects/$projectId',
      'labels_page': '/api/$version/labels',
      'tasks_page':
          '/api/$version/projects/$projectId/tasks?sort_by=id&order_by=asc',
      'task': '/api/$version/tasks/$parentId',
    };
    for (final MapEntry(key: name, value: path) in captures.entries) {
      final response = await dio.get<String>(path);
      final body = response.data!.replaceAll(username, 'fixtureuser');
      if (body.contains('@') || body.contains('"token"')) {
        throw StateError('$path leaks an email or a token');
      }
      final headers = {
        for (final header in const [
          'content-type',
          'x-pagination-total-pages',
          'x-pagination-result-count',
          'x-max-permission',
        ])
          header: ?response.headers.value(header),
      };
      final file = File(
        '${outDir.path}/${version}_${name}_$serverVersion.json',
      );
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'server': serverVersion,
          'request': 'GET $path',
          'status': response.statusCode,
          'headers': headers,
          'body': body,
        }),
      );
      stdout.writeln('wrote ${file.path}');
    }
  }
  dio.close();
}
