// Records the trash answers of step 37f into test/fixtures/trash, with three
// throwaway users (owner, writer, reader) and a write link share:
//   dart run tool/capture_trash_fixtures.dart [http://localhost:34527] [2.8.0]
// Both lists empty. In Garden (the writer may write, the reader read) the
// owner deletes a task with a label, an assignee, a reminder, a relation
// and an attachment, the link share and the writer one task each: the task
// list as owner (whole and in pages of two), writer, reader and link share
// (refused), the counts as owner and writer. The rich task restored (as the
// reader refused, then again: already live) and an unknown one; the
// writer's task deleted for good (as the writer refused, then once more:
// gone), the live task refused. Shed with Tools and Screws below it: a task
// in Screws deleted, then Shed, and a project the writer administers
// deleted by the writer; the project list and count, the task restore and
// a task read refused while Shed is in the trash (the read goes to
// test/fixtures/errors), Tools refused, Shed restored (by the writer
// refused, then twice), the writer's project deleted for good twice. A task
// and a subproject of Archive deleted before it is archived: neither can be
// restored. The link share removed (its task loses its deleter), then the
// owner's own tasks emptied and all projects. Writes are paced by half a
// second. The users are renamed, emails replaced; the link share's hash and
// every password and token never appear.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({
  String username,
  String email,
  String password,
  String jwt,
  int id,
});

const _mergePatch = 'application/merge-patch+json';
final String _fakeHash = 'x' * 40;
final _hashPattern = RegExp('"hash":"([A-Za-z0-9]{40})"');
const _keptHeaders = ['content-type'];

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
  final owner = await _register(dio, 'trowner');
  final writer = await _register(dio, 'trwriter');
  final reader = await _register(dio, 'trreader');
  final secrets = <String>{
    for (final user in [owner, writer, reader]) ...[user.password, user.jwt],
  };
  final names = {
    for (final (user, fake) in [
      (owner, 'fixtureowner'),
      (writer, 'fixturewriter'),
      (reader, 'fixturereader'),
    ]) ...{
      user.username: fake,
      user.username.toUpperCase(): fake.toUpperCase(),
    },
  };

  String scrub(String text) {
    var scrubbed = text;
    for (final MapEntry(key: real, value: fake) in names.entries) {
      scrubbed = scrubbed
          .replaceAll('$real@example.com', '$fake@example.invalid')
          .replaceAll(real, fake);
    }
    for (final match in _hashPattern.allMatches(scrubbed)) {
      if (match[1] != _fakeHash) secrets.add(match[1]!);
    }
    scrubbed = scrubbed.replaceAllMapped(
      _hashPattern,
      (_) => '"hash":"$_fakeHash"',
    );
    final leaks =
        scrubbed.contains('@example.com') ||
        scrubbed.contains('"token"') ||
        secrets.any(scrubbed.contains);
    if (leaks) throw StateError('a capture leaks a secret or an email');
    return scrubbed;
  }

  Future<Response<String>> capture(
    String name,
    String method,
    String path, {
    String? as,
    String folder = 'trash',
  }) async {
    final response = await _send(dio, as ?? owner.jwt, method, path);
    final file = File('test/fixtures/$folder/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    final record = {
      'server': serverVersion,
      'request': scrub('$method $path'),
      'status': response.statusCode,
      'headers': {
        for (final header in _keptHeaders)
          header: ?response.headers.value(header),
      },
      'body': scrub(response.data ?? ''),
    };
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(record)}\n',
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    return response;
  }

  Future<Object?> raw(
    String method,
    String path, {
    Object? body,
    String? as,
    String? contentType,
  }) async {
    final response = await _send(
      dio,
      as ?? owner.jwt,
      method,
      path,
      body: body,
      contentType: contentType,
    );
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    final data = response.data ?? '';
    return data.trim().isEmpty ? null : jsonDecode(data);
  }

  int idOf(Object? json) => (json! as Map<String, Object?>)['id']! as int;

  Future<int> project(String title, {int? parent}) async => idOf(
    await raw(
      'POST',
      '/api/v2/projects',
      body: {'title': title, 'parent_project_id': ?parent},
    ),
  );

  Future<int> task(int projectId, Map<String, Object?> body) async =>
      idOf(await raw('POST', '/api/v2/projects/$projectId/tasks', body: body));

  Future<void> share(int projectId, _User user, int permission) => raw(
    'POST',
    '/api/v2/projects/$projectId/users',
    body: {'username': user.username, 'permission': permission},
  );

  const tasksPage = '/api/v2/tasks/deleted?page=1&per_page=50';
  const projectsPage = '/api/v2/projects/deleted?page=1&per_page=50';

  await capture('v2_tasks_deleted_none', 'GET', tasksPage);
  await capture('v2_projects_deleted_none', 'GET', projectsPage);

  // Garden, its link share and its tasks.
  final garden = await project('Fixture garden');
  await share(garden, writer, 1);
  await share(garden, reader, 0);
  final link =
      (await raw(
            'POST',
            '/api/v2/projects/$garden/shares',
            body: {'permission': 1, 'name': 'Fixture helper'},
          ))!
          as Map<String, Object?>;
  final linkHash = link['hash']! as String;
  secrets.add(linkHash);
  final linkJwt = await _linkShareJwt(dio, linkHash);
  secrets.add(linkJwt);
  final label = idOf(
    await raw(
      'POST',
      '/api/v2/labels',
      body: {'title': 'Fixture label', 'hex_color': '1973ff'},
    ),
  );
  final soil = await task(garden, {'title': 'Buy soil'});
  final plants = await task(garden, {
    'title': 'Water the plants',
    'description': '<p>Every pot</p>',
    'due_date': '2030-06-01T10:00:00Z',
    'priority': 3,
    'hex_color': 'e8445a',
    'reminders': [
      {'reminder': '2030-06-01T09:00:00Z'},
    ],
  });
  await raw('POST', '/api/v2/tasks/$plants/labels', body: {'label_id': label});
  await raw(
    'POST',
    '/api/v2/tasks/$plants/assignees',
    body: {'user_id': writer.id},
  );
  await raw(
    'POST',
    '/api/v2/tasks/$plants/relations',
    body: {'other_task_id': soil, 'relation_kind': 'related'},
  );
  await raw(
    'POST',
    '/api/v2/tasks/$plants/attachments',
    body: FormData()
      ..files.add(
        MapEntry(
          'files',
          MultipartFile.fromString('Fixture notes', filename: 'notes.txt'),
        ),
      ),
  );
  final leaves = await task(garden, {'title': 'Rake the leaves'});
  final lawn = await task(garden, {'title': 'Mow the lawn'});

  await raw('DELETE', '/api/v2/tasks/$plants');
  await raw('DELETE', '/api/v2/tasks/$leaves', as: linkJwt);
  await raw('DELETE', '/api/v2/tasks/$lawn', as: writer.jwt);

  await capture('v2_tasks_deleted', 'GET', tasksPage);
  for (final page in [1, 2]) {
    await capture(
      'v2_tasks_deleted_page_$page',
      'GET',
      '/api/v2/tasks/deleted?page=$page&per_page=2',
    );
  }
  await capture('v2_tasks_deleted_writer', 'GET', tasksPage, as: writer.jwt);
  await capture('v2_tasks_deleted_reader', 'GET', tasksPage, as: reader.jwt);
  await capture('v2_tasks_deleted_link_share', 'GET', tasksPage, as: linkJwt);
  await capture('v2_tasks_deleted_count', 'GET', '/api/v2/tasks/deleted/count');
  await capture(
    'v2_tasks_deleted_count_writer',
    'GET',
    '/api/v2/tasks/deleted/count',
    as: writer.jwt,
  );
  await capture(
    'v2_projects_deleted_count_writer',
    'GET',
    '/api/v2/projects/deleted/count',
    as: writer.jwt,
  );

  await capture(
    'v2_task_restore_reader',
    'POST',
    '/api/v2/tasks/$plants/restore',
    as: reader.jwt,
  );
  await capture('v2_task_restore', 'POST', '/api/v2/tasks/$plants/restore');
  await capture(
    'v2_task_restore_live',
    'POST',
    '/api/v2/tasks/$plants/restore',
  );
  await capture(
    'v2_task_restore_unknown',
    'POST',
    '/api/v2/tasks/99999999/restore',
  );
  await capture(
    'v2_task_permanent_writer',
    'DELETE',
    '/api/v2/tasks/$lawn/permanent',
    as: writer.jwt,
  );
  await capture('v2_task_permanent', 'DELETE', '/api/v2/tasks/$lawn/permanent');
  await capture(
    'v2_task_permanent_gone',
    'DELETE',
    '/api/v2/tasks/$lawn/permanent',
  );
  await capture(
    'v2_task_permanent_live',
    'DELETE',
    '/api/v2/tasks/$plants/permanent',
  );

  // Shed with Tools and Screws, and a project the writer administers.
  final shed = await project('Fixture shed');
  final tools = await project('Fixture tools', parent: shed);
  final screws = await project('Fixture screws', parent: tools);
  await share(shed, writer, 1);
  final sort = await task(screws, {'title': 'Sort the screws'});
  final nails = await task(screws, {'title': 'Count the nails'});
  final handedOver = await project('Fixture hand-over');
  await share(handedOver, writer, 2);

  await raw('DELETE', '/api/v2/tasks/$sort');
  await raw('DELETE', '/api/v2/projects/$shed');
  await raw('DELETE', '/api/v2/projects/$handedOver', as: writer.jwt);

  await capture('v2_projects_deleted', 'GET', projectsPage);
  await capture(
    'v2_projects_deleted_count',
    'GET',
    '/api/v2/projects/deleted/count',
  );
  await capture(
    'v2_task_restore_project_trashed',
    'POST',
    '/api/v2/tasks/$sort/restore',
  );
  await capture(
    'v2_404_task_project_trashed_root',
    'GET',
    '/api/v2/tasks/$nails',
    folder: 'errors',
  );
  await capture(
    'v2_project_restore_parent_trashed',
    'POST',
    '/api/v2/projects/$tools/restore',
  );
  await capture(
    'v2_project_restore_writer',
    'POST',
    '/api/v2/projects/$shed/restore',
    as: writer.jwt,
  );
  await capture('v2_project_restore', 'POST', '/api/v2/projects/$shed/restore');
  await capture(
    'v2_project_restore_live',
    'POST',
    '/api/v2/projects/$shed/restore',
  );
  await capture(
    'v2_project_permanent',
    'DELETE',
    '/api/v2/projects/$handedOver/permanent',
  );
  await capture(
    'v2_project_permanent_gone',
    'DELETE',
    '/api/v2/projects/$handedOver/permanent',
  );

  // Archive: a task and a subproject in the trash, then archived.
  final archive = await project('Fixture archive');
  final archivedChild = await project('Fixture old pots', parent: archive);
  final stored = await task(archive, {'title': 'Store the pots'});
  await raw('DELETE', '/api/v2/tasks/$stored');
  await raw('DELETE', '/api/v2/projects/$archivedChild');
  await raw(
    'PATCH',
    '/api/v2/projects/$archive',
    body: {'is_archived': true},
    contentType: _mergePatch,
  );
  await capture(
    'v2_task_restore_archived',
    'POST',
    '/api/v2/tasks/$stored/restore',
  );
  await capture(
    'v2_project_restore_parent_archived',
    'POST',
    '/api/v2/projects/$archivedChild/restore',
  );

  // The link share removed: the server no longer names who deleted its
  // task.
  await raw('DELETE', '/api/v2/projects/$garden/shares/${idOf(link)}');
  await capture('v2_tasks_deleted_deleter_gone', 'GET', tasksPage);
  await capture(
    'v2_tasks_empty_own',
    'DELETE',
    '/api/v2/tasks/deleted?include_others=false',
  );
  await capture('v2_tasks_deleted_after_empty_own', 'GET', tasksPage);
  await capture(
    'v2_projects_empty',
    'DELETE',
    '/api/v2/projects/deleted?include_others=true',
  );
  await capture('v2_projects_deleted_after_empty', 'GET', projectsPage);

  dio.close();
}

Future<_User> _register(Dio dio, String prefix) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = '$prefix$suffix';
  final email = '$username@example.com';
  final password = 'password-$suffix-${Random.secure().nextInt(1 << 32)}';
  final registered = await _unauthenticated(
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
    password: password,
    jwt: (jsonDecode(login.data!) as Map<String, Object?>)['token']! as String,
    id: (jsonDecode(registered.data!) as Map<String, Object?>)['id']! as int,
  );
}

Future<String> _linkShareJwt(Dio dio, String hash) async {
  final response = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/shares/$hash/auth',
      data: const <String, Object?>{},
    ),
  );
  return (jsonDecode(response.data!) as Map<String, Object?>)['token']!
      as String;
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
      data: body is FormData && attempt > 1 ? body.clone() : body,
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
