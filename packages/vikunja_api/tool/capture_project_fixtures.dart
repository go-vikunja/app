// Records the project and project view writes of step 23 into
// test/fixtures/write, with one throwaway user and a link share:
//   dart run tool/capture_project_fixtures.dart \
//     [http://localhost:34527] [2.7.0]
// Studio (colour, two tasks, one done) and its child Sketches, created by v1
// and v2; Sketches edited by a v2 merge-patch (title, identifier, colour),
// the same patch unchanged (304), read on both versions and favourited by a
// v1 full replace; an identifier taken; Studio archived (Sketches with it),
// edited while archived, Sketches unarchived under it, Studio unarchived;
// the user's default project archived; Studio duplicated by v1 (top level,
// no shares) and v2 (under Studio, with shares) and both copies deleted, one
// of them twice; a create under an archived parent. Views of Studio: a list
// created by v1 with a filter, a board created by v2 at a position, three
// refused filters, a v2 merge-patch, the same unchanged, a v1 full replace,
// the filter cleared, deletes on both versions and one twice. Last, a link
// share with write permission is refused creating a view and deleting
// Studio. The request bodies are kept as `sent`.
// Writes are paced by half a second. The user is renamed `fixtureuser` and
// the email address replaced; no file may hold a token or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _mergePatch = 'application/merge-patch+json';

Future<void> main(List<String> args) async {
  final root = args.elementAtOrNull(0) ?? 'http://localhost:34527';
  final serverVersion = args.elementAtOrNull(1) ?? '2.7.0';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
    ),
  );
  final user = await _register(dio, 'fixturepj');
  final secrets = <String>[user.jwt];

  Future<Response<String>> request(
    String method,
    String path, {
    Object? body,
    String? contentType,
    String? jwt,
  }) => _send(
    dio,
    jwt ?? user.jwt,
    method,
    path,
    body: body,
    contentType: contentType,
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

  Future<Map<String, Object?>> read(String path) async =>
      (await send('GET', path))! as Map<String, Object?>;

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    if (scrubbed.contains('@example.com') || secrets.any(scrubbed.contains)) {
      throw StateError('a capture leaks an email or a token');
    }
    return scrubbed;
  }

  Future<Map<String, Object?>> capture(
    String name,
    String method,
    String path, {
    Object? body,
    String? contentType,
    String? jwt,
  }) async {
    final response = await request(
      method,
      path,
      body: body,
      contentType: contentType,
      jwt: jwt,
    );
    final file = File('test/fixtures/write/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        if (body != null) 'sent': jsonDecode(scrub(jsonEncode(body))),
        'status': response.statusCode,
        'headers': {'content-type': ?response.headers.value('content-type')},
        'body': scrub(response.data ?? ''),
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    final data = response.data ?? '';
    return data.startsWith('{')
        ? jsonDecode(data) as Map<String, Object?>
        : const {};
  }

  Future<Map<String, Object?>> patch(
    String name,
    String path,
    Map<String, Object?> body,
  ) => capture(
    name,
    'PATCH',
    '/api/v2$path',
    body: body,
    contentType: _mergePatch,
  );

  final studio = await capture(
    'v1_project_create',
    'PUT',
    '/api/v1/projects',
    body: {'title': 'Studio', 'hex_color': 'e8b04a'},
  );
  final studioId = studio['id']! as int;
  final sketches = await capture(
    'v2_project_create',
    'POST',
    '/api/v2/projects',
    body: {
      'title': 'Sketches',
      'parent_project_id': studioId,
      'hex_color': '4a90e2',
    },
  );
  final sketchesId = sketches['id']! as int;
  await send('PUT', '/api/v1/projects/$studioId/tasks', {
    'title': 'Prime the canvas',
  });
  await send('PUT', '/api/v1/projects/$studioId/tasks', {
    'title': 'Buy brushes',
    'done': true,
  });

  final edit = {'title': 'Drafts', 'identifier': 'drf', 'hex_color': '00db60'};
  await patch('v2_project_update', '/projects/$sketchesId', edit);
  await patch('v2_project_update_unchanged', '/projects/$sketchesId', {
    'title': 'Drafts',
  });
  await capture(
    'v2_project_update_read',
    'GET',
    '/api/v2/projects/$sketchesId',
  );
  final v1Sketches = await capture(
    'v1_project_update_read',
    'GET',
    '/api/v1/projects/$sketchesId',
  );
  await capture(
    'v1_project_update',
    'POST',
    '/api/v1/projects/$sketchesId',
    body: {...v1Sketches, 'is_favorite': true},
  );
  await patch('v2_project_update_identifier_taken', '/projects/$studioId', {
    'identifier': 'DRF',
  });

  await patch('v2_project_archive', '/projects/$studioId', {
    'is_archived': true,
  });
  await patch('v2_project_update_archived', '/projects/$studioId', {
    'title': 'Atelier',
  });
  await patch('v2_project_unarchive_parent_archived', '/projects/$sketchesId', {
    'is_archived': false,
  });
  await capture(
    'v2_project_create_archived_parent',
    'POST',
    '/api/v2/projects',
    body: {'title': 'Studies', 'parent_project_id': studioId},
  );
  await patch('v2_project_unarchive', '/projects/$studioId', {
    'is_archived': false,
  });
  final me = await read('/api/v1/user');
  final defaultProjectId =
      (me['settings']! as Map<String, Object?>)['default_project_id']! as int;
  await patch('v2_project_archive_default', '/projects/$defaultProjectId', {
    'is_archived': true,
  });

  final v1Copy = await capture(
    'v1_project_duplicate',
    'PUT',
    '/api/v1/projects/$studioId/duplicate',
    body: {'parent_project_id': 0, 'duplicate_shares': false},
  );
  final v2Copy = await capture(
    'v2_project_duplicate',
    'POST',
    '/api/v2/projects/$studioId/duplicate',
    body: {'parent_project_id': studioId, 'duplicate_shares': true},
  );
  final v1CopyId =
      (v1Copy['duplicated_project']! as Map<String, Object?>)['id']! as int;
  final v2CopyId =
      (v2Copy['duplicated_project']! as Map<String, Object?>)['id']! as int;
  await capture('v1_project_delete', 'DELETE', '/api/v1/projects/$v1CopyId');
  await capture('v2_project_delete', 'DELETE', '/api/v2/projects/$v2CopyId');
  await capture(
    'v2_project_delete_unknown',
    'DELETE',
    '/api/v2/projects/$v2CopyId',
  );

  Map<String, Object?> filter(String text) => {
    'filter': text,
    's': '',
    'sort_by': <String>[],
    'order_by': <String>[],
    'filter_include_nulls': false,
  };
  final views = '/projects/$studioId/views';
  final open = await capture(
    'v1_view_create',
    'PUT',
    '/api/v1$views',
    body: {
      'title': 'Open',
      'view_kind': 'list',
      'filter': filter('done = false'),
    },
  );
  final openId = open['id']! as int;
  final board = await capture(
    'v2_view_create',
    'POST',
    '/api/v2$views',
    body: {'title': 'Board', 'view_kind': 'kanban', 'position': 150},
  );
  final boardId = board['id']! as int;
  for (final (name, text) in [
    ('v2_view_create_filter_syntax', '(('),
    ('v2_view_create_filter_value', 'priority >>= 1'),
    ('v2_view_create_filter_field', 'foo = 1'),
  ]) {
    await capture(
      name,
      'POST',
      '/api/v2$views',
      body: {'title': 'Broken', 'view_kind': 'list', 'filter': filter(text)},
    );
  }
  final openEdit = {
    'title': 'Urgent',
    'view_kind': 'list',
    'filter': filter('priority >= 3'),
    'position': 50,
  };
  await patch('v2_view_update', '$views/$openId', openEdit);
  await patch('v2_view_update_unchanged', '$views/$openId', openEdit);
  await capture('v2_view_update_read', 'GET', '/api/v2$views/$openId');
  final v1Board = await capture(
    'v1_view_update_read',
    'GET',
    '/api/v1$views/$boardId',
  );
  await capture(
    'v1_view_update',
    'POST',
    '/api/v1$views/$boardId',
    body: {
      ...v1Board,
      'title': 'Columns',
      'view_kind': 'kanban',
      'filter': filter('done = false'),
      'position': 175,
    },
  );
  await patch('v2_view_update_clear_filter', '$views/$openId', {
    'title': 'Urgent',
    'view_kind': 'list',
    'filter': null,
  });

  await capture('v1_view_delete', 'DELETE', '/api/v1$views/$boardId');
  await capture('v2_view_delete', 'DELETE', '/api/v2$views/$openId');
  await capture('v2_view_delete_unknown', 'DELETE', '/api/v2$views/$openId');

  final link =
      (await send('PUT', '/api/v1/projects/$studioId/shares', {'right': 1}))!
          as Map<String, Object?>;
  final linkJwt = await _linkShareJwt(dio, link['hash']! as String);
  secrets.add(linkJwt);
  await capture(
    'v2_view_create_not_admin',
    'POST',
    '/api/v2$views',
    body: {'title': 'Mine', 'view_kind': 'list'},
    jwt: linkJwt,
  );
  await capture(
    'v2_project_delete_not_admin',
    'DELETE',
    '/api/v2/projects/$studioId',
    jwt: linkJwt,
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

Future<String> _linkShareJwt(Dio dio, String hash) async {
  final auth = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/shares/$hash/auth',
      data: <String, Object?>{},
    ),
  );
  return (jsonDecode(auth.data!) as Map<String, Object?>)['token']! as String;
}

/// Waits out the shared limit of the unauthenticated routes.
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
  String jwt,
  String method,
  String path, {
  Object? body,
  String? contentType,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        contentType: contentType,
        headers: {'Authorization': 'Bearer $jwt'},
        validateStatus: (_) => true,
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
