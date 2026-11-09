// Records the saved filter reads and writes of step 24 into
// test/fixtures/write, with one throwaway user:
//   dart run tool/capture_saved_filter_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// "Urgent open" created by v1 with sort and include-nulls, "Today" by v2;
// both read on both versions; "Today" replaced by a v2 merge-patch, the same
// patch unchanged (304), favourited by a v2 merge-patch; "Urgent open"
// replaced and favourited by v1 full replaces after a read; four refused
// creates (unknown field, bad value, syntax, empty filter) on v2 and the
// empty one on v1; the project list naming both; an unknown id read; deletes
// on both versions and one twice. The request bodies are kept as `sent`.
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
  final serverVersion = args.elementAtOrNull(1) ?? '2.8.0';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
    ),
  );
  final user = await _register(dio, 'fixturesf');

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

  Map<String, Object?> filters(
    String filter, {
    bool includeNulls = false,
    List<String> sortBy = const [],
    List<String> orderBy = const [],
  }) => {
    'filter': filter,
    's': '',
    'sort_by': sortBy,
    'order_by': orderBy,
    'filter_include_nulls': includeNulls,
  };

  final urgent = await capture(
    'v1_saved_filter_create',
    'PUT',
    '/api/v1/filters',
    body: {
      'title': 'Urgent open',
      'description': 'Open and urgent',
      'filters': filters(
        'done = false && priority >= 3',
        includeNulls: true,
        sortBy: ['due_date'],
        orderBy: ['asc'],
      ),
      'is_favorite': false,
    },
  );
  final urgentId = urgent['id']! as int;
  final today = await capture(
    'v2_saved_filter_create',
    'POST',
    '/api/v2/filters',
    body: {
      'title': 'Today',
      'description': '',
      'filters': filters('due_date >= now/d && due_date < now/d+1d'),
      'is_favorite': false,
    },
  );
  final todayId = today['id']! as int;

  await capture('v1_saved_filter_read', 'GET', '/api/v1/filters/$urgentId');
  await capture('v2_saved_filter_read', 'GET', '/api/v2/filters/$todayId');

  final replacement = {
    'title': 'This week',
    'description': 'Due within the week',
    'filters': filters('due_date < now/w+1w', includeNulls: true),
    'is_favorite': false,
  };
  await capture(
    'v2_saved_filter_update',
    'PATCH',
    '/api/v2/filters/$todayId',
    body: replacement,
    contentType: _mergePatch,
  );
  await capture(
    'v2_saved_filter_update_unchanged',
    'PATCH',
    '/api/v2/filters/$todayId',
    body: replacement,
    contentType: _mergePatch,
  );
  await capture(
    'v2_saved_filter_favorite',
    'PATCH',
    '/api/v2/filters/$todayId',
    body: {'is_favorite': true},
    contentType: _mergePatch,
  );

  final v1Read = await capture(
    'v1_saved_filter_update_read',
    'GET',
    '/api/v1/filters/$urgentId',
  );
  await capture(
    'v1_saved_filter_update',
    'POST',
    '/api/v1/filters/$urgentId',
    body: {
      ...v1Read,
      'title': 'Urgent',
      'description': '',
      'filters': filters('priority >= 4'),
      'is_favorite': false,
    },
  );
  final v1Again = await capture(
    'v1_saved_filter_favorite_read',
    'GET',
    '/api/v1/filters/$urgentId',
  );
  await capture(
    'v1_saved_filter_favorite',
    'POST',
    '/api/v1/filters/$urgentId',
    body: {...v1Again, 'is_favorite': true},
  );

  for (final (name, filter) in [
    ('invalid_field', 'dueDate < now'),
    ('invalid_value', 'done = yes'),
    ('invalid_syntax', 'done = true &&'),
    ('empty', ''),
  ]) {
    await capture(
      'v2_saved_filter_create_$name',
      'POST',
      '/api/v2/filters',
      body: {'title': 'Refused', 'filters': filters(filter)},
    );
  }
  await capture(
    'v1_saved_filter_create_empty',
    'PUT',
    '/api/v1/filters',
    body: {
      'title': 'Refused',
      'filters': {'filter': ''},
    },
  );

  await capture('v2_projects_saved_filters', 'GET', '/api/v2/projects');
  await capture(
    'v2_saved_filter_read_unknown',
    'GET',
    '/api/v2/filters/999999',
  );

  await capture(
    'v1_saved_filter_delete',
    'DELETE',
    '/api/v1/filters/$urgentId',
  );
  await capture('v2_saved_filter_delete', 'DELETE', '/api/v2/filters/$todayId');
  await capture(
    'v2_saved_filter_delete_unknown',
    'DELETE',
    '/api/v2/filters/$todayId',
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
