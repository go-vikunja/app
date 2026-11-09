// Records the error answers of attachment previews on 2.7.1 and newer into
// test/fixtures/attachments, with one throwaway user:
//   dart run tool/capture_attachment_preview_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// A preview of a text file (v2 `…/preview?size=md`, v1 `?preview_size=md`)
// and a v2 preview of an unknown attachment. The previews themselves are
// binary and not recorded. The user is renamed `fixtureuser` and the email
// address replaced; no file may hold a token or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _keptHeaders = ['content-type', 'content-length'];

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
  final user = await _register(dio, 'fixturepv');

  String scrub(String body) {
    final scrubbed = body
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    if (scrubbed.contains('@example.com') || scrubbed.contains(user.jwt)) {
      throw StateError('a capture leaks an email or a token');
    }
    return scrubbed;
  }

  Future<void> capture(String name, String path) async {
    final response = await _send(dio, user.jwt, 'GET', path);
    final file = File('test/fixtures/attachments/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    final scrubbed = scrub(response.data ?? '');
    final lengthKept =
        response.headers.value('content-length') ==
        '${utf8.encode(scrubbed).length}';
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': 'GET $path',
        'status': response.statusCode,
        'headers': {
          for (final header in _keptHeaders)
            if (header != 'content-length' || lengthKept)
              header: ?response.headers.value(header),
        },
        'body': scrubbed,
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
  }

  Future<Map<String, Object?>> json(
    String method,
    String path,
    Object body,
  ) async {
    final response = await _send(dio, user.jwt, method, path, body: body);
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    return jsonDecode(response.data!) as Map<String, Object?>;
  }

  final project = await json('POST', '/api/v2/projects', {
    'title': 'Preview fixtures',
  });
  final task = await json('POST', '/api/v2/projects/${project['id']}/tasks', {
    'title': 'Previews',
  });
  final taskId = task['id']! as int;
  final uploaded = await json(
    'POST',
    '/api/v2/tasks/$taskId/attachments',
    FormData()
      ..files.add(
        MapEntry(
          'files',
          MultipartFile.fromString('No preview here.', filename: 'notes.txt'),
        ),
      ),
  );
  final textId =
      ((uploaded['success']! as List<Object?>).single!
          as Map<String, Object?>)['id'];

  await capture(
    'v2_preview_no_preview',
    '/api/v2/tasks/$taskId/attachments/$textId/preview?size=md',
  );
  await capture(
    'v1_preview_no_preview',
    '/api/v1/tasks/$taskId/attachments/$textId?preview_size=md',
  );
  await capture(
    'v2_preview_unknown',
    '/api/v2/tasks/$taskId/attachments/999999/preview?size=md',
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
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body is FormData && attempt > 1 ? body.clone() : body,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $jwt'},
        validateStatus: (_) => true,
      ),
    );
    if (method != 'GET') {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // The SQLite server answers a write that collides with another with a
    // 500 and changes nothing.
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
