// Records the answers of step 32 into test/fixtures/link_share and
// test/fixtures/invites, with one throwaway owner:
//   dart run tool/capture_link_share_fixtures.dart [http://localhost:34527] [2.7.0]
// The owner shares a project read-only by a link named "Fixture guest" and
// for writing by a link with a password. Recorded on both API versions: the
// link share sign-in (open, password missing, wrong, right, unknown link),
// the renewal of a guest token (also with the owner's token and with no JWT
// at all), and, after the read link is deleted, what its token gets: the
// project list and the renewal. And the check of an invite that does not
// exist. Sign-in, registration, the link share sign-in and the invite check
// share a limit of 10 requests per minute and IP, so these are spaced by
// 7 s and wait out a 429.
//
// No file may hold a secret: hashes become 40 `x`, every JWT the placeholder
// `eyJ_placeholder_not_a_jwt` (a token's claims are kept beside the body as
// `token_claims`, with the hash claim replaced), passwords `<password>`,
// the invite token `<token>`; the owner is renamed. The tool fails before
// writing a file that still holds one.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

const _jwtPlaceholder = 'eyJ_placeholder_not_a_jwt';
const _unauthenticatedSpacing = Duration(seconds: 7);
final String _fakeHash = 'x' * 40;
final _jwtPattern = RegExp(
  r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',
);
const _keptHeaders = ['content-type', 'retry-after'];

Future<void> main(List<String> args) async {
  final root = args.elementAtOrNull(0) ?? 'http://localhost:34527';
  final serverVersion = args.elementAtOrNull(1) ?? '2.7.0';
  final dio = Dio(
    BaseOptions(
      baseUrl: root,
      headers: {'User-Agent': 'Rurana fixture capture'},
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  final spacer = _Spacer();
  final owner = await _register(dio, spacer);
  final linkPassword = 'link-${_randomWord(12)}';
  final secrets = <String>{owner.password, owner.jwt, linkPassword};

  String scrub(String text) {
    var scrubbed = text
        .replaceAll(
          '${owner.username}@example.com',
          'fixtureowner@example.invalid',
        )
        .replaceAll(owner.username, 'fixtureowner');
    for (final hash in secrets.where((secret) => secret.length == 40)) {
      scrubbed = scrubbed.replaceAll(hash, _fakeHash);
    }
    scrubbed = scrubbed.replaceAll(_jwtPattern, _jwtPlaceholder);
    final leaks =
        scrubbed.contains('@example.com') ||
        secrets.any(scrubbed.contains) ||
        scrubbed.replaceAll(_jwtPlaceholder, '').contains('eyJ');
    if (leaks) throw StateError('a capture leaks a secret or an email');
    return scrubbed;
  }

  Map<String, Object?>? claimsOf(String body) {
    final jwt = switch (_decode(body)) {
      {'token': final String jwt} => jwt,
      _ => null,
    };
    if (jwt == null) return null;
    secrets.add(jwt);
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[1]))),
    ) as Map<String, Object?>;
    return {
      for (final MapEntry(:key, :value) in payload.entries)
        key: key == 'hash' ? _fakeHash : value,
    };
  }

  Future<Response<String>> capture(
    String file,
    String method,
    String path, {
    Map<String, Object?>? body,
    String? bearer,
    bool unauthenticated = false,
  }) async {
    if (unauthenticated) await spacer.wait();
    final response = await _send(dio, method, path, body: body, bearer: bearer);
    final target = File('test/fixtures/${file}_$serverVersion.json');
    await target.parent.create(recursive: true);
    final data = response.data ?? '';
    final claims = response.statusCode == 200 ? claimsOf(data) : null;
    final record = {
      'server': serverVersion,
      'request': scrub('$method $path'),
      if (body != null)
        'sent': {
          for (final MapEntry(:key, :value) in body.entries)
            key: switch (key) {
              'password' => '<password>',
              'token' => '<token>',
              _ => value,
            },
        },
      'status': response.statusCode,
      'headers': {
        for (final header in _keptHeaders)
          header: ?response.headers.value(header),
      },
      'body': scrub(data),
      'token_claims': ?claims,
    };
    await target.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(record)}\n',
    );
    stdout.writeln('wrote ${target.path} (${response.statusCode})');
    return response;
  }

  Future<Map<String, Object?>> owned(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(
      dio,
      method,
      path,
      body: body,
      bearer: owner.jwt,
    );
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    return _decode(response.data ?? '{}') ?? const {};
  }

  final project = await owned(
    'PUT',
    '/api/v1/projects',
    body: {'title': 'Fixture shared project'},
  );
  final projectId = project['id']! as int;
  final readShare = await owned(
    'PUT',
    '/api/v1/projects/$projectId/shares',
    body: {'permission': 0, 'name': 'Fixture guest'},
  );
  final writeShare = await owned(
    'PUT',
    '/api/v1/projects/$projectId/shares',
    body: {'permission': 1, 'sharing_type': 2, 'password': linkPassword},
  );
  final readHash = readShare['hash']! as String;
  final writeHash = writeShare['hash']! as String;
  final unknownHash = _randomWord(40);
  secrets.addAll([readHash, writeHash, unknownHash]);

  String? readToken;
  try {
    for (final version in ['v1', 'v2']) {
      final open = await capture(
        'link_share/${version}_auth_open',
        'POST',
        '/api/$version/shares/$readHash/auth',
        body: version == 'v1' ? const {} : null,
        unauthenticated: true,
      );
      readToken ??= switch (_decode(open.data ?? '')) {
        {'token': final String jwt} => jwt,
        _ => null,
      };
      await capture(
        'link_share/${version}_auth_password_missing',
        'POST',
        '/api/$version/shares/$writeHash/auth',
        body: const {},
        unauthenticated: true,
      );
      await capture(
        'link_share/${version}_auth_password_wrong',
        'POST',
        '/api/$version/shares/$writeHash/auth',
        body: {'password': 'wrong-${_randomWord(8)}'},
        unauthenticated: true,
      );
      await capture(
        'link_share/${version}_auth_password',
        'POST',
        '/api/$version/shares/$writeHash/auth',
        body: {'password': linkPassword},
        unauthenticated: true,
      );
      await capture(
        'link_share/${version}_auth_unknown',
        'POST',
        '/api/$version/shares/$unknownHash/auth',
        body: const {},
        unauthenticated: true,
      );
    }
    final guestToken = readToken!;
    for (final version in ['v1', 'v2']) {
      await capture(
        'link_share/${version}_renew',
        'POST',
        '/api/$version/user/token',
        bearer: guestToken,
      );
      await capture(
        'link_share/${version}_renew_user_token',
        'POST',
        '/api/$version/user/token',
        bearer: owner.jwt,
      );
      await capture(
        'link_share/${version}_renew_not_a_jwt',
        'POST',
        '/api/$version/user/token',
        bearer: 'not-a-jwt',
      );
    }

    await owned(
      'DELETE',
      '/api/v1/projects/$projectId/shares/${readShare['id']}',
    );
    for (final version in ['v1', 'v2']) {
      await capture(
        'link_share/${version}_projects_share_gone',
        'GET',
        '/api/$version/projects',
        bearer: guestToken,
      );
      await capture(
        'link_share/${version}_renew_share_gone',
        'POST',
        '/api/$version/user/token',
        bearer: guestToken,
      );
    }

    await capture(
      'invites/v2_invite_check_invalid',
      'POST',
      '/api/v2/invite-links/check',
      body: {'token': _randomWord(64)},
      unauthenticated: true,
    );
  } finally {
    await owned('DELETE', '/api/v1/projects/$projectId');
    dio.close(force: true);
  }
}

typedef _User = ({String username, String password, String jwt});

final class _Spacer {
  DateTime? _last;

  Future<void> wait() async {
    final last = _last;
    if (last != null) {
      final left = _unauthenticatedSpacing - DateTime.now().difference(last);
      if (left > Duration.zero) await Future<void>.delayed(left);
    }
    _last = DateTime.now();
  }
}

Future<_User> _register(Dio dio, _Spacer spacer) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'lsowner$suffix';
  final password = 'password-$suffix-${_randomWord(10)}';
  await spacer.wait();
  await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/register',
      data: {
        'username': username,
        'email': '$username@example.com',
        'password': password,
      },
    ),
  );
  await spacer.wait();
  final login = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/login',
      data: {'username': username, 'password': password},
    ),
  );
  return (
    username: username,
    password: password,
    jwt: _decode(login.data!)!['token']! as String,
  );
}

Future<Response<String>> _unauthenticated(
  Future<Response<String>> Function() call,
) async {
  for (var attempt = 1; ; attempt++) {
    final response = await call();
    if (response.statusCode == 429 && attempt < 8) {
      await _waitOut(response);
      continue;
    }
    if (response.statusCode! >= 300) {
      throw StateError('unauthenticated call: ${response.statusCode}');
    }
    return response;
  }
}

Future<Response<String>> _send(
  Dio dio,
  String method,
  String path, {
  Map<String, Object?>? body,
  String? bearer,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        contentType: body == null ? null : Headers.jsonContentType,
        headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'},
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
      await _waitOut(response);
      continue;
    }
    return response;
  }
}

Future<void> _waitOut(Response<String> response) async {
  final retryAfter = int.tryParse(response.headers.value('retry-after') ?? '');
  final jitter = Random().nextInt(3000);
  await Future<void>.delayed(
    Duration(seconds: (retryAfter ?? 10) + 1, milliseconds: jitter),
  );
}

Map<String, Object?>? _decode(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String _randomWord(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(random.nextInt(alphabet.length)),
  ]);
}
