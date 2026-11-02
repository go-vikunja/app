// Records the user settings and avatar answers of step 30 into
// test/fixtures/user_settings, with one throwaway user:
//   dart run tool/capture_user_settings_fixtures.dart \
//     [http://localhost:34527] [2.7.1]
// The user first gets frontend keys another client wrote (a sound switch, a
// sidebar width, a key no client knows) and a date display. Then: a v2
// merge-patch of changed fields with a frontend key cleared, the same patch
// unchanged (304), a v2 full PUT and a v1 full POST each built from a fresh
// read, every read in between; refused writes on both versions (timezone
// 1025, week start, reminder time 2002, archived default project 3017);
// the avatar provider read, set and refused (1018) on both versions;
// avatar uploads on both versions of a PNG, of text and of a 60 megapixel
// PNG (4032), and the provider and the user read after them. A multipart
// request is kept as `sent` {file name, length}. Writes are paced by half a
// second. The user is renamed `fixtureuser`; no file may hold a token or an
// email address.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef _User = ({String username, String email, String jwt});

const _mergePatch = 'application/merge-patch+json';
const _general = '/user/settings/general';

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
  final user = await _register(dio, 'fixtureus');

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
  }) async {
    final response = await _send(
      dio,
      user.jwt,
      method,
      path,
      body: body,
      contentType: contentType,
    );
    final file = File(
      'test/fixtures/user_settings/${name}_$serverVersion.json',
    );
    await file.parent.create(recursive: true);
    final sentJson = sent ?? body;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        if (sentJson != null) 'sent': jsonDecode(scrub(jsonEncode(sentJson))),
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

  Map<String, Object?> settingsOf(Map<String, Object?> user) => {
    for (final MapEntry(:key, :value)
        in (user['settings']! as Map<String, Object?>).entries)
      if (key != r'$schema' && key != 'extra_settings_links') key: value,
  };

  Map<String, Object?> frontendOf(Map<String, Object?> settings) => {
    ...?settings['frontend_settings'] as Map<String, Object?>?,
  };

  Future<void> upload(
    String name,
    String version,
    String fileName,
    List<int> bytes,
  ) => capture(
    name,
    'PUT',
    version == 'v2'
        ? '/api/v2/user/settings/avatar'
        : '/api/v1/user/settings/avatar/upload',
    body: FormData()
      ..files.add(
        MapEntry('avatar', MultipartFile.fromBytes(bytes, filename: fileName)),
      ),
    sent: {'file_name': fileName, 'length': bytes.length},
  );

  await capture('v2_user_new', 'GET', '/api/v2/user');
  await json(
    'PATCH',
    '/api/v2$_general',
    body: {
      'frontend_settings': {
        'play_sound_when_done': false,
        'sidebar_width': 320,
        'rurana_unknown_key': {
          'nested': [1, 2],
        },
        'date_display': 'yyyy-mm-dd',
        'color_schema': 'dark',
      },
    },
    contentType: _mergePatch,
  );
  await capture('v2_user', 'GET', '/api/v2/user');
  await capture('v1_user', 'GET', '/api/v1/user');

  final patch = {
    'name': 'Dora',
    'discoverable_by_name': true,
    'overdue_tasks_reminders_time': '18:30',
    'week_start': 1,
    'frontend_settings': {'date_display': null, 'minimum_priority': 4},
  };
  await capture(
    'v2_patch',
    'PATCH',
    '/api/v2$_general',
    body: patch,
    contentType: _mergePatch,
  );
  await capture(
    'v2_patch_unchanged',
    'PATCH',
    '/api/v2$_general',
    body: patch,
    contentType: _mergePatch,
  );
  await capture('v2_user_after_patch', 'GET', '/api/v2/user');

  final beforePut = await capture('v2_user_before_put', 'GET', '/api/v2/user');
  final putSettings = settingsOf(beforePut);
  await capture(
    'v2_put',
    'PUT',
    '/api/v2$_general',
    body: {
      ...putSettings,
      'timezone': 'Europe/Berlin',
      'email_reminders_enabled': true,
      'frontend_settings': {
        ...frontendOf(putSettings),
        'default_view': 'kanban',
        'time_format': '12h',
      },
    },
  );
  await capture('v2_user_after_put', 'GET', '/api/v2/user');

  final beforePost = await capture(
    'v1_user_before_post',
    'GET',
    '/api/v1/user',
  );
  final postSettings = settingsOf(beforePost);
  await capture(
    'v1_post',
    'POST',
    '/api/v1$_general',
    body: {
      ...postSettings,
      'name': 'Dora Explorer',
      'discoverable_by_email': true,
      'frontend_settings': {
        ...frontendOf(postSettings),
        'quick_add_magic_mode': 'todoist',
        'quick_add_default_reminders': [
          {'relative_period': -3600, 'relative_to': 'due_date'},
        ],
      },
    },
  );
  await capture('v1_user_after_post', 'GET', '/api/v1/user');

  final project = await json(
    'POST',
    '/api/v2/projects',
    body: {'title': 'Archived default'},
  );
  final archivedId = project['id']! as int;
  await json(
    'PATCH',
    '/api/v2/projects/$archivedId',
    body: {'is_archived': true},
    contentType: _mergePatch,
  );

  for (final (name, body) in <(String, Map<String, Object?>)>[
    ('timezone', {'timezone': 'Mars/Phobos'}),
    ('week_start', {'week_start': 7}),
    ('overdue_time', {'overdue_tasks_reminders_time': '25:00'}),
    ('default_project_archived', {'default_project_id': archivedId}),
  ]) {
    await capture(
      'v2_patch_$name',
      'PATCH',
      '/api/v2$_general',
      body: body,
      contentType: _mergePatch,
    );
  }
  final refusedBase = settingsOf(await json('GET', '/api/v1/user'));
  for (final (name, body) in <(String, Map<String, Object?>)>[
    ('timezone', {'timezone': 'Mars/Phobos'}),
    ('week_start', {'week_start': 7}),
    ('overdue_time', {'overdue_tasks_reminders_time': '25:00'}),
    ('default_project_archived', {'default_project_id': archivedId}),
  ]) {
    await capture(
      'v1_post_$name',
      'POST',
      '/api/v1$_general',
      body: {...refusedBase, ...body},
    );
  }

  await capture(
    'v2_avatar_provider',
    'GET',
    '/api/v2/user/settings/avatar/provider',
  );
  await capture('v1_avatar_provider', 'GET', '/api/v1/user/settings/avatar');
  await capture(
    'v2_avatar_provider_set',
    'PUT',
    '/api/v2/user/settings/avatar/provider',
    body: {'avatar_provider': 'marble'},
  );
  await capture(
    'v1_avatar_provider_set',
    'POST',
    '/api/v1/user/settings/avatar',
    body: {'avatar_provider': 'gravatar'},
  );
  await capture(
    'v2_avatar_provider_invalid',
    'PUT',
    '/api/v2/user/settings/avatar/provider',
    body: {'avatar_provider': 'robohash'},
  );
  await capture(
    'v1_avatar_provider_invalid',
    'POST',
    '/api/v1/user/settings/avatar',
    body: {'avatar_provider': 'robohash'},
  );

  final square = _png(64, 64, (x, y) => (x * 4) ^ (y * 4));
  final text = utf8.encode('not an image\n');
  final tooManyPixels = _png(10000, 6000, (_, _) => 0);
  await upload('v2_avatar_upload', 'v2', 'avatar.png', square);
  await capture(
    'v2_avatar_provider_after_upload',
    'GET',
    '/api/v2/user/settings/avatar/provider',
  );
  await upload('v1_avatar_upload', 'v1', 'avatar.png', square);
  await upload('v2_avatar_upload_not_image', 'v2', 'avatar.txt', text);
  await upload('v1_avatar_upload_not_image', 'v1', 'avatar.txt', text);
  await upload(
    'v2_avatar_upload_too_many_pixels',
    'v2',
    'huge.png',
    tooManyPixels,
  );
  await upload(
    'v1_avatar_upload_too_many_pixels',
    'v1',
    'huge.png',
    tooManyPixels,
  );
  await capture('v2_user_after_upload', 'GET', '/api/v2/user');

  dio.close();
}

/// An 8-bit greyscale PNG.
Uint8List _png(int width, int height, int Function(int x, int y) grey) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y++) {
    final row = Uint8List(width + 1);
    for (var x = 0; x < width; x++) {
      row[x + 1] = grey(x, y) & 0xff;
    }
    raw.add(row);
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8);
  return (BytesBuilder(copy: false)
        ..add(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', zlib.encode(raw.takeBytes())))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

Uint8List _chunk(String type, List<int> data) {
  final typed = [...ascii.encode(type), ...data];
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(typed));
  return Uint8List.fromList([
    ...length.buffer.asUint8List(),
    ...typed,
    ...crc.buffer.asUint8List(),
  ]);
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
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
    // handlers with a 500 and changes nothing. An avatar upload never
    // collides, so its 500 is kept.
    if (response.statusCode == 500 && body is! FormData && attempt < 8) {
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
