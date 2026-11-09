// Records the answers of step 31's AccountSecurityPort into
// test/fixtures/account_security, with one throwaway user:
//   dart run tool/capture_account_security_fixtures.dart \
//     [http://localhost:34527] [2.8.0]
// The user signs in three times: a password login (the bearer of every
// capture), an OAuth sign-in whose code exchange sends a Rurana User-Agent
// and a password login as Firefox. Then: the sessions on both versions, whole
// and two to a page, revoked (the Firefox one on v1, the OAuth one on v2)
// and an unknown one; `/routes`; API tokens listed, created, refused (no
// title, no permission, an unknown permission) and deleted, one of them
// twice; CalDAV tokens listed, created and deleted, an unknown id too; the
// data export before and after a request; last the TOTP status before an
// enrolment, after it, and once enabled, which ends every session (up to
// 2.7.0 the bearer keeps working until it expires, from 2.7.1 the user signs
// in again with a code); TOTP is disabled again. From 2.7.1 enrolling and
// enabling take the password too, and disabling a code as well.
//
// Requests with a password, a TOTP code or a token value are never
// captured. Every token, secret, password and email is scrubbed, and a
// capture that still holds one is an error: no file may hold a secret.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

typedef _User = ({String username, String email, String password, String jwt});

const _ruranaAgent = 'Rurana/0.31.0+42 (android 15)';
const _firefoxAgent =
    'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0';
const _fakeApiToken = 'tk_0000000000000000000000000000000000000000';
final String _fakeCaldavToken = '0' * 64;
const _redacted = '<redacted>';
final _apiTokenPattern = RegExp('tk_[0-9a-f]{40}');
final _caldavTokenPattern = RegExp('"token":"([A-Za-z0-9]{64})"');
final _secretPattern = RegExp('"secret":"([^"]+)"');
final _otpauthSecretPattern = RegExp('secret=([A-Za-z0-9]+)');

final _client = OAuthClientConfig(
  clientId: 'dev.coderoftime.rurana',
  redirectUri: Uri.parse('vikunja-dev.coderoftime.rurana://oauth/callback'),
);

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
  final user = await _register(dio, 'fixtureus');
  final secrets = <String>{user.password, user.jwt};

  final ruranaDio = Dio(BaseOptions(headers: {'User-Agent': _ruranaAgent}));
  final connection = await DioServerConnector(ruranaDio).connect(root);
  final oauth = await _oauthSignIn(ruranaDio, connection, user.jwt);
  secrets.addAll([oauth.accessToken, oauth.refreshToken]);
  final firefoxJwt = await _login(dio, user, userAgent: _firefoxAgent);
  secrets.add(firefoxJwt);
  final since271 = connection.info.version?.isAtLeast(2, 7, 1) ?? false;
  var bearer = user.jwt;

  String scrub(String text) {
    var scrubbed = text
        .replaceAll(user.email, 'fixtureuser@example.invalid')
        .replaceAll(user.username, 'fixtureuser');
    for (final match in _apiTokenPattern.allMatches(scrubbed)) {
      if (match[0] != _fakeApiToken) secrets.add(match[0]!);
    }
    for (final match in _caldavTokenPattern.allMatches(scrubbed)) {
      if (match[1] != _fakeCaldavToken) secrets.add(match[1]!);
    }
    for (final match in _secretPattern.allMatches(scrubbed)) {
      if (match[1] != _redacted) secrets.add(match[1]!);
    }
    for (final match in _otpauthSecretPattern.allMatches(scrubbed)) {
      secrets.add(match[1]!);
    }
    scrubbed = scrubbed
        .replaceAll(_apiTokenPattern, _fakeApiToken)
        .replaceAllMapped(
          _caldavTokenPattern,
          (_) => '"token":"$_fakeCaldavToken"',
        )
        .replaceAllMapped(_secretPattern, (_) => '"secret":"$_redacted"')
        .replaceAllMapped(_otpauthSecretPattern, (_) => 'secret=$_redacted');
    final leaks =
        scrubbed.contains('@example.com') ||
        secrets.any(
          (secret) => secret.length >= 6 && scrubbed.contains(secret),
        );
    if (leaks) throw StateError('a capture leaks a secret or an email');
    return scrubbed;
  }

  Future<String> capture(
    String name,
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(dio, bearer, method, path, body: body);
    final file = File(
      'test/fixtures/account_security/${name}_$serverVersion.json',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'server': serverVersion,
        'request': '$method $path',
        if (body != null) 'sent': jsonDecode(scrub(jsonEncode(body))),
        'status': response.statusCode,
        'headers': {
          for (final header in const [
            'content-type',
            'x-pagination-total-pages',
            'x-pagination-result-count',
          ])
            header: ?response.headers.value(header),
        },
        'body': scrub(response.data ?? ''),
      }),
    );
    stdout.writeln('wrote ${file.path} (${response.statusCode})');
    return response.data ?? '';
  }

  Future<Object?> raw(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final response = await _send(dio, bearer, method, path, body: body);
    if (response.statusCode! >= 300) {
      throw StateError('$method $path: ${response.statusCode}');
    }
    final data = response.data ?? '';
    return data.trim().isEmpty ? null : jsonDecode(data);
  }

  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_sessions',
      'GET',
      '/api/$version/user/sessions?page=1&per_page=50',
    );
    for (final page in [1, 2]) {
      await capture(
        '${version}_sessions_page_$page',
        'GET',
        '/api/$version/user/sessions?page=$page&per_page=2',
      );
    }
  }
  final firefoxSid = JwtClaims.tryParse(firefoxJwt)!.sessionId;
  await capture(
    'v1_session_revoke',
    'DELETE',
    '/api/v1/user/sessions/$firefoxSid',
  );
  await capture(
    'v2_session_revoke',
    'DELETE',
    '/api/v2/user/sessions/${oauth.sessionId}',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_session_revoke_unknown',
      'DELETE',
      '/api/$version/user/sessions/00000000-0000-4000-8000-000000000000',
    );
  }

  for (final version in ['v1', 'v2']) {
    await capture('${version}_routes', 'GET', '/api/$version/routes');
    await capture(
      '${version}_api_tokens_empty',
      'GET',
      '/api/$version/tokens?page=1&per_page=50',
    );
  }
  final expires = DateTime.now().toUtc().add(const Duration(days: 30));
  final expiry = DateTime.utc(expires.year, expires.month, expires.day, 12);
  await capture(
    'v1_api_token_create',
    'PUT',
    '/api/v1/tokens',
    body: {
      'title': 'Home Assistant',
      'permissions': {
        'tasks': ['read_all', 'update'],
        'caldav': ['access'],
      },
      'expires_at': expiry.toIso8601String(),
    },
  );
  await capture(
    'v2_api_token_create',
    'POST',
    '/api/v2/tokens',
    body: {
      'title': 'Backup script',
      'permissions': {
        'projects': ['read_all', 'read_one'],
        'other': ['user'],
      },
      'expires_at': expiry.add(const Duration(days: 60)).toIso8601String(),
    },
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_api_tokens',
      'GET',
      '/api/$version/tokens?page=1&per_page=50',
    );
  }
  for (final (version, method) in [('v1', 'PUT'), ('v2', 'POST')]) {
    await capture(
      '${version}_api_token_create_no_title',
      method,
      '/api/$version/tokens',
      body: {
        'title': '',
        'permissions': {
          'tasks': ['read_all'],
        },
        'expires_at': expiry.toIso8601String(),
      },
    );
    await capture(
      '${version}_api_token_create_no_permission',
      method,
      '/api/$version/tokens',
      body: {
        'title': 'Nothing',
        'permissions': <String, Object?>{},
        'expires_at': expiry.toIso8601String(),
      },
    );
    await capture(
      '${version}_api_token_create_unknown_permission',
      method,
      '/api/$version/tokens',
      body: {
        'title': 'Flying',
        'permissions': {
          'tasks': ['fly'],
        },
        'expires_at': expiry.toIso8601String(),
      },
    );
  }
  final tokens = await raw('GET', '/api/v2/tokens?page=1&per_page=50');
  final tokenIds = [
    for (final token in (tokens! as Map<String, Object?>)['items']! as List)
      (token as Map<String, Object?>)['id']! as int,
  ];
  await capture(
    'v1_api_token_delete',
    'DELETE',
    '/api/v1/tokens/${tokenIds[0]}',
  );
  await capture(
    'v2_api_token_delete',
    'DELETE',
    '/api/v2/tokens/${tokenIds[1]}',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_api_token_delete_unknown',
      'DELETE',
      '/api/$version/tokens/${tokenIds[1]}',
    );
  }

  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_caldav_tokens_empty',
      'GET',
      '/api/$version/user/settings/token/caldav?page=1&per_page=50',
    );
  }
  await capture(
    'v1_caldav_token_create',
    'PUT',
    '/api/v1/user/settings/token/caldav',
  );
  await capture(
    'v2_caldav_token_create',
    'POST',
    '/api/v2/user/settings/token/caldav',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_caldav_tokens',
      'GET',
      '/api/$version/user/settings/token/caldav?page=1&per_page=50',
    );
  }
  final caldav = await raw('GET', '/api/v1/user/settings/token/caldav');
  final caldavIds = [
    for (final token in caldav! as List)
      (token as Map<String, Object?>)['id']! as int,
  ];
  await capture(
    'v1_caldav_token_delete',
    'DELETE',
    '/api/v1/user/settings/token/caldav/${caldavIds[0]}',
  );
  await capture(
    'v2_caldav_token_delete',
    'DELETE',
    '/api/v2/user/settings/token/caldav/${caldavIds[1]}',
  );
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_caldav_token_delete_unknown',
      'DELETE',
      '/api/$version/user/settings/token/caldav/${caldavIds[1]}',
    );
  }

  for (final version in ['v1', 'v2']) {
    await capture('${version}_export_none', 'GET', '/api/$version/user/export');
  }
  await raw(
    'POST',
    '/api/v1/user/export/request',
    body: {'password': user.password},
  );
  for (var attempt = 0; ; attempt++) {
    final status = await raw('GET', '/api/v1/user/export');
    if (status case {'id': final int id} when id > 0) break;
    if (attempt == 30) throw StateError('the export never became ready');
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  for (final version in ['v1', 'v2']) {
    await capture('${version}_export', 'GET', '/api/$version/user/export');
  }

  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_totp_not_set_up',
      'GET',
      '/api/$version/user/settings/totp',
    );
  }
  final enrolment =
      (await raw(
            'POST',
            '/api/v2/user/settings/totp/enroll',
            body: since271 ? {'password': user.password} : null,
          ))!
          as Map<String, Object?>;
  final totpSecret = enrolment['secret']! as String;
  final totpUrl = enrolment['url']! as String;
  secrets.addAll([totpSecret, totpUrl]);
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_totp_setup_started',
      'GET',
      '/api/$version/user/settings/totp',
    );
  }
  // The server takes a code once, even in a write it then loses with a 500,
  // so each try waits for a fresh one.
  Future<void> withCode(
    String path,
    Map<String, Object?> Function(String code) body,
  ) async {
    for (var attempt = 1; ; attempt++) {
      final response = await _send(
        dio,
        bearer,
        'POST',
        path,
        body: body(_totpCode(totpSecret)),
        retryLostRaces: false,
      );
      if (response.statusCode! < 300) return;
      if (response.statusCode != 500 || attempt == 4) {
        throw StateError('POST $path: ${response.statusCode}');
      }
      await _nextTotpWindow();
    }
  }

  await withCode(
    '/api/v2/user/settings/totp/enable',
    (code) => {'passcode': code, if (since271) 'password': user.password},
  );
  if (since271) {
    await _nextTotpWindow();
    bearer = await _login(dio, user, totpSecret: totpSecret);
    secrets.add(bearer);
  }
  for (final version in ['v1', 'v2']) {
    await capture(
      '${version}_totp_enabled',
      'GET',
      '/api/$version/user/settings/totp',
    );
  }
  if (since271) {
    await _nextTotpWindow();
    await withCode(
      '/api/v2/user/settings/totp/disable',
      (code) => {'password': user.password, 'totp_passcode': code},
    );
  } else {
    await raw(
      'POST',
      '/api/v2/user/settings/totp/disable',
      body: {'password': user.password},
    );
  }

  dio.close();
  ruranaDio.close();
}

Future<TokenSet> _oauthSignIn(
  Dio dio,
  ServerConnection connection,
  String jwt,
) async {
  final request = AuthorizationRequest.create(connection, _client);
  final query = request.url.queryParameters;
  final api = connection.apiBaseUri(ApiVersion.v2);
  final response = await dio.postUri<Map<String, Object?>>(
    api.replace(path: '${api.path}/oauth/authorize'),
    data: {
      for (final key in const [
        'response_type',
        'client_id',
        'redirect_uri',
        'state',
        'code_challenge',
        'code_challenge_method',
      ])
        key: query[key],
    },
    options: Options(headers: {'Authorization': 'Bearer $jwt'}),
  );
  final body = response.data!;
  final callback = Uri.parse(body['redirect_uri']! as String).replace(
    queryParameters: {
      'code': body['code']! as String,
      'state': body['state']! as String,
    },
  );
  return await OAuthTokenClient(
    dio,
    connection,
  ).exchangeCode(code: request.codeFromCallback(callback), request: request);
}

/// The server takes each code once, so a second one needs the next window.
Future<void> _nextTotpWindow() => Future<void>.delayed(
  Duration(milliseconds: 30500 - DateTime.now().millisecondsSinceEpoch % 30000),
);

/// RFC 6238 with the server's parameters: SHA-1, six digits, 30 seconds.
String _totpCode(String base32Secret) {
  final key = _base32Decode(base32Secret);
  final counter = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
  final message = ByteData(8)..setInt64(0, counter);
  final mac = Hmac(sha1, key).convert(message.buffer.asUint8List()).bytes;
  final offset = mac.last & 0x0f;
  final value =
      ((mac[offset] & 0x7f) << 24 |
          mac[offset + 1] << 16 |
          mac[offset + 2] << 8 |
          mac[offset + 3]) %
      1000000;
  return value.toString().padLeft(6, '0');
}

List<int> _base32Decode(String text) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final bytes = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final char in text.toUpperCase().replaceAll('=', '').split('')) {
    buffer = buffer << 5 | alphabet.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add(buffer >> bits & 0xff);
    }
  }
  return bytes;
}

Future<_User> _register(Dio dio, String prefix) async {
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = '$prefix$suffix';
  final email = '$username@example.com';
  final password = 'password-$suffix-${Random.secure().nextInt(1 << 32)}';
  await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/register',
      data: {'username': username, 'email': email, 'password': password},
    ),
  );
  final user = (username: username, email: email, password: password, jwt: '');
  return (
    username: username,
    email: email,
    password: password,
    jwt: await _login(dio, user),
  );
}

Future<String> _login(
  Dio dio,
  _User user, {
  String? userAgent,
  String? totpSecret,
}) async {
  final login = await _unauthenticated(
    () => dio.post<String>(
      '/api/v1/login',
      data: {
        'username': user.username,
        'password': user.password,
        if (totpSecret != null) 'totp_passcode': _totpCode(totpSecret),
      },
      options: Options(headers: {'User-Agent': ?userAgent}),
    ),
  );
  return (jsonDecode(login.data!) as Map<String, Object?>)['token']! as String;
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
  Map<String, Object?>? body,
  bool retryLostRaces = true,
}) async {
  for (var attempt = 1; ; attempt++) {
    final response = await dio.request<String>(
      path,
      data: body,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $jwt'},
        validateStatus: (_) => true,
      ),
    );
    if (method != 'GET') {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    // The SQLite server answers a write that collides with its own event
    // handlers, the data export among them, with a 500 and changes nothing.
    if (response.statusCode == 500 && retryLostRaces && attempt < 8) {
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
