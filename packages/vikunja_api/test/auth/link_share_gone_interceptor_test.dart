import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_token_source.dart';
import '../helpers/jwt.dart';
import '../helpers/link_share_fixtures.dart';
import '../helpers/server_connection.dart';

// A guest's token after the owner deleted its link: v1 answers 400 code
// 13003, v2 401 without a code (tool/capture_link_share_fixtures.dart).
String _projects(String version) =>
    '$testServerRoot/api/$version/projects?page=1&expand=permissions';

({ProjectsPort projects, FakeTokenSource tokens, List<LinkShareGone> gone})
_guest(
  String version,
  FakeRoute answer, {
  String? token,
  Future<LinkShareGone?> Function(String token)? confirmGone,
}) {
  final gone = <LinkShareGone>[];
  final connection = testConnection(hasV2: version == 'v2');
  final tokens = FakeTokenSource(current: token ?? fakeLinkShareJwt());
  final dio = createAuthenticatedDio(
    base: fakeDio({_projects(version): answer}),
    connection: connection,
    tokens: tokens,
    retry: (dio) => RetryInterceptor(dio, delay: (_) async {}),
    interceptors: [
      LinkShareGoneInterceptor(onGone: gone.add, confirmGone: confirmGone),
    ],
  );
  return (
    projects: createReadClient(dio: dio, connection: connection).projects,
    tokens: tokens,
    gone: gone,
  );
}

void main() {
  test('v1 400 code 13003 for a guest is gone', () async {
    final guest = _guest(
      'v1',
      linkShareFixture('v1_projects_share_gone_2.7.0'),
    );

    await expectLater(
      guest.projects.list(),
      throwsA(isA<LinkShareGone>().having((f) => f.code, 'code', 13003)),
    );
    expect(guest.gone, [isA<LinkShareGone>()]);
    expect(guest.tokens.rejectedTokens, isEmpty);
  });

  test('v2 401 without a code for a guest is gone', () async {
    final guest = _guest(
      'v2',
      linkShareFixture('v2_projects_share_gone_2.7.0'),
    );

    await expectLater(
      guest.projects.list(),
      throwsA(isA<LinkShareGone>().having((f) => f.code, 'code', isNull)),
    );
    expect(guest.gone, hasLength(1));
    expect(guest.tokens.rejectedTokens, isEmpty);
  });

  test("a user's 401 without a code stays what it was", () async {
    final user = _guest(
      'v2',
      linkShareFixture('v2_projects_share_gone_2.7.0'),
      token: fakeJwt(),
    );

    await expectLater(
      user.projects.list(),
      throwsA(
        isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 401),
      ),
    );
    expect(user.gone, isEmpty);
  });

  test("a user's 13003 is mapped without calling back", () async {
    final user = _guest(
      'v1',
      linkShareFixture('v1_projects_share_gone_2.7.0'),
      token: fakeJwt(),
    );

    await expectLater(user.projects.list(), throwsA(isA<LinkShareGone>()));
    expect(user.gone, isEmpty);
  });

  test('an expired guest token still goes to the token source', () async {
    final guest = _guest('v2', errorFixture('v2_401_code11_garbage_2.7.0'));
    guest.tokens.nextAfterRejection = null;

    await expectLater(guest.projects.list(), throwsA(isA<TokenRejected>()));
    expect(guest.tokens.rejectedTokens, hasLength(1));
    expect(guest.gone, isEmpty);
  });

  test("a guest's other refusals are left alone", () async {
    for (final (version, answer, matcher) in [
      ('v1', errorFixture('v1_403_project_2.7.0'), isA<Forbidden>()),
      (
        'v1',
        json({'code': 1027, 'message': 'Invalid user context.'}, status: 401),
        isA<DomainError>().having((f) => f.code, 'code', 1027),
      ),
      (
        'v1',
        json({'message': 'Invalid JWT token.'}, status: 400),
        isA<UnexpectedResponse>(),
      ),
    ]) {
      final guest = _guest(version, answer);

      await expectLater(guest.projects.list(), throwsA(matcher));
      expect(guest.gone, isEmpty);
    }
  });

  group("v1's 500 to a gone share's token before 2.7", () {
    final serverError = json({
      'message': 'Could not determine the current user.',
    }, status: 500);

    test('is gone once confirmGone confirms it with that token', () async {
      final token = fakeLinkShareJwt();
      final asked = <String>[];
      final guest = _guest(
        'v1',
        serverError,
        token: token,
        confirmGone: (token) async {
          asked.add(token);
          return const LinkShareGone(code: 3006);
        },
      );

      await expectLater(
        guest.projects.list(),
        throwsA(isA<LinkShareGone>().having((f) => f.code, 'code', 3006)),
      );
      expect(asked, [token]);
      expect(guest.gone, hasLength(1));
    });

    test('stays a server failure when confirmGone does not confirm '
        'it', () async {
      final guest = _guest('v1', serverError, confirmGone: (_) async => null);

      await expectLater(
        guest.projects.list(),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 's', 500)),
      );
      expect(guest.gone, isEmpty);
    });

    test('stays a server failure without confirmGone', () async {
      final guest = _guest('v1', serverError);

      await expectLater(guest.projects.list(), throwsA(isA<ServerFailure>()));
      expect(guest.gone, isEmpty);
    });

    test("is never asked about for a user's token or another "
        'status', () async {
      final asked = <String>[];
      Future<LinkShareGone?> confirm(String token) async {
        asked.add(token);
        return const LinkShareGone(code: 3006);
      }

      for (final (answer, token) in [
        (serverError, fakeJwt()),
        (json({'message': 'down'}, status: 501), null),
        (json({'message': 'busy'}, status: 503), null),
      ]) {
        final guest = _guest('v1', answer, token: token, confirmGone: confirm);

        await expectLater(guest.projects.list(), throwsA(isA<ServerFailure>()));
        expect(guest.gone, isEmpty);
      }
      expect(asked, isEmpty);
    });
  });

  test('a streamed error body is read to find the code', () async {
    final gone = <LinkShareGone>[];
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter({
        '$testServerRoot/file': (_) => ResponseBody.fromString(
          jsonEncode({'code': 13003, 'message': 'invalid'}),
          400,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      })
      ..interceptors.add(LinkShareGoneInterceptor(onGone: gone.add));

    await expectLater(
      dio.get<ResponseBody>(
        '$testServerRoot/file',
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Authorization': 'Bearer ${fakeLinkShareJwt()}'},
        ),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<LinkShareGone>(),
        ),
      ),
    );
    expect(gone, hasLength(1));
  });

  test('without a callback it only maps', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeHttpAdapter({
        '$testServerRoot/x': linkShareFixture('v2_projects_share_gone_2.7.0'),
      })
      ..interceptors.add(LinkShareGoneInterceptor());

    await expectLater(
      dio.get<Object?>(
        '$testServerRoot/x',
        options: Options(
          headers: {'Authorization': 'Bearer ${fakeLinkShareJwt()}'},
        ),
      ),
      throwsA(
        isA<DioException>().having(
          normalizeError,
          'failure',
          isA<LinkShareGone>(),
        ),
      ),
    );
  });
}
