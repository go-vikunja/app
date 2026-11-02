// Records a user's notifications into test/fixtures/read and the answers of
// the mark-read endpoints into test/fixtures/write, with two throwaway users:
//   dart run tool/capture_notification_fixtures.dart [http://localhost:34527] [2.7.1]
// The reader subscribes to the doer's project; the doer then assigns the
// reader, mentions the reader in a comment and in a description, creates and
// deletes a task, creates a child project and adds the reader to a team.
// 2.7.0 lists no task.deleted for the subscriber afterwards.
// The users are renamed `fixturereader` and `fixturedoer` and their email
// addresses replaced; no file may hold a token or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({int id, String username, String email, String jwt});

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

  final reader = await _register(dio, 'fixturer');
  final doer = await _register(dio, 'fixtured');

  Future<Object?> send(
    _User user,
    String method,
    String path, [
    Object? body,
  ]) async {
    final response = await _request(dio, user, method, path, body);
    final data = response.data;
    return data == null || data.isEmpty ? null : jsonDecode(data);
  }

  Future<int> create(_User user, String path, Object body) async {
    final created = await send(user, 'POST', path, body);
    return (created! as Map<String, Object?>)['id']! as int;
  }

  final projectId = await create(doer, '/api/v2/projects', {
    'title': 'Notification fixtures',
  });
  await send(doer, 'POST', '/api/v2/projects/$projectId/users', {
    'username': reader.username,
    'permission': 1,
  });
  await send(reader, 'PUT', '/api/v1/subscriptions/project/$projectId');

  final taskId = await create(doer, '/api/v2/projects/$projectId/tasks', {
    'title': 'Water the plants',
  });
  await send(doer, 'POST', '/api/v2/tasks/$taskId/assignees', {
    'user_id': reader.id,
  });
  await send(doer, 'PUT', '/api/v1/tasks/$taskId/comments', {
    'comment':
        '<p>Please check the <strong>pots</strong> '
        '<mention-user data-id="${reader.username}">@${reader.username}'
        '</mention-user> &amp; the window boxes, too.</p>',
  });
  await create(doer, '/api/v2/projects/$projectId/tasks', {
    'title': 'Buy soil',
    'description':
        '<p><mention-user data-id="${reader.username}">@${reader.username}'
        '</mention-user> which kind?</p>',
  });
  final doomedId = await create(doer, '/api/v2/projects/$projectId/tasks', {
    'title': 'Short-lived',
  });
  await send(doer, 'DELETE', '/api/v2/tasks/$doomedId');
  await create(doer, '/api/v2/projects', {
    'title': 'Balcony',
    'parent_project_id': projectId,
  });
  final teamId = await create(doer, '/api/v2/teams', {'name': 'Gardeners'});
  await send(doer, 'POST', '/api/v2/teams/$teamId/members', {
    'username': reader.username,
  });

  // The server stores notifications from asynchronous event handlers.
  for (var attempt = 0; ; attempt++) {
    final page = await send(reader, 'GET', '/api/v1/notifications');
    final names = {
      for (final item in page! as List<Object?>)
        (item! as Map<String, Object?>)['name'],
    };
    if (names.length >= 6 || attempt == 20) break;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(reader.email, 'fixturereader@example.invalid')
        .replaceAll(doer.email, 'fixturedoer@example.invalid')
        .replaceAll(reader.username, 'fixturereader')
        .replaceAll(doer.username, 'fixturedoer');
    if (scrubbed.contains('@example.com') || scrubbed.contains('"token"')) {
      throw StateError('a capture leaks an email or a token');
    }
    return scrubbed;
  }

  Future<void> write(
    String directory,
    String name,
    String method,
    String path,
    Response<String> response,
  ) async {
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
    stdout.writeln('wrote ${file.path}');
  }

  for (final version in ['v1', 'v2']) {
    final path = '/api/$version/notifications';
    await write(
      'read',
      '${version}_notifications_page',
      'GET',
      path,
      await _request(dio, reader, 'GET', path),
    );
  }

  final list = jsonDecode(
    (await _request(dio, reader, 'GET', '/api/v1/notifications')).data!,
  ) as List<Object?>;
  final ids = [for (final item in list) (item! as Map<String, Object?>)['id']];
  final writes = <(String, String, String, Object?)>[
    (
      'v2_notification_mark_read',
      'PUT',
      '/api/v2/notifications/${ids[0]}',
      {'read': true},
    ),
    (
      'v1_notification_mark_read',
      'POST',
      '/api/v1/notifications/${ids[1]}',
      {'read': true},
    ),
    (
      'v2_notification_mark_unread',
      'PUT',
      '/api/v2/notifications/${ids[0]}',
      {'read': false},
    ),
    (
      'v2_notification_mark_unknown',
      'PUT',
      '/api/v2/notifications/999999999',
      {'read': true},
    ),
    (
      'v1_notification_mark_unknown',
      'POST',
      '/api/v1/notifications/999999999',
      {'read': true},
    ),
    ('v2_notifications_mark_all', 'POST', '/api/v2/notifications', null),
    ('v1_notifications_mark_all', 'POST', '/api/v1/notifications', null),
  ];
  for (final (name, method, path, body) in writes) {
    final response = await _send(
      dio,
      reader,
      method,
      path,
      body: body,
      acceptErrors: true,
    );
    await write('write', name, method, path, response);
  }
  dio.close();
}

Future<_User> _register(Dio dio, String prefix) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = '$prefix$suffix';
  final email = '$username@example.com';
  final password = 'password-$suffix';
  final user = await _unauthenticated(
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
    id: (jsonDecode(user.data!) as Map<String, Object?>)['id']! as int,
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
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }
}

Future<Response<String>> _request(
  Dio dio,
  _User user,
  String method,
  String path, [
  Object? body,
]) => _send(dio, user, method, path, body: body);

Future<Response<String>> _send(
  Dio dio,
  _User user,
  String method,
  String path, {
  Object? body,
  bool acceptErrors = false,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await dio.request<String>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {'Authorization': 'Bearer ${user.jwt}'},
          validateStatus: acceptErrors ? (_) => true : null,
        ),
      );
    } on DioException catch (error) {
      // The SQLite server answers a write that collides with its own
      // notification handlers with a 500 and changes nothing.
      if (error.response?.statusCode == 500 && attempt < 8) {
        await Future<void>.delayed(Duration(seconds: attempt));
        continue;
      }
      throw StateError(
        '$method $path failed with ${error.response?.statusCode}: '
        '${error.response?.data}',
      );
    }
  }
}
