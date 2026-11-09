// Records list position writes and project moves into test/fixtures/write,
// with two throwaway users:
//   dart run tool/capture_ordering_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// Project Ordering (colour, identifier, description, a favourite) with a
// list view and two tasks, Elsewhere with its own list view, the child
// Child (colour, identifier, description) with the grandchild Grandchild,
// and the archived Attic. Captured: list positions (v1, v2, an unknown
// view, another project's view), the child read and moved under Elsewhere
// by a v1 full replace, read and moved back by a v2 merge-patch, the same
// patch unchanged (304), and the refusals: itself, its grandchild, Attic, the
// Favorites pseudo project or an unknown project as the parent, an unknown
// project, a v1 cycle, and a second user with write permission moving the
// child to the top level or with read permission reordering Elsewhere.
// Every position sent is far above 0.1: below it the server renumbers all
// siblings, at the top level those of every user. Writes are paced by half
// a second. The users are renamed `fixtureuser` and their email addresses
// replaced; no file may hold a token or a real address.
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
  final owner = await _register(dio, 'fixtureown');
  final guest = await _register(dio, 'fixtureguest');

  Future<Response<String>> request(
    String method,
    String path, {
    Object? body,
    String? contentType,
    _User? as,
  }) => _send(
    dio,
    as ?? owner,
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

  Future<Map<String, Object?>> create(String path, Object body) async =>
      (await send('PUT', path, body))! as Map<String, Object?>;

  Future<int> listViewOf(int projectId) async {
    final views =
        (await send('GET', '/api/v1/projects/$projectId/views'))!
            as List<Object?>;
    return views.cast<Map<String, Object?>>().firstWhere(
          (view) => view['view_kind'] == 'list',
        )['id']!
        as int;
  }

  final ordering = await create('/api/v1/projects', {
    'title': 'Ordering',
    'hex_color': 'e8b04a',
    'identifier': 'ORD',
    'description': '<p>Keep me</p>',
  });
  final orderingId = ordering['id']! as int;
  await send('POST', '/api/v1/projects/$orderingId', {
    ...ordering,
    'is_favorite': true,
  });
  final elsewhere = await create('/api/v1/projects', {'title': 'Elsewhere'});
  final elsewhereId = elsewhere['id']! as int;
  final child = await create('/api/v1/projects', {
    'title': 'Child',
    'parent_project_id': orderingId,
    'hex_color': '4a90e2',
    'identifier': 'CHI',
    'description': '<p>Nested</p>',
  });
  final childId = child['id']! as int;
  final grandchild = await create('/api/v1/projects', {
    'title': 'Grandchild',
    'parent_project_id': childId,
  });
  final grandchildId = grandchild['id']! as int;
  final attic = await create('/api/v1/projects', {'title': 'Attic'});
  final atticId = attic['id']! as int;
  await send('POST', '/api/v1/projects/$atticId', {
    ...attic,
    'is_archived': true,
  });

  final listId = await listViewOf(orderingId);
  final elsewhereListId = await listViewOf(elsewhereId);
  final water = await create('/api/v1/projects/$orderingId/tasks', {
    'title': 'Water the plants',
  });
  final milk = await create('/api/v1/projects/$orderingId/tasks', {
    'title': 'Buy milk',
  });
  final waterId = water['id']! as int;
  final milkId = milk['id']! as int;

  final emails = {owner.email, guest.email};
  final usernames = {owner.username, guest.username};
  String scrub(String body) {
    var scrubbed = body;
    for (final email in emails) {
      scrubbed = scrubbed.replaceAll(email, 'fixtureuser@example.invalid');
    }
    for (final username in usernames) {
      scrubbed = scrubbed.replaceAll(username, 'fixtureuser');
    }
    if (scrubbed.contains('@example.com') ||
        scrubbed.contains(owner.jwt) ||
        scrubbed.contains(guest.jwt)) {
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
    _User? as,
  }) async {
    final response = await request(
      method,
      path,
      body: body,
      contentType: contentType,
      as: as,
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

  await capture(
    'v1_list_position',
    'POST',
    '/api/v1/tasks/$waterId/position',
    body: {'project_view_id': listId, 'position': 1500.5},
  );
  await capture(
    'v2_list_position',
    'PUT',
    '/api/v2/tasks/$milkId/position',
    body: {'project_view_id': listId, 'position': 3000},
  );
  await capture(
    'v1_list_position_unknown_view',
    'POST',
    '/api/v1/tasks/$waterId/position',
    body: {'project_view_id': 999999999, 'position': 5},
  );
  await capture(
    'v2_list_position_unknown_view',
    'PUT',
    '/api/v2/tasks/$waterId/position',
    body: {'project_view_id': 999999999, 'position': 5},
  );
  await capture(
    'v2_list_position_foreign_view',
    'PUT',
    '/api/v2/tasks/$waterId/position',
    body: {'project_view_id': elsewhereListId, 'position': 5},
  );

  final v1Child = jsonDecode(
    await capture('v1_project', 'GET', '/api/v1/projects/$childId'),
  ) as Map<String, Object?>;
  await capture(
    'v1_project_move',
    'POST',
    '/api/v1/projects/$childId',
    body: {...v1Child, 'position': 2500.5, 'parent_project_id': elsewhereId},
  );
  await capture('v2_project', 'GET', '/api/v2/projects/$childId');
  final backUnderOrdering = {
    'position': 3000.25,
    'parent_project_id': orderingId,
  };
  await capture(
    'v2_project_move',
    'PATCH',
    '/api/v2/projects/$childId',
    body: backUnderOrdering,
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_move_unchanged',
    'PATCH',
    '/api/v2/projects/$childId',
    body: backUnderOrdering,
    contentType: _mergePatch,
  );

  final orderingPosition = (ordering['position']! as num).toDouble();
  await capture(
    'v2_project_move_own_parent',
    'PATCH',
    '/api/v2/projects/$orderingId',
    body: {'position': orderingPosition, 'parent_project_id': orderingId},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_move_cycle',
    'PATCH',
    '/api/v2/projects/$orderingId',
    body: {'position': orderingPosition, 'parent_project_id': grandchildId},
    contentType: _mergePatch,
  );
  final v1Ordering =
      (await send('GET', '/api/v1/projects/$orderingId'))!
          as Map<String, Object?>;
  await capture(
    'v1_project_move_cycle',
    'POST',
    '/api/v1/projects/$orderingId',
    body: {...v1Ordering, 'parent_project_id': grandchildId},
  );
  await capture(
    'v2_project_move_archived_parent',
    'PATCH',
    '/api/v2/projects/$childId',
    body: {'position': 3000.25, 'parent_project_id': atticId},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_move_pseudo_parent',
    'PATCH',
    '/api/v2/projects/$childId',
    body: {'position': 3000.25, 'parent_project_id': -1},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_move_unknown_parent',
    'PATCH',
    '/api/v2/projects/$childId',
    body: {'position': 3000.25, 'parent_project_id': 999999999},
    contentType: _mergePatch,
  );
  await capture(
    'v2_project_move_unknown',
    'PATCH',
    '/api/v2/projects/999999999',
    body: {'position': 3000.25, 'parent_project_id': 0},
    contentType: _mergePatch,
  );

  await send('PUT', '/api/v1/projects/$orderingId/users', {
    'username': guest.username,
    'permission': 1,
  });
  await send('PUT', '/api/v1/projects/$elsewhereId/users', {
    'username': guest.username,
    'permission': 0,
  });
  await capture(
    'v2_project_move_not_admin',
    'PATCH',
    '/api/v2/projects/$childId',
    body: {'position': 99999999, 'parent_project_id': 0},
    contentType: _mergePatch,
    as: guest,
  );
  final elsewherePosition = (elsewhere['position']! as num).toDouble();
  await capture(
    'v2_project_move_read_only',
    'PATCH',
    '/api/v2/projects/$elsewhereId',
    body: {'position': elsewherePosition + 1, 'parent_project_id': 0},
    contentType: _mergePatch,
    as: guest,
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
