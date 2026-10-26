import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/jwt.dart';
import '../helpers/link_share_fixtures.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_link_share_fixtures.dart: the
// owner (445) shared project 1384 by the read link 87 ("Fixture guest") and
// the write link 88 with a password and no name, then deleted link 87.
final String _hash = 'Ab3' * 13 + 'z';
const _password = 'correct horse';

FakeRoute _captured(String name) => linkShareFixture('${name}_2.7.0');

LinkShareAuthClient _client(Dio dio, String version) =>
    LinkShareAuthClient(dio, testConnection(hasV2: version == 'v2'));

String _api(String version) => '$testServerRoot/api/$version';

Matcher _gone(int? code) =>
    isA<LinkShareGone>().having((f) => f.code, 'code', code);

void main() {
  for (final version in ['v1', 'v2']) {
    group('$version authenticate', () {
      final url = '${_api(version)}/shares/$_hash/auth';

      test('an open link: its token, project, permission and name', () async {
        final dio = fakeDio({url: _captured('${version}_auth_open')});

        final auth = await _client(dio, version).authenticate(_hash);

        final request = adapterOf(dio).requests.single;
        expect(request.method, 'POST');
        expect(request.uri.toString(), url);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.followRedirects, isFalse);
        expect(adapterOf(dio).decodedBodies, [<String, Object?>{}]);
        expect(auth.token.jwt, recordedToken('${version}_auth_open_2.7.0'));
        expect(auth.shareId, 87);
        expect(auth.projectId, 1384);
        expect(auth.permission, Permission.read);
        expect(auth.name, 'Fixture guest');
        expect(auth.token.claims.projectId, 1384);
      });

      test('a password link with its password; no name is null', () async {
        final dio = fakeDio({url: _captured('${version}_auth_password')});

        final auth = await _client(
          dio,
          version,
        ).authenticate(_hash, password: _password);

        expect(adapterOf(dio).decodedBodies, [
          {'password': _password},
        ]);
        expect(auth.shareId, 88);
        expect(auth.permission, Permission.write);
        expect(auth.name, isNull);
      });

      test('an empty password is not sent', () async {
        final dio = fakeDio({url: _captured('${version}_auth_open')});

        await _client(dio, version).authenticate(_hash, password: '');

        expect(adapterOf(dio).decodedBodies, [<String, Object?>{}]);
      });

      test('a password missing is 412 code 13001', () async {
        final dio = fakeDio({
          url: _captured('${version}_auth_password_missing'),
        });

        await expectLater(
          _client(dio, version).authenticate(_hash),
          throwsA(
            isA<DomainError>()
                .having((f) => f.statusCode, 'status', 412)
                .having((f) => f.code, 'code', 13001),
          ),
        );
      });

      test('a wrong password is a Forbidden code 13002', () async {
        final dio = fakeDio({url: _captured('${version}_auth_password_wrong')});

        await expectLater(
          _client(dio, version).authenticate(_hash, password: 'nope'),
          throwsA(isA<Forbidden>().having((f) => f.code, 'code', 13002)),
        );
      });

      test('an unknown or deleted link is gone (3006)', () async {
        final dio = fakeDio({url: _captured('${version}_auth_unknown')});

        await expectLater(
          _client(dio, version).authenticate(_hash),
          throwsA(_gone(3006)),
        );
      });

      test('without the route (link sharing off) it is gone too', () async {
        final dio = fakeDio({url: errorFixture('v1_404_route_2.7.0')});

        await expectLater(
          _client(dio, version).authenticate(_hash),
          throwsA(_gone(null)),
        );
      });

      test('the shared limit is RateLimited with its wait', () async {
        final dio = fakeDio({url: errorFixture('v1_429_oauth_token_2.7.0')});

        await expectLater(
          _client(dio, version).authenticate(_hash),
          throwsA(
            isA<RateLimited>().having(
              (f) => f.retryAfter,
              'retryAfter',
              const Duration(seconds: 60),
            ),
          ),
        );
      });
    });
  }

  group('authenticate answers', () {
    final url = '${_api('v2')}/shares/$_hash/auth';

    test('the hash is escaped as a path segment', () async {
      final dio = fakeDio({
        '${_api('v2')}/shares/a%2Fb/auth': _captured('v2_auth_open'),
      });

      await _client(dio, 'v2').authenticate('a/b');

      expect(adapterOf(dio).requests, hasLength(1));
    });

    test('a token that is not a link share token is unexpected', () async {
      final dio = fakeDio({
        url: json({'token': fakeJwt(), 'project_id': 3, 'permission': 0}),
      });

      await expectLater(
        _client(dio, 'v2').authenticate(_hash),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('project and permission fall back to the token', () async {
      final dio = fakeDio({
        url: json({
          'token': fakeLinkShareJwt(id: 4, projectId: 6, permission: 2),
        }),
      });

      final auth = await _client(dio, 'v2').authenticate(_hash);

      expect(auth.shareId, 4);
      expect(auth.projectId, 6);
      expect(auth.permission, Permission.admin);
      expect(auth.name, isNull);
    });

    test('no connection is a NetworkFailure', () async {
      final dio = fakeDio({});

      await expectLater(
        _client(dio, 'v2').authenticate(_hash),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a cancelled request stays a DioException', () async {
      final dio = fakeDio({
        url: failsWith(
          (request) => DioException.requestCancelled(
            requestOptions: request,
            reason: 'gone',
          ),
        ),
      });

      await expectLater(
        _client(dio, 'v2').authenticate(_hash),
        throwsA(isA<DioException>()),
      );
    });

    test('toString names neither token nor name', () async {
      final dio = fakeDio({url: _captured('v2_auth_open')});

      final auth = await _client(dio, 'v2').authenticate(_hash);

      expect('$auth', 'LinkShareAuth(share: 87, project: 1384, read)');
      expect('${auth.token}', isNot(contains(auth.token.jwt)));
      expect('${auth.token}', startsWith('LinkShareToken(share: 87, '));
    });
  });

  for (final version in ['v1', 'v2']) {
    group('$version renew', () {
      final url = '${_api(version)}/user/token';
      final current = fakeLinkShareJwt(id: 87, projectId: 1384, permission: 0);

      test('a new token for the same link, with the old as bearer', () async {
        final dio = fakeDio({url: _captured('${version}_renew')});

        final renewed = await _client(dio, version).renew(current);

        final request = adapterOf(dio).requests.single;
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer $current');
        expect(request.followRedirects, isFalse);
        expect(adapterOf(dio).requestBodies, [isNull]);
        expect(renewed.jwt, recordedToken('${version}_renew_2.7.0'));
        expect(renewed.claims.shareId, 87);
        expect(renewed.claims.projectId, 1384);
      });

      test('an expired token is rejected (401 code 11)', () async {
        final dio = fakeDio({url: _captured('${version}_renew_not_a_jwt')});

        await expectLater(
          _client(dio, version).renew(current),
          throwsA(isA<TokenRejected>()),
        );
      });

      test('a deleted link is gone', () async {
        final dio = fakeDio({url: _captured('${version}_renew_share_gone')});

        await expectLater(
          _client(dio, version).renew(current),
          throwsA(_gone(version == 'v1' ? 3006 : null)),
        );
      });

      test("a user's token is refused with a 400", () async {
        final dio = fakeDio({url: _captured('${version}_renew_user_token')});

        await expectLater(
          _client(dio, version).renew(fakeJwt()),
          throwsA(
            isA<UnexpectedResponse>().having(
              (f) => f.statusCode,
              'status',
              400,
            ),
          ),
        );
      });
    });
  }

  test('v1 renew answered 13003 is gone too', () async {
    final dio = fakeDio({
      '${_api('v1')}/user/token': _captured('v1_projects_share_gone'),
    });

    await expectLater(
      _client(dio, 'v1').renew(fakeLinkShareJwt()),
      throwsA(_gone(13003)),
    );
  });

  test('the request never follows a redirect', () async {
    final dio = fakeDio({
      '${_api('v2')}/user/token': redirect('https://elsewhere.example/'),
    });

    await expectLater(
      _client(dio, 'v2').renew(fakeLinkShareJwt()),
      throwsA(isA<VikunjaFailure>()),
    );
    expect(adapterOf(dio).requests, hasLength(1));
  });

  test('a timeout applies to sending and receiving', () async {
    final dio = fakeDio({
      '${_api('v2')}/user/token': failsWith(
        (request) => DioException.receiveTimeout(
          timeout: request.receiveTimeout!,
          requestOptions: request,
        ),
      ),
    });
    final client = LinkShareAuthClient(
      dio,
      testConnection(),
      timeout: const Duration(seconds: 3),
    );

    await expectLater(
      client.renew(fakeLinkShareJwt()),
      throwsA(
        isA<NetworkFailure>().having(
          (f) => f.problem,
          'problem',
          NetworkProblem.timeout,
        ),
      ),
    );
    final request = adapterOf(dio).requests.single;
    expect(request.sendTimeout, const Duration(seconds: 3));
    expect(request.receiveTimeout, const Duration(seconds: 3));
  });

  test('a SocketException is unreachable', () async {
    final dio = fakeDio({
      '${_api('v2')}/user/token': throwing(const SocketException('down')),
    });

    await expectLater(
      _client(dio, 'v2').renew(fakeLinkShareJwt()),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
