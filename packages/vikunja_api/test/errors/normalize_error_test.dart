import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

const _url = 'https://vikunja.example/api/v1/anything';

Future<VikunjaFailure> _failureFor(
  FakeRoute route, {
  ResponseType responseType = ResponseType.json,
}) async {
  final dio = fakeDio({_url: route});
  try {
    await dio.get<Object?>(_url, options: Options(responseType: responseType));
  } on DioException catch (error) {
    return normalizeError(error);
  }
  fail('the request succeeded');
}

Matcher _oauth(OAuthProblem problem, int code) => isA<OAuthFailure>()
    .having((f) => f.problem, 'problem', problem)
    .having((f) => f.code, 'code', code)
    .having((f) => f.message, 'message', isNotEmpty);

final Matcher _tokenRejected = isA<TokenRejected>()
    .having((f) => f.code, 'code', 11)
    .having((f) => f.message, 'message', startsWith('missing, malformed'));

final Matcher _forbidden = isA<Forbidden>()
    .having((f) => f.code, 'code', isNull)
    .having((f) => f.message, 'message', contains('permission'));

/// What every captured body in test/fixtures/errors normalizes to. Named
/// `<api>_<what>_<server version>.json`.
Matcher _expectedFor(String name) {
  final parts = name.split('_');
  final api = parts.first;
  final version = parts.last;
  final what = parts.sublist(1, parts.length - 1).join('_');
  final before27 = version != '2.7.0';
  return switch (what) {
    '401_code11_garbage' || '401_code11_missing' => _tokenRejected,
    '403_project' => _forbidden,
    '404_project' =>
      isA<NotFound>()
          .having((f) => f.code, 'code', 3001)
          .having((f) => f.routeAbsent, 'routeAbsent', isFalse)
          .having((f) => f.message, 'message', 'This project does not exist.'),
    '404_route' =>
      isA<NotFound>()
          .having((f) => f.routeAbsent, 'routeAbsent', isTrue)
          .having((f) => f.message, 'message', 'Not Found'),
    '412_invalid_fields' =>
      isA<ValidationFailed>()
          .having((f) => f.code, 'code', 2002)
          .having((f) => f.fieldErrors.keys, 'fields', ['title'])
          .having(
            (f) => f.fieldErrors['title']!.single,
            'title message',
            endsWith('does not validate as runelength(1|250)'),
          ),
    '422_validation' =>
      isA<ValidationFailed>()
          .having((f) => f.fieldErrors, 'fieldErrors', {
            'title': ['expected length <= 250'],
          })
          .having((f) => f.message, 'message', 'validation failed'),
    '422_schema' => isA<ValidationFailed>().having(
      (f) => f.fieldErrors,
      'fieldErrors',
      {
        'title': ['expected string'],
      },
    ),
    // Huma validates the v2 create body; v1 reaches the model's own check.
    '422_title_empty' =>
      isA<ValidationFailed>()
          .having((f) => f.fieldErrors, 'fieldErrors', {
            'title': ['expected length >= 1'],
          })
          .having((f) => f.message, 'message', 'validation failed'),
    '400_title_empty' =>
      isA<DomainError>()
          .having((f) => f.statusCode, 'status', 400)
          .having((f) => f.code, 'code', 4001)
          .having(
            (f) => f.message,
            'message',
            'You must provide at least a task title.',
          ),
    '400_repeat_range' =>
      isA<DomainError>()
          .having((f) => f.statusCode, 'status', 400)
          .having((f) => f.code, 'code', 4029)
          .having((f) => f.message, 'message', startsWith('The task repeat')),
    '429_oauth_token' =>
      isA<RateLimited>()
          .having(
            (f) => f.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          )
          .having((f) => f.message, 'message', 'Too Many Requests'),
    'authorize_17002_redirect' || 'oauth_17002_redirect_mismatch' => _oauth(
      OAuthProblem.invalidRedirectUri,
      17002,
    ),
    'authorize_17003_pkce_missing' => _oauth(OAuthProblem.pkceMissing, 17003),
    'oauth_17001_client_mismatch' => _oauth(OAuthProblem.clientMismatch, 17001),
    'oauth_17004_code_used' => _oauth(OAuthProblem.codeInvalid, 17004),
    'oauth_17006_pkce_mismatch' => _oauth(OAuthProblem.pkceMismatch, 17006),
    'oauth_17007_grant' => _oauth(OAuthProblem.unsupportedGrant, 17007),
    // Huma turns the plain Echo error into a 500 on 2.7.0.
    'authorize_response_type' when api == 'v2' && !before27 =>
      isA<ServerFailure>().having((f) => f.statusCode, 'status', 500),
    'authorize_response_type' =>
      isA<UnexpectedResponse>()
          .having((f) => f.statusCode, 'status', 400)
          .having((f) => f.message, 'message', "response_type must be 'code'"),
    // Before 2.7.0 the refresh errors carry no code; OAuthTokenClient maps
    // them.
    'refresh_invalid' || 'refresh_race_401' when before27 =>
      isA<UnexpectedResponse>()
          .having((f) => f.statusCode, 'status', 401)
          .having(
            (f) => f.message,
            'message',
            'Invalid or expired refresh token.',
          ),
    'refresh_invalid' || 'refresh_race_401' =>
      isA<SessionEnded>()
          .having(
            (f) => f.reason,
            'reason',
            SessionEndReason.invalidRefreshToken,
          )
          .having((f) => f.code, 'code', 16002),
    'refresh_race_500' =>
      isA<ServerFailure>()
          .having((f) => f.statusCode, 'status', 500)
          .having((f) => f.code, 'code', isNull),
    _ => throw StateError('No expectation for the fixture $name'),
  };
}

void main() {
  group('captured error bodies', () {
    final names = [
      for (final file in Directory('test/fixtures/errors').listSync())
        if (file.path.endsWith('.json'))
          file.uri.pathSegments.last.replaceFirst('.json', ''),
    ]..sort();

    test('cover every shape', () {
      expect(names, hasLength(greaterThanOrEqualTo(80)));
      for (final shape in [
        'v1_401_code11_garbage_2.3.0',
        'v2_401_code11_garbage_2.7.0',
        'v2_404_project_2.7.0',
        'v2_422_validation_2.7.0',
        'v1_412_invalid_fields_2.7.0',
        'v1_429_oauth_token_2.3.0',
        'v2_429_oauth_token_2.7.0',
        'v1_oauth_17004_code_used_2.3.0',
        'v2_oauth_17006_pkce_mismatch_2.7.0',
        'v2_refresh_invalid_2.7.0',
      ]) {
        expect(names, contains(shape));
      }
    });

    for (final name in names) {
      test(name, () async {
        final expected = _expectedFor(name);

        expect(await _failureFor(errorFixture(name)), expected);
        expect(
          await _failureFor(
            errorFixture(name),
            responseType: ResponseType.bytes,
          ),
          expected,
          reason: 'undecoded bytes',
        );
        expect(
          await _failureFor(
            errorFixture(name),
            responseType: ResponseType.plain,
          ),
          expected,
          reason: 'undecoded text',
        );
      });
    }
  });

  group('responses without a captured body', () {
    FakeRoute body(int status, Object body, {Map<String, String>? headers}) =>
        (_) => ResponseBody.fromString(
          body is String ? body : jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
            for (final MapEntry(:key, :value) in (headers ?? {}).entries)
              key: [value],
          },
        );

    for (final (code, reason) in [
      (16002, SessionEndReason.invalidRefreshToken),
      (16003, SessionEndReason.expired),
      (16005, SessionEndReason.invalidRefreshToken),
    ]) {
      test('401 code $code ends the session', () async {
        expect(
          await _failureFor(
            body(401, {'code': code, 'message': 'Session expired.'}),
          ),
          isA<SessionEnded>()
              .having((f) => f.reason, 'reason', reason)
              .having((f) => f.code, 'code', code)
              .having((f) => f.message, 'message', 'Session expired.'),
        );
      });
    }

    test("v1's 400 code 13003 means a guest's link is gone", () async {
      expect(
        await _failureFor(
          capturedFixture('link_share/v1_projects_share_gone_2.7.0'),
        ),
        isA<LinkShareGone>()
            .having((f) => f.code, 'code', 13003)
            .having((f) => f.reason, 'reason', SessionEndReason.linkShareGone)
            .having((f) => f.message, 'message', isNotEmpty),
      );
    });

    test('401 code 16004 lost the rotation race', () async {
      expect(
        await _failureFor(
          body(401, {
            'status': 401,
            'title': 'Unauthorized',
            'detail': 'Refresh token already used.',
            'code': 16004,
          }),
        ),
        isA<RefreshRaceLost>().having((f) => f.code, 'code', 16004),
      );
    });

    for (final (code, reason) in [
      (1020, SessionEndReason.accountDisabled),
      (1040, SessionEndReason.accountLocked),
    ]) {
      test('412 code $code ends the session', () async {
        expect(
          await _failureFor(body(412, {'code': code, 'message': 'x'})),
          isA<SessionEnded>().having((f) => f.reason, 'reason', reason),
        );
      });
    }

    test('412 code 1026 stays a domain error', () async {
      expect(
        await _failureFor(body(412, {'code': 1026, 'message': 'reserved'})),
        isA<DomainError>()
            .having((f) => f.statusCode, 'status', 412)
            .having((f) => f.code, 'code', 1026),
      );
    });

    test('17005 is an expired code', () async {
      expect(
        await _failureFor(body(400, {'code': 17005, 'message': 'expired'})),
        _oauth(OAuthProblem.codeExpired, 17005),
      );
    });

    test(
      'a v2 401 without a code is unexpected, not a token rejection',
      () async {
        expect(
          await _failureFor(
            body(401, {
              'status': 401,
              'title': 'Unauthorized',
              'detail': 'invalid or missing authentication',
            }),
          ),
          isA<UnexpectedResponse>()
              .having((f) => f.statusCode, 'status', 401)
              .having((f) => f.message, 'message', contains('missing')),
        );
      },
    );

    test('a coded domain error keeps status, code and message', () async {
      expect(
        await _failureFor(
          body(400, {'code': 4029, 'message': 'Invalid repeat mode.'}),
        ),
        isA<DomainError>()
            .having((f) => f.statusCode, 'status', 400)
            .having((f) => f.code, 'code', 4029)
            .having((f) => f.message, 'message', 'Invalid repeat mode.'),
      );
    });

    test('a proxy 502 page is a server failure without a message', () async {
      expect(
        await _failureFor(html('<h1>502 Bad Gateway</h1>', status: 502)),
        isA<ServerFailure>()
            .having((f) => f.statusCode, 'status', 502)
            .having((f) => f.message, 'message', isEmpty),
      );
    });

    test('a proxy 403 page is forbidden', () async {
      expect(
        await _failureFor(html('<h1>Forbidden</h1>', status: 403)),
        isA<Forbidden>().having((f) => f.code, 'code', isNull),
      );
    });

    test('a 404 page from a proxy means the route is absent', () async {
      expect(
        await _failureFor(html('not here', status: 404)),
        isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', isTrue),
      );
    });

    test('an unknown status without a body is unexpected', () async {
      expect(
        await _failureFor(status(418)),
        isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 418),
      );
    });

    test('429 without any rate limit header has no retryAfter', () async {
      expect(
        await _failureFor(body(429, {'message': 'Too Many Requests'})),
        isA<RateLimited>().having((f) => f.retryAfter, 'retryAfter', isNull),
      );
    });
  });

  group('requests without a response', () {
    test('timeouts', () async {
      for (final build in [
        (RequestOptions r) => DioException.connectionTimeout(
          timeout: Duration.zero,
          requestOptions: r,
        ),
        (RequestOptions r) => DioException.receiveTimeout(
          timeout: Duration.zero,
          requestOptions: r,
        ),
        (RequestOptions r) =>
            DioException.sendTimeout(timeout: Duration.zero, requestOptions: r),
      ]) {
        expect(
          await _failureFor(failsWith(build)),
          isA<NetworkFailure>().having(
            (f) => f.problem,
            'problem',
            NetworkProblem.timeout,
          ),
        );
      }
    });

    test('a refused connection is unreachable', () async {
      expect(
        await _failureFor(refused),
        isA<NetworkFailure>()
            .having((f) => f.problem, 'problem', NetworkProblem.unreachable)
            .having((f) => f.cause, 'cause', isA<SocketException>()),
      );
    });

    test('a rejected certificate is a TLS problem', () async {
      expect(
        await _failureFor(
          failsWith(
            (r) => DioException.badCertificate(requestOptions: r, error: 'x'),
          ),
        ),
        isA<NetworkFailure>().having(
          (f) => f.problem,
          'problem',
          NetworkProblem.tls,
        ),
      );
    });

    test('a native TLS error text is a TLS problem', () async {
      expect(
        await _failureFor(
          failsWith(
            (r) => DioException.connectionError(
              requestOptions: r,
              reason: 'net::ERR_CERT_AUTHORITY_INVALID',
            ),
          ),
        ),
        isA<NetworkFailure>().having(
          (f) => f.problem,
          'problem',
          NetworkProblem.tls,
        ),
      );
    });

    test('a refused client certificate is a problem of its own', () async {
      expect(
        await _failureFor(
          throwing(
            HttpException(
              '\n\tTLSV1_ALERT_CERTIFICATE_REQUIRED(tls_record.cc:489) '
              'error 268436572',
              uri: Uri.parse('https://vikunja.example/api/v1/info'),
            ),
          ),
        ),
        isA<NetworkFailure>().having(
          (f) => f.problem,
          'problem',
          NetworkProblem.clientCertificate,
        ),
      );
    });

    test('a body that fails to decode is unexpected', () async {
      expect(
        await _failureFor(
          failsWith(
            (r) => DioException(
              requestOptions: r,
              error: const FormatException('Unexpected character', 'secret'),
            ),
          ),
        ),
        isA<UnexpectedResponse>().having(
          (f) => f.message,
          'message',
          isNot(contains('secret')),
        ),
      );
    });

    test('a cancellation is a programming error', () async {
      final exception = DioException.requestCancelled(
        requestOptions: RequestOptions(path: _url),
        reason: null,
      );
      expect(() => normalizeError(exception), throwsArgumentError);
    });
  });

  group('requests the connection settings stopped', () {
    const origin = 'https://vikunja.example:443';
    final cases = [
      (
        const CleartextBlockedException('http://vikunja.example:80'),
        NetworkProblem.cleartextBlocked,
      ),
      (
        const ConnectionProfileLockedException(origin),
        NetworkProblem.profileLocked,
      ),
      (
        const ConnectionProfileIncompleteException(origin),
        NetworkProblem.profileIncomplete,
      ),
      (
        const ConnectionProfilesDamagedException(),
        NetworkProblem.profileDamaged,
      ),
      (
        const ClientCertificateRefusedException(origin),
        NetworkProblem.clientCertificate,
      ),
    ];

    for (final (error, problem) in cases) {
      test('${error.runtimeType} is a network failure, so queued work '
          'waits', () async {
        final expected = isA<NetworkFailure>()
            .having((f) => f.problem, 'problem', problem)
            .having((f) => f.cause, 'cause', same(error));

        expect(
          await _failureFor(
            failsWith(
              (r) => DioException.connectionError(
                requestOptions: r,
                reason: 'refused by the connection settings',
                error: error,
              ),
            ),
          ),
          expected,
        );
        // Dio wraps what an adapter throws as is into an unknown error.
        expect(await _failureFor(throwing(error)), expected);
        expect(normalizeError(error), expected);
        expect(problem.concernsConnectionSettings, isTrue);
      });
    }
  });

  test('a failure passes through, also inside a DioException', () {
    const failure = SessionEnded(SessionEndReason.expired);
    expect(normalizeError(failure), same(failure));
    expect(
      normalizeError(
        DioException(
          requestOptions: RequestOptions(path: _url),
          error: failure,
        ),
      ),
      same(failure),
    );
  });

  test('anything else is unexpected and never quotes the error', () {
    expect(
      normalizeError(const FormatException('bad', 'eyJhbGciOi.secret')),
      isA<UnexpectedResponse>()
          .having((f) => f.statusCode, 'status', isNull)
          .having((f) => f.message, 'message', 'FormatException'),
    );
  });
}
