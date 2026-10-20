import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_token_source.dart';

const _api = 'https://tasks.example.com/vikunja/api/v2';
const _userUrl = '$_api/user';

ServerConnection _connection() {
  const info = ServerInfo(version: ServerVersion(2, 7, 0));
  const apiVersions = {ApiVersion.v1, ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse('https://tasks.example.com/vikunja'),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

/// Accepts only `Bearer <validToken>` and answers anything else like
/// Vikunja's JWT middleware.
FakeRoute _protected({String validToken = 'fresh', Object? body}) => (request) {
  if (request.headers['Authorization'] == 'Bearer $validToken') {
    return json(body ?? {'id': 1})(request);
  }
  return errorFixtureBody('v2_401_code11_garbage_2.7.0');
};

({Dio dio, Dio base, FakeTokenSource tokens}) _client(
  Map<String, FakeRoute> routes, {
  String current = 'stale',
  String? nextAfterRejection = 'fresh',
}) {
  final base = fakeDio(routes);
  final tokens = FakeTokenSource(
    current: current,
    nextAfterRejection: nextAfterRejection,
  );
  final dio = createAuthenticatedDio(
    base: base,
    connection: _connection(),
    tokens: tokens,
    retry: (dio) => RetryInterceptor(dio, delay: (_) async {}),
  );
  return (dio: dio, base: base, tokens: tokens);
}

List<RequestOptions> _sent(Dio base) => adapterOf(base).requests;

/// A code 11 body of 128 KiB, so only reading all of it finds the code.
Stream<Uint8List> _oversizedBytes() => Stream.fromIterable([
  Uint8List.fromList(utf8.encode('{"code":11,"message":"')),
  for (var i = 0; i < 8; i++)
    Uint8List(16 * 1024)..fillRange(0, 16 * 1024, 0x78),
  Uint8List.fromList(utf8.encode('"}')),
]);

Stream<Uint8List> _brokenOffBytes() async* {
  yield Uint8List.fromList(utf8.encode('{"code":11,'));
  throw const SocketException('Connection reset by peer');
}

Future<VikunjaFailure> _failure(Future<Object?> request) async {
  try {
    await request;
  } on DioException catch (error) {
    return normalizeError(error);
  }
  fail('the request succeeded');
}

void main() {
  test('every request carries the token the source considers valid', () async {
    final (:dio, :base, :tokens) = _client({
      _userUrl: _protected(validToken: 'stale'),
    });

    await dio.get<Object?>('user');
    await dio.get<Object?>('/user');

    expect(tokens.validAccessTokenCalls, 2);
    expect(
      [for (final request in _sent(base)) request.headers['Authorization']],
      ['Bearer stale', 'Bearer stale'],
    );
    expect(_sent(base).map((r) => '${r.uri}'), [_userUrl, _userUrl]);
  });

  test('401 code 11 refreshes once and repeats the request once', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});

    final response = await dio.get<Object?>('user');

    expect(response.statusCode, 200);
    expect(tokens.rejectedTokens, ['stale']);
    expect(
      [for (final request in _sent(base)) request.headers['Authorization']],
      ['Bearer stale', 'Bearer fresh'],
    );
  });

  test(
    'a POST is repeated with its body, as the server did not run it',
    () async {
      final (:dio, :base, :tokens) = _client({'$_api/logout': _protected()});

      await dio.post<Object?>('logout', data: {'keep': 'me'});

      expect(_sent(base), hasLength(2));
      expect(_sent(base).last.method, 'POST');
      expect(_sent(base).last.data, {'keep': 'me'});
      expect(tokens.rejectedTokens, ['stale']);
    },
  );

  test('multipart bodies are rebuilt for the repeat', () async {
    final (:dio, :base, tokens: _) = _client({'$_api/upload': _protected()});

    await dio.put<Object?>(
      'upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'a.bin'),
      }),
    );

    expect(_sent(base), hasLength(2));
    expect(_sent(base).first.data, isNot(same(_sent(base).last.data)));
  });

  test('a rejected repeat is not refreshed again', () async {
    final (:dio, :base, :tokens) = _client({
      _userUrl: _protected(validToken: 'never'),
    });

    expect(await _failure(dio.get<Object?>('user')), isA<TokenRejected>());
    expect(tokens.rejectedTokens, ['stale']);
    expect(_sent(base), hasLength(2));
  });

  test('without a newer token the rejection stands', () async {
    final (:dio, :base, :tokens) = _client({
      _userUrl: _protected(),
    }, nextAfterRejection: null);

    expect(await _failure(dio.get<Object?>('user')), isA<TokenRejected>());
    expect(tokens.rejectedTokens, ['stale']);
    expect(_sent(base), hasLength(1));
  });

  test('the same token again is not worth a repeat', () async {
    final (:dio, :base, tokens: _) = _client({
      _userUrl: _protected(),
    }, nextAfterRejection: 'stale');

    expect(await _failure(dio.get<Object?>('user')), isA<TokenRejected>());
    expect(_sent(base), hasLength(1));
  });

  test('a refresh that ends the session reports that', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});
    tokens.refreshFailure = const SessionEnded(SessionEndReason.expired);

    expect(
      await _failure(dio.get<Object?>('user')),
      isA<SessionEnded>().having(
        (f) => f.reason,
        'reason',
        SessionEndReason.expired,
      ),
    );
    expect(_sent(base), hasLength(1));
  });

  for (final (description, route) in [
    ('a 401 without a code', json({'message': 'nope'}, status: 401)),
    ('a 401 of the refresh endpoint', errorFixture('v2_refresh_invalid_2.7.0')),
    ('a 403', errorFixture('v2_403_project_2.7.0')),
  ]) {
    test('$description is not refreshed', () async {
      final (:dio, :base, :tokens) = _client({_userUrl: route});

      await _failure(dio.get<Object?>('user'));

      expect(tokens.rejectedTokens, isEmpty);
      expect(_sent(base), hasLength(1));
    });
  }

  test('a stream body cannot be repeated', () async {
    final (:dio, :base, :tokens) = _client({'$_api/upload': _protected()});

    await _failure(
      dio.put<Object?>(
        'upload',
        data: Stream.value([1, 2, 3]),
        options: Options(headers: {Headers.contentLengthHeader: 3}),
      ),
    );

    expect(tokens.rejectedTokens, isEmpty);
    expect(_sent(base), hasLength(1));
  });

  test('a body read once refreshes the token but is not repeated', () async {
    final (:dio, :base, :tokens) = _client({'$_api/upload': _protected()});

    final failure = await _failure(
      dio.put<Object?>(
        'upload',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes([1, 2, 3], filename: 'a.bin'),
        }),
        options: Options(extra: {AuthInterceptor.bodyReadOnceKey: true}),
      ),
    );

    expect(failure, isA<TokenRejected>());
    expect(tokens.rejectedTokens, ['stale']);
    expect(tokens.current, 'fresh');
    expect(_sent(base), hasLength(1));
  });

  test('a stream response is refreshed and repeated as well', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});

    final response = await dio.get<ResponseBody>(
      'user',
      options: Options(responseType: ResponseType.stream),
    );

    expect(response.statusCode, 200);
    expect(response.data, isA<ResponseBody>());
    expect(tokens.rejectedTokens, ['stale']);
    expect(
      [for (final request in _sent(base)) request.headers['Authorization']],
      ['Bearer stale', 'Bearer fresh'],
    );
  });

  test('a rejected stream response is a rejected token', () async {
    final (:dio, base: _, tokens: _) = _client({
      _userUrl: _protected(),
    }, nextAfterRejection: null);

    expect(
      await _failure(
        dio.get<ResponseBody>(
          'user',
          options: Options(responseType: ResponseType.stream),
        ),
      ),
      isA<TokenRejected>(),
    );
  });

  for (final (description, body) in [
    ('an oversized', _oversizedBytes),
    ('a broken off', _brokenOffBytes),
  ]) {
    test('$description stream error body is not refreshed', () async {
      final (:dio, :base, :tokens) = _client({
        _userUrl: (_) => ResponseBody(body(), 401),
      });

      expect(
        await _failure(
          dio.get<ResponseBody>(
            'user',
            options: Options(responseType: ResponseType.stream),
          ),
        ),
        isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 401),
      );
      expect(tokens.rejectedTokens, isEmpty);
      expect(_sent(base), hasLength(1));
    });
  }

  test('without a valid token nothing is sent', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});
    tokens.validAccessTokenFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );

    expect(await _failure(dio.get<Object?>('user')), isA<NetworkFailure>());
    expect(_sent(base), isEmpty);
    expect(tokens.validAccessTokenCalls, 1, reason: 'not retried');
  });

  for (final url in [
    'https://evil.example/vikunja/api/v2/user',
    'http://tasks.example.com/vikunja/api/v2/user',
    'https://tasks.example.com:8443/vikunja/api/v2/user',
    'https://tasks.example.com/other-app/api/v2/user',
    'https://tasks.example.com/vikunjax/api/v2/user',
    'https://tasks.example.com.evil.example/vikunja/api/v2/user',
  ]) {
    test('no bearer for $url', () async {
      final (:dio, :base, :tokens) = _client({url: json({})});

      await dio.get<Object?>(url);

      expect(_sent(base).single.headers.containsKey('Authorization'), isFalse);
      expect(tokens.validAccessTokenCalls, 0);
    });
  }

  test(
    'the server root itself and the default port count as the server',
    () async {
      const explicitPort = 'https://tasks.example.com:443/vikunja/api/v2/user';
      final (:dio, :base, tokens: _) = _client({
        _userUrl: json({}),
        'https://tasks.example.com/vikunja': json({}),
      });

      await dio.get<Object?>(explicitPort);
      await dio.get<Object?>('https://tasks.example.com/vikunja');

      expect(
        [for (final request in _sent(base)) request.headers['Authorization']],
        ['Bearer stale', 'Bearer stale'],
      );
    },
  );

  test('a request with its own Authorization header is left alone', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});

    await _failure(
      dio.get<Object?>(
        'user',
        options: Options(headers: {'authorization': 'Bearer tk_own'}),
      ),
    );

    expect(_sent(base).single.headers['Authorization'], 'Bearer tk_own');
    expect(tokens.validAccessTokenCalls, 0);
    expect(tokens.rejectedTokens, isEmpty);
  });

  test('a request with the token never follows a redirect', () async {
    final (:dio, :base, tokens: _) = _client({_userUrl: json({})});

    await dio.get<Object?>('user', options: Options(followRedirects: true));

    expect(_sent(base).single.followRedirects, isFalse);
  });

  test('a retried GET asks for a valid token again', () async {
    final (:dio, :base, :tokens) = _client({
      _userUrl: sequence([status(503), json({})]),
    });

    await dio.get<Object?>('user');
    expect(tokens.validAccessTokenCalls, 2);
    expect(_sent(base), hasLength(2));
  });

  test('a repeat that hits a 503 is retried with the fresh token', () async {
    final (:dio, :base, :tokens) = _client({
      _userUrl: sequence([
        errorFixture('v2_401_code11_garbage_2.7.0'),
        status(503),
        _protected(),
      ]),
    });

    final response = await dio.get<Object?>('user');

    expect(response.statusCode, 200);
    expect(tokens.rejectedTokens, ['stale']);
    expect(
      [for (final request in _sent(base)) request.headers['Authorization']],
      ['Bearer stale', 'Bearer fresh', 'Bearer fresh'],
    );
  });

  test('concurrent rejections each ask the source', () async {
    final (:dio, :base, :tokens) = _client({_userUrl: _protected()});

    await Future.wait([dio.get<Object?>('user'), dio.get<Object?>('user')]);

    expect(tokens.rejectedTokens, ['stale', 'stale']);
  });
}
