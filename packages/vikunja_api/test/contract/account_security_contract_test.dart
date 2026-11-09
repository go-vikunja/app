@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// One throwaway user, whose password exists only in memory: the export
// request and the TOTP enrolment and cancel below need it, the cancel from
// 2.7.1 a code of the enrolment's secret too, which stays in memory as well.
// From 2.8.0 the cancel is refused and the setup can only be finished.
// The port runs over an OAuth session whose code exchange sent a Rurana
// User-Agent. No token value, secret or password is ever printed: failures
// name shapes and lengths.
const _pace = Duration(milliseconds: 500);
const _ruranaAgent = 'Rurana/0.31.0+31 (android 15)';
const _propfind = '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:current-user-principal/><c:calendar-home-set/></d:prop>
</d:propfind>''';
final _apiTokenShape = RegExp(r'^tk_[0-9a-f]{40}$');
final _caldavTokenShape = RegExp(r'^[A-Za-z0-9]{64}$');

final _client = OAuthClientConfig(
  clientId: 'dev.coderoftime.rurana',
  redirectUri: Uri.parse('vikunja-dev.coderoftime.rurana://oauth/callback'),
);

typedef _User = ({String username, String password, String jwt});

void main() {
  group('account security on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late Dio ruranaDio;
        late ServerConnection connection;
        late OAuthTokenClient tokenClient;
        late _User user;
        late TokenSet current;

        AccountSecurityPort portOver(ApiVersion apiVersion) {
          final over = onlyVersion(connection, apiVersion);
          return createAccountSecurityPort(
            dio: createAuthenticatedDio(
              base: dio,
              connection: over,
              tokens: StaticJwt(current.accessToken),
            ),
            connection: over,
          );
        }

        bool since271() => connection.info.version?.isAtLeast(2, 7, 1) ?? false;
        bool since280() => connection.info.version?.isAtLeast(2, 8) ?? false;

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        Uri api(String path) {
          final base = connection.apiBaseUri(ApiVersion.v2);
          return base.replace(path: '${base.path}$path');
        }

        Future<Response<Object?>> postAsUser(
          String path,
          Map<String, Object?>? body,
        ) => dio.postUri<Object?>(
          api(path),
          data: body,
          options: Options(
            headers: {'Authorization': 'Bearer ${user.jwt}'},
            // The TOTP enrolment answers with the secret.
            responseType: ResponseType.bytes,
          ),
        );

        Future<Object?> rawWrite(
          String path,
          Map<String, Object?>? body,
        ) async => (await paced(() => postAsUser(path, body))).data;

        // The server takes a code once, even in a write it loses to a
        // parallel one with a 500, so a retry waits for the next code.
        Future<void> rawWriteWithCode(
          String path,
          String secret,
          Map<String, Object?> Function(String code) body,
        ) async {
          for (var attempt = 1; ; attempt++) {
            try {
              await patiently(() => postAsUser(path, body(_totpCode(secret))));
              await Future<void>.delayed(_pace);
              return;
            } on DioException catch (error) {
              if (error.response?.statusCode != 500 || attempt == 3) rethrow;
              await _nextTotpWindow();
            }
          }
        }

        Future<int> propfind(String password) async {
          final credentials = base64Encode(
            utf8.encode('${user.username}:$password'),
          );
          final response = await patiently(
            () => dio.requestUri<String>(
              connection.rootUri.replace(
                path: '/dav/principals/${user.username}/',
              ),
              data: _propfind,
              options: Options(
                method: 'PROPFIND',
                contentType: 'application/xml; charset=utf-8',
                responseType: ResponseType.plain,
                headers: {'Authorization': 'Basic $credentials', 'Depth': '0'},
                validateStatus: (_) => true,
              ),
            ),
          );
          return response.statusCode!;
        }

        Future<TokenSet> signIn() async {
          final request = AuthorizationRequest.create(connection, _client);
          final query = request.url.queryParameters;
          final response = await patiently(
            () => dio.postUri<Map<String, Object?>>(
              api('/oauth/authorize'),
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
              options: Options(
                headers: {'Authorization': 'Bearer ${user.jwt}'},
              ),
            ),
          );
          final body = response.data!;
          final callback = Uri.parse(body['redirect_uri']! as String).replace(
            queryParameters: {
              'code': body['code']! as String,
              'state': body['state']! as String,
            },
          );
          return await patiently(
            () => tokenClient.exchangeCode(
              code: request.codeFromCallback(callback),
              request: request,
            ),
          );
        }

        setUpAll(() async {
          dio = contractDio();
          ruranaDio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'User-Agent': _ruranaAgent},
            ),
          );
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          tokenClient = OAuthTokenClient(ruranaDio, connection);
          user = await _registerAndLogin(dio, connection);
          current = await signIn();
        });

        tearDownAll(() {
          dio.close(force: true);
          ruranaDio.close(force: true);
        });

        test('sessions: the current sid with our User-Agent and another '
            'sign-in; revoking that one ends its refresh at once, on both '
            'versions', () async {
          for (final apiVersion in ApiVersion.values) {
            // "This device" and never ending it rest on a refresh keeping
            // the session id.
            final refreshed = await paced(
              () => tokenClient.refresh(current.refreshToken),
            );
            expect(
              JwtClaims.tryParse(refreshed.accessToken)!.sessionId,
              current.sessionId,
            );
            current = refreshed;
            final port = portOver(apiVersion);
            final other = await signIn();

            final sessions = await patiently(port.sessions);
            final ids = sessions.map((session) => session.id);
            expect(ids, containsAll([current.sessionId, other.sessionId]));
            expect(
              ids,
              contains(JwtClaims.tryParse(user.jwt)!.sessionId),
              reason: 'the password login',
            );
            final mine = sessions.singleWhere(
              (session) => session.id == current.sessionId,
            );
            expect(mine.deviceInfo, _ruranaAgent);
            expect(mine.created, isNotNull);
            expect(mine.lastActive, isNotNull);

            await paced(() => port.revokeSession(other.sessionId));

            await expectLater(
              tokenClient.refresh(other.refreshToken),
              throwsA(isA<SessionEnded>()),
              reason: '$apiVersion',
            );
            expect(
              (await patiently(port.sessions)).map((session) => session.id),
              isNot(contains(other.sessionId)),
            );
            await paced(() => port.revokeSession(other.sessionId));
          }
        });

        test('API tokens: /routes, create, list, a CalDAV PROPFIND with the '
            'caldav permission, delete, twice, on both versions', () async {
          for (final apiVersion in ApiVersion.values) {
            final port = portOver(apiVersion);
            final groups = await patiently(port.apiPermissions);
            expect(groups.offers('caldav', 'access'), isTrue);
            expect(groups.offers('tasks', 'read_all'), isTrue);
            // The app's task preset moves tasks between buckets by this name.
            expect(
              groups.offers(
                'projects',
                since271()
                    ? 'views_buckets_tasks_update'
                    : 'views_buckets_tasks',
              ),
              isTrue,
            );
            expect(groups.groupNames.last, ApiPermissionGroups.otherGroup);

            final expiresAt = DateTime.now().toUtc().add(
              const Duration(days: 30),
            );
            final created = await paced(
              () => port.createApiToken(
                NewApiToken(
                  title: 'Contract ${apiVersion.name}',
                  permissions: const {
                    'tasks': ['read_all'],
                    'caldav': ['access'],
                  },
                  expiresAt: expiresAt,
                ),
              ),
            );
            expect(
              _apiTokenShape.hasMatch(created.secret),
              isTrue,
              reason: 'token shape, length ${created.secret.length}',
            );
            expect(created.token.title, 'Contract ${apiVersion.name}');
            expect(
              created.token.expiresAt.difference(expiresAt).inSeconds.abs(),
              lessThan(1),
            );

            final listed = (await patiently(port.apiTokens))
                .singleWhere((token) => token.id == created.token.id);
            expect(listed.permissions, {
              'caldav': ['access'],
              'tasks': ['read_all'],
            });
            expect(await propfind(created.secret), 207);

            await paced(() => port.deleteApiToken(created.token.id));
            expect(
              (await patiently(port.apiTokens)).map((token) => token.id),
              isNot(contains(created.token.id)),
            );
            // 2.7.1 answers 404 code 14017, which counts as deleted.
            await expectLater(
              port.deleteApiToken(created.token.id),
              since271() ? completes : throwsA(isA<Forbidden>()),
            );
            expect(await propfind(created.secret), 401);

            await expectLater(
              port.createApiToken(
                NewApiToken(
                  title: 'Flying',
                  permissions: const {
                    'tasks': ['fly'],
                  },
                  expiresAt: expiresAt,
                ),
              ),
              throwsA(
                isA<DomainError>()
                    .having((f) => f.statusCode, 'status', 400)
                    .having((f) => f.code, 'code', 14002),
              ),
            );
            await Future<void>.delayed(_pace);
            await expectLater(
              port.createApiToken(
                NewApiToken(
                  title: 'Nothing',
                  permissions: const {},
                  expiresAt: expiresAt,
                ),
              ),
              throwsA(
                isA<ValidationFailed>().having(
                  (f) => f.fieldErrors.keys,
                  'fields',
                  ['permissions'],
                ),
              ),
            );
            await Future<void>.delayed(_pace);
          }
        });

        test('CalDAV tokens: create, a PROPFIND with the token, list, '
            'delete, on both versions', () async {
          for (final apiVersion in ApiVersion.values) {
            final port = portOver(apiVersion);
            final created = await paced(port.createCaldavToken);
            expect(
              _caldavTokenShape.hasMatch(created.secret),
              isTrue,
              reason: 'token shape, length ${created.secret.length}',
            );
            expect(
              (await patiently(port.caldavTokens)).map((token) => token.id),
              contains(created.token.id),
            );
            expect(await propfind(created.secret), 207);

            await paced(() => port.deleteCaldavToken(created.token.id));
            expect(
              (await patiently(port.caldavTokens)).map((token) => token.id),
              isNot(contains(created.token.id)),
            );
            expect(await propfind(created.secret), 401);
            await paced(() => port.deleteCaldavToken(created.token.id));
          }
        });

        test('GET /user: no deletion scheduled', () async {
          final response = await patiently(
            () => dio.getUri<Object?>(
              api('/user'),
              options: Options(
                headers: {'Authorization': 'Bearer ${current.accessToken}'},
              ),
            ),
          );
          final profile = parseUserProfile(response.data);
          expect(profile!.username, user.username);
          expect(profile.deletionScheduledAt, isNull);
        });

        test('data export: none, then a status once a request is '
            'written', () async {
          for (final apiVersion in ApiVersion.values) {
            expect(
              await patiently(portOver(apiVersion).dataExport),
              isNull,
              reason: '$apiVersion',
            );
          }
          await rawWrite('/user/export/request', {'password': user.password});

          UserDataExport? export;
          for (var attempt = 0; attempt < 30 && export == null; attempt++) {
            await Future<void>.delayed(const Duration(seconds: 1));
            export = await patiently(portOver(ApiVersion.v2).dataExport);
          }
          expect(export, isNotNull, reason: 'the export never became ready');
          expect(export!.size, greaterThan(0));
          expect(export.expires.isAfter(DateTime.now()), isTrue);
          expect(
            (await patiently(portOver(ApiVersion.v1).dataExport))?.id,
            export.id,
          );
        });

        test('TOTP: not set up, a started setup, cancelled again with the '
            'password and from 2.7.1 a code, from 2.8.0 refused', () async {
          Future<List<TotpStatus>> statuses() async => [
            for (final apiVersion in ApiVersion.values)
              await patiently(portOver(apiVersion).totpStatus),
          ];

          expect(await statuses(), [TotpStatus.notSetUp, TotpStatus.notSetUp]);
          final enrolment = await rawWrite(
            '/user/settings/totp/enroll',
            since271() ? {'password': user.password} : null,
          );
          final secret =
              (jsonDecode(utf8.decode(enrolment! as List<int>))
                      as Map<String, Object?>)['secret']!
                  as String;
          expect(await statuses(), [
            TotpStatus.setupStarted,
            TotpStatus.setupStarted,
          ]);
          if (since280()) {
            await expectLater(
              rawWriteWithCode(
                '/user/settings/totp/disable',
                secret,
                (code) => {'password': user.password, 'totp_passcode': code},
              ),
              throwsA(
                isA<DioException>().having(
                  normalizeError,
                  'failure',
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 412)
                      .having((f) => f.code, 'code', 1016),
                ),
              ),
            );
            expect(await statuses(), [
              TotpStatus.setupStarted,
              TotpStatus.setupStarted,
            ]);
            return;
          }
          if (since271()) {
            await rawWriteWithCode(
              '/user/settings/totp/disable',
              secret,
              (code) => {'password': user.password, 'totp_passcode': code},
            );
          } else {
            await rawWrite('/user/settings/totp/disable', {
              'password': user.password,
            });
          }
          expect(await statuses(), [TotpStatus.notSetUp, TotpStatus.notSetUp]);
        });
      });
    }
  });
}

Future<void> _nextTotpWindow() => Future<void>.delayed(
  Duration(milliseconds: 30500 - DateTime.now().millisecondsSinceEpoch % 30000),
);

/// RFC 6238 with the server's parameters: SHA-1, six digits, 30 seconds.
String _totpCode(String base32Secret) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final key = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final char in base32Secret.toUpperCase().replaceAll('=', '').split('')) {
    buffer = buffer << 5 | alphabet.indexOf(char);
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      key.add(buffer >> bits & 0xff);
    }
  }
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

Future<_User> _registerAndLogin(Dio dio, ServerConnection connection) async {
  final v1 = connection.apiBaseUri(ApiVersion.v1);
  final suffix = Random.secure().nextInt(1 << 32).toRadixString(16);
  final username = 'contract$suffix';
  final password = 'pw-$suffix-${Random.secure().nextInt(1 << 32)}';
  await despiteWriteRaces(
    () => dio.postUri<Object?>(
      v1.replace(path: '${v1.path}/register'),
      data: {
        'username': username,
        'email': '$username@example.com',
        'password': password,
      },
    ),
  );
  final login = await despiteWriteRaces(
    () => dio.postUri<Map<String, Object?>>(
      v1.replace(path: '${v1.path}/login'),
      data: {'username': username, 'password': password},
    ),
  );
  return (
    username: username,
    password: password,
    jwt: login.data!['token']! as String,
  );
}
