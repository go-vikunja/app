// Records the comment and reaction answers of step 27 into
// test/fixtures/write, with one throwaway user:
//   dart run tool/capture_comment_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// On both versions: a comment created with a mention, an empty one, one on
// a task that does not exist and one in an archived project; an update (v1:
// the read before it and the echo; v2: a merge-patch, the same patch again)
// and one of a comment that does not exist; the read of a missing comment;
// an update and a delete in the archived project; a delete and a repeated
// one. Reactions to the task and to the comment, the same one again, its
// removal, the removal of one never added, an empty value, 21 code points
// (added and removed), a missing comment and task, and one in the archived
// project. Writes are
// paced by half a second. The user is renamed `fixtureuser` and the email
// address replaced; no file may hold a token or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _mergePatch = 'application/merge-patch+json';
const _missing = 999999999;

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
  final user = await _register(dio, 'fixturecm');

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    if (scrubbed.contains('@example.com') || scrubbed.contains(user.jwt)) {
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
  }) async {
    final response = await _send(
      dio,
      user.jwt,
      method,
      path,
      body: body,
      contentType: contentType,
    );
    final file = File('test/fixtures/write/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    final scrubbed = scrub(response.data ?? '');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        if (body != null) 'sent': jsonDecode(scrub(jsonEncode(body))),
        'status': response.statusCode,
        'headers': {'content-type': ?response.headers.value('content-type')},
        'body': scrubbed,
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    final data = response.data ?? '';
    return data.startsWith('{')
        ? jsonDecode(data) as Map<String, Object?>
        : const {};
  }

  Future<Map<String, Object?>> json(
    String method,
    String path, {
    Object? body,
    String? contentType,
  }) async {
    final response = await _send(
      dio,
      user.jwt,
      method,
      path,
      body: body,
      contentType: contentType,
    );
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    final data = response.data ?? '';
    return data.isEmpty ? const {} : jsonDecode(data) as Map<String, Object?>;
  }

  final mention =
      '<mention-user data-id="${user.username}" data-label="Fixture User" '
      'data-mention-suggestion-char="@"></mention-user>';
  final project = await json(
    'POST',
    '/api/v2/projects',
    body: {'title': 'Comment fixtures'},
  );
  final task = await json(
    'POST',
    '/api/v2/projects/${project['id']}/tasks',
    body: {'title': 'Commented'},
  );
  final taskId = task['id']! as int;
  final archived = await json(
    'POST',
    '/api/v2/projects',
    body: {'title': 'Archived comments'},
  );
  final archivedTask = await json(
    'POST',
    '/api/v2/projects/${archived['id']}/tasks',
    body: {'title': 'In an archived project'},
  );
  final archivedTaskId = archivedTask['id']! as int;
  final archivedComment = await json(
    'POST',
    '/api/v2/tasks/$archivedTaskId/comments',
    body: {'comment': '<p>before archiving</p>'},
  );
  await json(
    'PATCH',
    '/api/v2/projects/${archived['id']}',
    body: {'is_archived': true},
    contentType: _mergePatch,
  );

  for (final version in ['v1', 'v2']) {
    final create = version == 'v2' ? 'POST' : 'PUT';
    final api = '/api/$version';
    final created = await capture(
      '${version}_comment_create',
      create,
      '$api/tasks/$taskId/comments',
      body: {'comment': '<p>Hello $mention, from $version</p>'},
    );
    final commentId = created['id']! as int;
    await capture(
      '${version}_comment_create_empty',
      create,
      '$api/tasks/$taskId/comments',
      body: {'comment': ''},
    );
    await capture(
      '${version}_comment_create_unknown_task',
      create,
      '$api/tasks/$_missing/comments',
      body: {'comment': '<p>x</p>'},
    );
    await capture(
      '${version}_comment_create_archived',
      create,
      '$api/tasks/$archivedTaskId/comments',
      body: {'comment': '<p>x</p>'},
    );
    final edited = {'comment': '<p>Edited on $version</p>'};
    if (version == 'v1') {
      await capture(
        'v1_comment_read',
        'GET',
        '$api/tasks/$taskId/comments/$commentId',
      );
      await capture(
        'v1_comment_update',
        'POST',
        '$api/tasks/$taskId/comments/$commentId',
        body: edited,
      );
      await capture(
        'v1_comment_update_archived',
        'POST',
        '$api/tasks/$archivedTaskId/comments/${archivedComment['id']}',
        body: edited,
      );
    } else {
      await capture(
        'v2_comment_patch',
        'PATCH',
        '$api/tasks/$taskId/comments/$commentId',
        body: edited,
        contentType: _mergePatch,
      );
      await capture(
        'v2_comment_patch_unchanged',
        'PATCH',
        '$api/tasks/$taskId/comments/$commentId',
        body: edited,
        contentType: _mergePatch,
      );
      await capture(
        'v2_comment_read',
        'GET',
        '$api/tasks/$taskId/comments/$commentId',
      );
      await capture(
        'v2_comment_patch_unknown',
        'PATCH',
        '$api/tasks/$taskId/comments/$_missing',
        body: edited,
        contentType: _mergePatch,
      );
      await capture(
        'v2_comment_patch_archived',
        'PATCH',
        '$api/tasks/$archivedTaskId/comments/${archivedComment['id']}',
        body: edited,
        contentType: _mergePatch,
      );
    }
    await capture(
      '${version}_comment_read_unknown',
      'GET',
      '$api/tasks/$taskId/comments/$_missing',
    );

    final reactions = '$api/tasks/$taskId/reactions';
    await capture(
      '${version}_reaction_add_task',
      create,
      reactions,
      body: {'value': '👍'},
    );
    await capture(
      '${version}_reaction_add_task_again',
      create,
      reactions,
      body: {'value': '👍'},
    );
    await capture(
      '${version}_reaction_add_comment',
      create,
      '$api/comments/$commentId/reactions',
      body: {'value': '🎉'},
    );
    await capture(
      '${version}_reaction_remove_task',
      'POST',
      '$reactions/delete',
      body: {'value': '👍'},
    );
    await capture(
      '${version}_reaction_remove_absent',
      'POST',
      '$reactions/delete',
      body: {'value': '🚀'},
    );
    await capture(
      '${version}_reaction_add_empty',
      create,
      reactions,
      body: {'value': ''},
    );
    await capture(
      '${version}_reaction_add_21',
      create,
      reactions,
      body: {'value': '😀' * 21},
    );
    // v1 stores it; whether v2 takes it back is worth a capture.
    await capture(
      '${version}_reaction_remove_21',
      'POST',
      '$reactions/delete',
      body: {'value': '😀' * 21},
    );
    await capture(
      '${version}_reaction_add_unknown_comment',
      create,
      '$api/comments/$_missing/reactions',
      body: {'value': '👍'},
    );
    await capture(
      '${version}_reaction_add_unknown_task',
      create,
      '$api/tasks/$_missing/reactions',
      body: {'value': '👍'},
    );
    await capture(
      '${version}_reaction_add_archived',
      create,
      '$api/tasks/$archivedTaskId/reactions',
      body: {'value': '👍'},
    );

    await capture(
      '${version}_comment_delete_archived',
      'DELETE',
      '$api/tasks/$archivedTaskId/comments/${archivedComment['id']}',
    );
    await capture(
      '${version}_comment_delete',
      'DELETE',
      '$api/tasks/$taskId/comments/$commentId',
    );
    await capture(
      '${version}_comment_delete_unknown',
      'DELETE',
      '$api/tasks/$taskId/comments/$commentId',
    );
  }
  dio.close(force: true);
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
