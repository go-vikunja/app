// Records the attachment answers of step 26 into test/fixtures/attachments,
// with one throwaway user:
//   dart run tool/capture_attachment_fixtures.dart \
//     [http://localhost:34527] [2.7.0]
// On both versions: uploads of a PNG, a text file under a unicode name, an
// empty file, a file one byte above the 20 MiB limit (4012 inside a
// success), a part without a file name, a body above the request limit
// (413, when the server answers before it closes the connection) and one
// into an archived project; downloads of the text file, a range of it and
// an unknown attachment; deletes of an attachment, an unknown one and one in
// the archived project. On v2 the cover set by a merge-patch, a title-only
// patch refused once the cover attachment is deleted, and the same patch
// with the cover cleared; on v1 the full replace refused the same way.
// Downloads keep the headers a client reads. A multipart request is kept as
// `sent` {file name, length}. Writes are paced by half a second. The user
// is renamed `fixtureuser` and the email address replaced; no file may hold
// a token or a real address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _mergePatch = 'application/merge-patch+json';
const int _mebibyte = 1024 * 1024;
const _keptHeaders = [
  'content-type',
  'content-length',
  'content-disposition',
  'content-range',
  'accept-ranges',
  'last-modified',
];

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
  final user = await _register(dio, 'fixtureat');

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
    Object? sent,
    String? contentType,
    Map<String, String> headers = const {},
  }) async {
    final Response<String> response;
    try {
      response = await _send(
        dio,
        user.jwt,
        method,
        path,
        body: body,
        contentType: contentType,
        headers: headers,
      );
    } on DioException catch (error) {
      stdout.writeln('skipped $name: ${error.type} ${error.error}');
      return const {};
    }
    final file = File('test/fixtures/attachments/${name}_$serverVersion.json');
    await file.parent.create(recursive: true);
    final sentJson = sent ?? body;
    final scrubbed = scrub(response.data ?? '');
    // A scrubbed body no longer has the length the server sent.
    final lengthKept =
        response.headers.value('content-length') ==
        '${utf8.encode(scrubbed).length}';
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        if (headers.isNotEmpty) 'request_headers': headers,
        if (sentJson != null) 'sent': jsonDecode(scrub(jsonEncode(sentJson))),
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

  Future<Map<String, Object?>> upload(
    String name,
    String version,
    int taskId,
    String fileName,
    List<int> Function() bytes,
  ) {
    final length = bytes().length;
    return capture(
      name,
      version == 'v2' ? 'POST' : 'PUT',
      '/api/$version/tasks/$taskId/attachments',
      body: FormData()
        ..files.add(
          MapEntry(
            'files',
            MultipartFile.fromStream(
              () => Stream.value(bytes()),
              length,
              filename: fileName,
            ),
          ),
        ),
      sent: {'file_name': fileName, 'length': length},
    );
  }

  // A 1x1 PNG that Go's image package decodes.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );
  final project = await json(
    'POST',
    '/api/v2/projects',
    body: {'title': 'Attachment fixtures'},
  );
  final archived = await json(
    'POST',
    '/api/v2/projects',
    body: {'title': 'Archived attachments'},
  );
  final archivedTask = await json(
    'POST',
    '/api/v2/projects/${archived['id']}/tasks',
    body: {'title': 'In an archived project'},
  );
  final kept = await json(
    'POST',
    '/api/v2/tasks/${archivedTask['id']}/attachments',
    body: FormData()
      ..files.add(
        MapEntry('files', MultipartFile.fromString('kept', filename: 'k.txt')),
      ),
  );
  final keptId =
      ((kept['success']! as List<Object?>).single!
          as Map<String, Object?>)['id'];
  await json(
    'PATCH',
    '/api/v2/projects/${archived['id']}',
    body: {'is_archived': true},
    contentType: _mergePatch,
  );

  for (final version in ['v1', 'v2']) {
    final task = await json(
      'POST',
      '/api/v2/projects/${project['id']}/tasks',
      body: {'title': 'Attachments over $version'},
    );
    final taskId = task['id']! as int;
    final uploadedPng = await upload(
      '${version}_upload_png',
      version,
      taskId,
      'pixel.png',
      () => png,
    );
    final text = await upload(
      '${version}_upload_unicode',
      version,
      taskId,
      'Ünïcødé 日本 ü.txt',
      () => utf8.encode('Attachment fixture text.\n'),
    );
    await upload(
      '${version}_upload_empty',
      version,
      taskId,
      'empty.txt',
      () => const [],
    );
    await upload(
      '${version}_upload_too_large',
      version,
      taskId,
      'large.bin',
      () => List.filled(20 * _mebibyte + 1, 0),
    );
    await upload(
      '${version}_upload_no_file_name',
      version,
      taskId,
      '',
      () => utf8.encode('nameless'),
    );
    await upload(
      '${version}_upload_over_request_limit',
      version,
      taskId,
      'huge.bin',
      () => List.filled(23 * _mebibyte, 0),
    );
    await upload(
      '${version}_upload_archived',
      version,
      archivedTask['id']! as int,
      'archived.txt',
      () => utf8.encode('refused'),
    );

    final textId =
        ((text['success']! as List<Object?>).single!
            as Map<String, Object?>)['id'];
    await capture(
      '${version}_download_unicode',
      'GET',
      '/api/$version/tasks/$taskId/attachments/$textId',
    );
    await capture(
      '${version}_download_range',
      'GET',
      '/api/$version/tasks/$taskId/attachments/$textId',
      headers: {'Range': 'bytes=11-'},
    );
    await capture(
      '${version}_download_unknown',
      'GET',
      '/api/$version/tasks/$taskId/attachments/999999',
    );

    await capture(
      '${version}_delete',
      'DELETE',
      '/api/$version/tasks/$taskId/attachments/$textId',
    );
    await capture(
      '${version}_delete_unknown',
      'DELETE',
      '/api/$version/tasks/$taskId/attachments/$textId',
    );
    await capture(
      '${version}_delete_archived',
      'DELETE',
      '/api/$version/tasks/${archivedTask['id']}/attachments/$keptId',
    );

    final pngId =
        ((uploadedPng['success']! as List<Object?>).single!
            as Map<String, Object?>)['id'];
    switch (version) {
      case 'v2':
        await capture(
          'v2_cover_set',
          'PATCH',
          '/api/v2/tasks/$taskId',
          body: {'cover_image_attachment_id': pngId},
          contentType: _mergePatch,
        );
        await json('DELETE', '/api/v2/tasks/$taskId/attachments/$pngId');
        await capture(
          'v2_cover_dangling',
          'PATCH',
          '/api/v2/tasks/$taskId',
          body: {'title': 'Edited after the cover was deleted'},
          contentType: _mergePatch,
        );
        await capture(
          'v2_cover_cleared',
          'PATCH',
          '/api/v2/tasks/$taskId',
          body: {
            'title': 'Edited after the cover was deleted',
            'cover_image_attachment_id': 0,
          },
          contentType: _mergePatch,
        );
      case 'v1':
        final read = await json('GET', '/api/v1/tasks/$taskId');
        await json(
          'POST',
          '/api/v1/tasks/$taskId',
          body: {...read, 'cover_image_attachment_id': pngId},
        );
        await json('DELETE', '/api/v1/tasks/$taskId/attachments/$pngId');
        final stale = await json('GET', '/api/v1/tasks/$taskId');
        await capture(
          'v1_cover_dangling',
          'POST',
          '/api/v1/tasks/$taskId',
          body: {
            for (final MapEntry(:key, :value) in stale.entries)
              if (key != 'attachments') key: value,
            'title': 'Edited after the cover was deleted',
          },
        );
    }
  }

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
  Map<String, String> headers = const {},
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body is FormData && attempt > 1 ? body.clone() : body,
      options: Options(
        method: method,
        contentType: contentType,
        headers: {...headers, 'Authorization': 'Bearer $jwt'},
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
