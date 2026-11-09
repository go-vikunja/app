import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_account_security_fixtures.dart
// from one user with three sessions: a password login, an OAuth sign-in
// with a Rurana User-Agent and a password login as Firefox. Token values
// are replaced by zeros, TOTP secrets by `<redacted>`.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _page = '?page=1&per_page=50';
const _fixtureToken = 'tk_0000000000000000000000000000000000000000';
const _ruranaSession = '99392678-be79-4a08-97f7-5f08f10e230e';
const _loginSession = '4fba43b8-d48d-479f-894b-9d9f21f8b421';
const _firefoxSession = '27c9b42b-0ce4-4774-a234-ef842636a84e';

final _created = DateTime.utc(2026, 10, 21, 6, 19, 9);
final _sessions = [
  UserSession(
    id: _ruranaSession,
    deviceInfo: 'Rurana/0.31.0+42 (android 15)',
    ipAddress: '172.20.0.1',
    created: _created,
    lastActive: _created,
  ),
  UserSession(
    id: _loginSession,
    deviceInfo: 'Rurana fixture capture',
    ipAddress: '172.20.0.1',
    created: _created,
    lastActive: _created,
  ),
  UserSession(
    id: _firefoxSession,
    deviceInfo:
        'Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 '
        'Firefox/140.0',
    ipAddress: '172.20.0.1',
    created: _created,
    lastActive: _created,
  ),
];

final _apiTokens = [
  ApiToken(
    id: 91,
    title: 'Home Assistant',
    permissions: const {
      'caldav': ['access'],
      'tasks': ['read_all', 'update'],
    },
    expiresAt: DateTime.utc(2026, 11, 20, 12),
    created: DateTime.utc(2026, 10, 21, 6, 19, 11),
  ),
  ApiToken(
    id: 92,
    title: 'Backup script',
    permissions: const {
      'other': ['user'],
      'projects': ['read_all', 'read_one'],
    },
    expiresAt: DateTime.utc(2027, 1, 19, 12),
    created: DateTime.utc(2026, 10, 21, 6, 19, 12),
  ),
];

final _caldavTokens = [
  CaldavToken(id: 9, created: DateTime.utc(2026, 10, 21, 6, 19, 17)),
  CaldavToken(id: 10, created: DateTime.utc(2026, 10, 21, 6, 19, 18)),
];

final _farFuture = DateTime.utc(2099);

AccountSecurityPort _port(Dio dio, String version, {int perPage = 50}) =>
    createAccountSecurityPort(
      dio: dio,
      connection: testConnection(
        hasV2: version == 'v2',
        maxItemsPerPage: perPage,
      ),
    );

String _base(String version) => version == 'v2' ? _v2 : _v1;

FakeRoute _captured(String name, {String server = '2.7.0'}) =>
    capturedFixture('account_security/${name}_$server');

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

FakeRoute _problem(int status, Map<String, Object?> body) =>
    (_) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json'],
      },
    );

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _validation(String field, {int? code}) => isA<ValidationFailed>()
    .having((f) => f.fieldErrors.keys, 'fields', [field])
    .having((f) => f.code, 'code', code);

void main() {
  for (final version in ['v1', 'v2']) {
    final base = _base(version);

    group('$version totpStatus', () {
      Future<TotpStatus> statusFrom(FakeRoute route) => _port(
        fakeDio({'$base/user/settings/totp': route}),
        version,
      ).totpStatus();

      test('412 code 1016 is not set up', () async {
        expect(
          await statusFrom(_captured('${version}_totp_not_set_up')),
          TotpStatus.notSetUp,
        );
      });

      test('a secret without enabled is a setup started', () async {
        expect(
          await statusFrom(_captured('${version}_totp_setup_started')),
          TotpStatus.setupStarted,
        );
      });

      test('enabled with the blanked secret of 2.7.0', () async {
        expect(
          await statusFrom(_captured('${version}_totp_enabled')),
          TotpStatus.enabled,
        );
      });
    });

    group('$version sessions', () {
      test('one page', () async {
        final dio = fakeDio({
          '$base/user/sessions$_page': _captured('${version}_sessions'),
        });

        expect(await _port(dio, version).sessions(), _sessions);
        expect(_calls(dio), ['GET $base/user/sessions$_page']);
      });

      test('reads every page in order', () async {
        final dio = fakeDio({
          '$base/user/sessions?page=1&per_page=2': _captured(
            '${version}_sessions_page_1',
          ),
          '$base/user/sessions?page=2&per_page=2': _captured(
            '${version}_sessions_page_2',
          ),
        });

        expect(await _port(dio, version, perPage: 2).sessions(), _sessions);
        expect(adapterOf(dio).requests, hasLength(2));
      });

      test('revoking answers ${version == 'v2' ? 204 : 200}', () async {
        final dio = fakeDio({
          '$base/user/sessions/$_firefoxSession': _captured(
            '${version}_session_revoke',
          ),
        });

        await _port(dio, version).revokeSession(_firefoxSession);

        expect(_calls(dio), ['DELETE $base/user/sessions/$_firefoxSession']);
      });

      test('a session that is gone already (404 code 16001) counts as '
          'ended', () async {
        final dio = fakeDio({
          '$base/user/sessions/$_firefoxSession': _captured(
            '${version}_session_revoke_unknown',
          ),
        });

        await _port(dio, version).revokeSession(_firefoxSession);
      });
    });

    group('$version API tokens', () {
      test(
        'lists without values, the permissions in the server order',
        () async {
          final dio = fakeDio({
            '$base/tokens$_page': _captured('${version}_api_tokens'),
          });

          final tokens = await _port(dio, version).apiTokens();

          expect(tokens, _apiTokens);
          expect(tokens.first.permissions.keys, ['caldav', 'tasks']);
        },
      );

      test('an empty list', () async {
        final dio = fakeDio({
          '$base/tokens$_page': _captured('${version}_api_tokens_empty'),
        });

        expect(await _port(dio, version).apiTokens(), isEmpty);
        expect(adapterOf(dio).requests, hasLength(1));
      });

      test('/routes: every group and permission the server offers', () async {
        final dio = fakeDio({'$base/routes': _captured('${version}_routes')});

        final groups = await _port(dio, version).apiPermissions();

        expect(groups.groups, hasLength(25));
        expect(groups.permissionCount, 116);
        expect(groups.groups.keys.first, 'caldav');
        expect(groups.groupNames.last, 'other');
        expect(groups.groups['caldav'], ['access']);
        expect(groups.offers('tasks', 'read_all'), isTrue);
        expect(groups.offers('user', 'read'), isFalse);
      });

      test(
        '/routes of 2.8.0: the bin permissions in tasks and projects',
        () async {
          final dio = fakeDio({
            '$base/routes': _captured('${version}_routes', server: '2.8.0'),
          });

          final groups = await _port(dio, version).apiPermissions();

          expect(groups.groups, hasLength(25));
          expect(groups.permissionCount, 127);
          for (final group in ['tasks', 'projects']) {
            for (final permission in [
              'deleted',
              'deleted_count',
              'deleted_delete',
              'permanent',
              'restore',
            ]) {
              expect(
                groups.offers(group, permission),
                isTrue,
                reason: '$group $permission',
              );
            }
          }
          expect(groups.offers('projects', 'count'), isTrue);
          expect(groups.offers('tasks', 'count'), isFalse);
        },
      );

      final createMethod = version == 'v2' ? 'POST' : 'PUT';

      test('create: $createMethod with the title, the permissions and the '
          'expiry in UTC; the answer carries the value once', () async {
        final dio = fakeDio({
          '$base/tokens': _captured('${version}_api_token_create'),
        });

        final created = await _port(dio, version).createApiToken(
          NewApiToken(
            title: 'Home Assistant',
            permissions: const {
              'tasks': ['read_all', 'update'],
              'caldav': ['access'],
            },
            expiresAt: DateTime.utc(2099, 1, 1, 12),
          ),
        );

        expect(_calls(dio), ['$createMethod $base/tokens']);
        expect(adapterOf(dio).decodedBodies.single, {
          'title': 'Home Assistant',
          'permissions': {
            'tasks': ['read_all', 'update'],
            'caldav': ['access'],
          },
          'expires_at': '2099-01-01T12:00:00.000Z',
        });
        expect(created.secret, _fixtureToken);
        expect(created.token.id, version == 'v1' ? 91 : 92);
        expect('$created', isNot(contains(_fixtureToken)));
      });

      test('create: no title and no permission are refused', () async {
        for (final (fixture, field, code) in [
          ('no_title', 'title', version == 'v1' ? 2002 : null),
          ('no_permission', 'permissions', 2002),
        ]) {
          final dio = fakeDio({
            '$base/tokens': _captured('${version}_api_token_create_$fixture'),
          });

          await expectLater(
            _port(dio, version).createApiToken(
              NewApiToken(
                title: 'x',
                permissions: const {},
                expiresAt: _farFuture,
              ),
            ),
            throwsA(_validation(field, code: code)),
            reason: fixture,
          );
        }
      });

      test('create: a permission the server does not offer is code '
          '14002', () async {
        final dio = fakeDio({
          '$base/tokens': _captured(
            '${version}_api_token_create_unknown_permission',
          ),
        });

        await expectLater(
          _port(dio, version).createApiToken(
            NewApiToken(
              title: 'Flying',
              permissions: const {
                'tasks': ['fly'],
              },
              expiresAt: _farFuture,
            ),
          ),
          throwsA(_domainError(400, 14002)),
        );
      });

      test('delete answers ${version == 'v2' ? 204 : 200}', () async {
        final dio = fakeDio({
          '$base/tokens/92': _captured('${version}_api_token_delete'),
        });

        await _port(dio, version).deleteApiToken(92);

        expect(_calls(dio), ['DELETE $base/tokens/92']);
      });

      test('delete: up to 2.7.0 an unknown id, like a foreign one, is a '
          'Forbidden', () async {
        final dio = fakeDio({
          '$base/tokens/92': _captured('${version}_api_token_delete_unknown'),
        });

        await expectLater(
          _port(dio, version).deleteApiToken(92),
          throwsA(isA<Forbidden>()),
        );
      });

      test('delete: from 2.7.1 a token deleted already (404 code 14017) '
          'counts as deleted', () async {
        final dio = fakeDio({
          '$base/tokens/12': _captured(
            '${version}_api_token_delete_unknown',
            server: '2.7.1',
          ),
        });

        await _port(dio, version).deleteApiToken(12);

        expect(_calls(dio), ['DELETE $base/tokens/12']);
      });
    });

    group('$version CalDAV tokens', () {
      test('lists without values', () async {
        final dio = fakeDio({
          '$base/user/settings/token/caldav$_page': _captured(
            '${version}_caldav_tokens',
          ),
        });

        expect(await _port(dio, version).caldavTokens(), _caldavTokens);
        expect(adapterOf(dio).requests, hasLength(1));
      });

      test('an empty list', () async {
        final dio = fakeDio({
          '$base/user/settings/token/caldav$_page': _captured(
            '${version}_caldav_tokens_empty',
          ),
        });

        expect(await _port(dio, version).caldavTokens(), isEmpty);
      });

      final createMethod = version == 'v2' ? 'POST' : 'PUT';

      test('create: $createMethod without a body; the answer carries the '
          'value once', () async {
        final dio = fakeDio({
          '$base/user/settings/token/caldav': _captured(
            '${version}_caldav_token_create',
          ),
        });

        final created = await _port(dio, version).createCaldavToken();

        expect(_calls(dio), ['$createMethod $base/user/settings/token/caldav']);
        expect(adapterOf(dio).requestBodies.single, isNull);
        expect(created.secret, '0' * 64);
        expect(created.token.id, version == 'v1' ? 9 : 10);
        expect('$created', isNot(contains('0' * 64)));
      });

      test('delete, an unknown id too', () async {
        for (final fixture in ['delete', 'delete_unknown']) {
          final dio = fakeDio({
            '$base/user/settings/token/caldav/10': _captured(
              '${version}_caldav_token_$fixture',
            ),
          });

          await _port(dio, version).deleteCaldavToken(10);

          expect(_calls(dio), [
            'DELETE $base/user/settings/token/caldav/10',
          ], reason: fixture);
        }
      });
    });

    group('$version dataExport', () {
      test('none (${version == 'v2' ? 'null' : '{}'}) is null', () async {
        final dio = fakeDio({
          '$base/user/export': _captured('${version}_export_none'),
        });

        expect(await _port(dio, version).dataExport(), isNull);
      });

      test('ready until it expires', () async {
        final dio = fakeDio({
          '$base/user/export': _captured('${version}_export'),
        });

        expect(
          await _port(dio, version).dataExport(),
          UserDataExport(
            id: 461,
            size: 1087,
            created: DateTime.utc(2026, 10, 21, 6, 19, 21),
            expires: DateTime.utc(2026, 10, 28, 6, 19, 21),
          ),
        );
      });
    });
  }

  group('totpStatus beyond the captures', () {
    Future<TotpStatus> statusFrom(FakeRoute route) =>
        _port(fakeDio({'$_v2/user/settings/totp': route}), 'v2').totpStatus();

    test('up to 2.6 the server sends the secret while TOTP is on', () async {
      expect(
        await statusFrom(
          json({
            'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
            'enabled': true,
            'url': 'otpauth://totp/Vikunja:dora?secret=JBSWY3DPEHPK3PXP',
          }),
        ),
        TotpStatus.enabled,
      );
    });

    test('neither enabled nor a secret is not set up', () async {
      expect(
        await statusFrom(json({'secret': '', 'enabled': false, 'url': ''})),
        TotpStatus.notSetUp,
      );
    });

    test('an account of a sign-in provider is code 1021', () async {
      await expectLater(
        statusFrom(
          _problem(412, {
            'status': 412,
            'detail':
                'This account is managed by a third-party authentication '
                'provider.',
            'code': 1021,
          }),
        ),
        throwsA(_domainError(412, 1021)),
      );
    });

    test('a server with TOTP turned off has no route', () async {
      await expectLater(
        statusFrom(json({'message': 'Not Found'}, status: 404)),
        throwsA(
          isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
        ),
      );
    });

    test('an API token is rejected', () async {
      await expectLater(
        statusFrom(
          json({
            'code': 11,
            'message':
                'missing, malformed, expired or otherwise invalid token '
                'provided',
          }, status: 401),
        ),
        throwsA(isA<TokenRejected>()),
      );
    });
  });

  group('lists beyond the captures', () {
    Map<String, Object?> sessionJson(String id) => {
      'id': id,
      'device_info': '',
      'ip_address': '',
      'created': '2026-10-21T06:19:09Z',
      'last_active': '2026-10-21T06:19:09Z',
    };

    Map<String, Object?> envelope(List<String> ids, int totalPages) => {
      'items': [for (final id in ids) sessionJson(id)],
      'total': ids.length,
      'page': 1,
      'per_page': 2,
      'total_pages': totalPages,
    };

    test('an id seen on an earlier page is skipped', () async {
      final dio = fakeDio({
        '$_v2/user/sessions?page=1&per_page=2': json(envelope(['a', 'b'], 2)),
        '$_v2/user/sessions?page=2&per_page=2': json(envelope(['b', 'c'], 2)),
      });

      final sessions = await _port(dio, 'v2', perPage: 2).sessions();

      expect(sessions.map((session) => session.id), ['a', 'b', 'c']);
    });

    test('stops after 20 pages and on an empty page', () async {
      var page = 0;
      final dio = Dio()
        ..httpClientAdapter = FakeHttpAdapter({
          for (var i = 1; i <= 25; i++)
            '$_v2/user/sessions?page=$i&per_page=2': (request) {
              page = i;
              return json(envelope(['s$i'], 99))(request);
            },
        });

      expect(await _port(dio, 'v2', perPage: 2).sessions(), hasLength(20));
      expect(page, 20);

      final empty = fakeDio({
        '$_v2/user/sessions?page=1&per_page=2': json(envelope([], 5)),
      });
      expect(await _port(empty, 'v2', perPage: 2).sessions(), isEmpty);
      expect(adapterOf(empty).requests, hasLength(1));
    });

    test('a v1 list without pagination headers is one page', () async {
      final dio = fakeDio({
        '$_v1/user/sessions?page=1&per_page=2': json([
          sessionJson('a'),
          sessionJson('b'),
        ]),
      });

      expect(await _port(dio, 'v1', perPage: 2).sessions(), hasLength(2));
      expect(adapterOf(dio).requests, hasLength(1));
    });

    test('anything else is an unexpected response', () async {
      final dio = fakeDio({
        '$_v2/tokens$_page': json({'tokens': <Object?>[]}),
      });

      await expectLater(
        _port(dio, 'v2').apiTokens(),
        throwsA(
          isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 200),
        ),
      );
    });
  });

  group('revokeSession beyond the captures', () {
    test('the id is one path segment', () async {
      final dio = fakeDio({'$_v2/user/sessions/a%2Fb%3Fc': status(204)});

      await _port(dio, 'v2').revokeSession('a/b?c');

      expect(_calls(dio), ['DELETE $_v2/user/sessions/a%2Fb%3Fc']);
    });

    test(
      'a 404 without code 16001 is not taken for an ended session',
      () async {
        final dio = fakeDio({
          '$_v2/user/sessions/x': json({'message': 'Not Found'}, status: 404),
        });

        await expectLater(
          _port(dio, 'v2').revokeSession('x'),
          throwsA(isA<NotFound>()),
        );
      },
    );

    test("another user's session is a Forbidden", () async {
      final dio = fakeDio({
        '$_v1/user/sessions/x': json({
          'code': 0,
          'message': 'Forbidden',
        }, status: 403),
      });

      await expectLater(
        _port(dio, 'v1').revokeSession('x'),
        throwsA(isA<Forbidden>()),
      );
    });
  });

  group('deleteApiToken beyond the captures', () {
    test('another 404 is not taken for a deleted token', () async {
      final routeAbsent = fakeDio({
        '$_v2/tokens/92': json({'message': 'Not Found'}, status: 404),
      });
      final otherCode = fakeDio({
        '$_v1/tokens/92': json({
          'code': 3001,
          'message': 'The project does not exist.',
        }, status: 404),
      });

      await expectLater(
        _port(routeAbsent, 'v2').deleteApiToken(92),
        throwsA(isA<NotFound>()),
      );
      await expectLater(
        _port(otherCode, 'v1').deleteApiToken(92),
        throwsA(isA<NotFound>().having((f) => f.code, 'code', 3001)),
      );
    });
  });

  group('createApiToken beyond the captures', () {
    test('a blank title or an expiry that is not in the future never reaches '
        'the server, which would accept both', () async {
      final dio = fakeDio({});
      final port = _port(dio, 'v2');

      await expectLater(
        port.createApiToken(
          NewApiToken(
            title: '   ',
            permissions: const {
              'tasks': ['read_all'],
            },
            expiresAt: _farFuture,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        port.createApiToken(
          NewApiToken(
            title: 'Late',
            permissions: const {
              'tasks': ['read_all'],
            },
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ),
        throwsArgumentError,
      );
      expect(adapterOf(dio).requests, isEmpty);
    });

    test('a create answer without the value is an unexpected response that '
        'quotes nothing', () async {
      final dio = fakeDio({
        '$_v2/tokens': json({
          'id': 5,
          'title': 'x',
          'token': '',
          'permissions': <String, Object?>{},
          'expires_at': '2099-01-01T00:00:00Z',
        }, status: 201),
      });

      await expectLater(
        _port(dio, 'v2').createApiToken(
          NewApiToken(
            title: 'x',
            permissions: const {
              'tasks': ['read_all'],
            },
            expiresAt: _farFuture,
          ),
        ),
        throwsA(
          isA<UnexpectedResponse>().having(
            (f) => f.message,
            'message',
            'created token without its value',
          ),
        ),
      );
    });
  });

  group('routes beyond the captures', () {
    test(r'keys that are not groups, like $schema, are skipped', () async {
      final dio = fakeDio({
        '$_v2/routes': json({
          r'$schema': 'http://localhost/api/v2/schemas/Routes.json',
          'tasks': {
            'read_all': {'path': '/api/v1/tasks', 'method': 'GET'},
            'update': {'path': '/api/v1/tasks/{id}', 'method': 'POST'},
          },
          'broken': 'x',
        }),
      });

      final groups = await _port(dio, 'v2').apiPermissions();

      expect(groups.groups, {
        'tasks': ['read_all', 'update'],
      });
    });
  });

  group('dataExport beyond the captures', () {
    test('without expires it is created plus seven days', () async {
      final dio = fakeDio({
        '$_v2/user/export': json({
          'id': 3,
          'size': 10,
          'created': '2026-10-21T06:19:21Z',
        }),
      });

      expect(
        (await _port(dio, 'v2').dataExport())!.expires,
        DateTime.utc(2026, 10, 28, 6, 19, 21),
      );
    });

    test('a null body sent as text is none', () async {
      final dio = fakeDio({
        '$_v2/user/export': (_) => ResponseBody.fromString(
          'null\n',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        ),
      });

      expect(await _port(dio, 'v2').dataExport(), isNull);
    });
  });
}
