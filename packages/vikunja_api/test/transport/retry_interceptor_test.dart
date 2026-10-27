import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

const _url = 'https://tasks.example.com/api/v2/tasks';

final class _Delays {
  final waited = <Duration>[];

  Future<void> call(Duration delay) async => waited.add(delay);
}

final class _FixedRandom implements Random {
  new(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

// Like the http `ClientException`s of cronet_http and cupertino_http.
final class _NativeClientException implements Exception {
  const new(this.description);

  final String description;

  @override
  String toString() => description;
}

({Dio dio, _Delays delays}) _client(
  FakeRoute route, {
  Duration maxRetryAfter = const Duration(seconds: 30),
  int maxRetries = 2,
  double random = 0.5,
  RetryDelay? delay,
}) {
  final delays = _Delays();
  final dio = fakeDio({_url: route});
  dio.interceptors.add(
    RetryInterceptor(
      dio,
      maxRetries: maxRetries,
      maxRetryAfter: maxRetryAfter,
      delay: delay ?? delays.call,
      random: _FixedRandom(random),
    ),
  );
  return (dio: dio, delays: delays);
}

Future<VikunjaFailure> _failure(Future<Object?> request) async {
  try {
    await request;
  } on DioException catch (error) {
    return normalizeError(error);
  }
  fail('the request succeeded');
}

FakeRoute _withRetryAfter(int status, String retryAfter) =>
    (_) => ResponseBody.fromString(
      '{"message":"Too Many Requests"}',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'retry-after': [retryAfter],
      },
    );

void main() {
  test('a GET is retried twice with exponential backoff', () async {
    final (:dio, :delays) = _client(
      sequence([
        status(503),
        status(503),
        json({'ok': true}),
      ]),
      random: 1,
    );

    final response = await dio.get<Object?>(_url);

    expect(response.data, {'ok': true});
    expect(adapterOf(dio).requests, hasLength(3));
    expect(delays.waited, [
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 1000),
    ]);
  });

  test('jitter takes at most half of the backoff away', () async {
    final (:dio, :delays) = _client(
      sequence([status(502), status(504), json({})]),
      random: 0,
    );

    await dio.get<Object?>(_url);

    expect(delays.waited, [
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 500),
    ]);
  });

  test('after two retries the last failure is reported', () async {
    final (:dio, :delays) = _client(status(503));

    expect(
      await _failure(dio.get<Object?>(_url)),
      isA<ServerFailure>().having((f) => f.statusCode, 'status', 503),
    );
    expect(adapterOf(dio).requests, hasLength(3));
    expect(delays.waited, hasLength(2));
  });

  test('a HEAD is retried', () async {
    final (:dio, delays: _) = _client(sequence([status(503), status(200)]));

    await dio.head<Object?>(_url);

    expect(adapterOf(dio).requests, hasLength(2));
  });

  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    test('a $method is never retried', () async {
      final (:dio, :delays) = _client(sequence([status(503), json({})]));

      await _failure(
        dio.request<Object?>(_url, options: Options(method: method)),
      );

      expect(adapterOf(dio).requests, hasLength(1));
      expect(delays.waited, isEmpty);
    });
  }

  for (final code in [400, 401, 403, 404, 412, 422, 500]) {
    test('a $code is not retried', () async {
      final (:dio, delays: _) = _client(status(code));

      await _failure(dio.get<Object?>(_url));

      expect(adapterOf(dio).requests, hasLength(1));
    });
  }

  test('429 waits as long as Retry-After asks', () async {
    final (:dio, :delays) = _client(
      sequence([_withRetryAfter(429, '7'), json({})]),
    );

    await dio.get<Object?>(_url);

    expect(delays.waited, [const Duration(seconds: 7)]);
  });

  test('503 with Retry-After waits for it', () async {
    final (:dio, :delays) = _client(
      sequence([_withRetryAfter(503, '3'), json({})]),
    );

    await dio.get<Object?>(_url);

    expect(delays.waited, [const Duration(seconds: 3)]);
  });

  test('a Retry-After above the cap goes to the caller', () async {
    final (:dio, :delays) = _client(_withRetryAfter(429, '120'));

    expect(
      await _failure(dio.get<Object?>(_url)),
      isA<RateLimited>().having(
        (f) => f.retryAfter,
        'retryAfter',
        const Duration(seconds: 120),
      ),
    );
    expect(adapterOf(dio).requests, hasLength(1));
    expect(delays.waited, isEmpty);
  });

  test('the cap is configurable', () async {
    final (:dio, :delays) = _client(
      sequence([_withRetryAfter(429, '120'), json({})]),
      maxRetryAfter: const Duration(minutes: 10),
    );

    await dio.get<Object?>(_url);

    expect(delays.waited, [const Duration(seconds: 120)]);
  });

  test('429 of 2.3.0 waits until X-RateLimit-Reset', () async {
    final (:dio, :delays) = _client(
      sequence([errorFixture('v1_429_oauth_token_2.3.0'), json({})]),
      maxRetryAfter: const Duration(minutes: 2),
    );

    await dio.get<Object?>(_url);

    expect(delays.waited, [const Duration(seconds: 60)]);
  });

  test('a refused connection is retried', () async {
    final (:dio, delays: _) = _client(sequence([refused, json({})]));

    await dio.get<Object?>(_url);

    expect(adapterOf(dio).requests, hasLength(2));
  });

  test('a refused connection of a native adapter is retried', () async {
    final (:dio, delays: _) = _client(
      sequence([
        throwing(
          const _NativeClientException(
            'NetworkClientException: net::ERR_CONNECTION_REFUSED, '
            'uri=$_url, errorCode=7, cronetInternalErrorCode=-102, '
            'immediatelyRetryable=false',
          ),
        ),
        json({}),
      ]),
    );

    await dio.get<Object?>(_url);

    expect(adapterOf(dio).requests, hasLength(2));
  });

  test('a timeout is retried', () async {
    final (:dio, delays: _) = _client(
      sequence([
        failsWith(
          (r) => DioException.receiveTimeout(
            timeout: Duration.zero,
            requestOptions: r,
          ),
        ),
        json({}),
      ]),
    );

    await dio.get<Object?>(_url);

    expect(adapterOf(dio).requests, hasLength(2));
  });

  for (final (description, route) in [
    (
      'a rejected certificate',
      failsWith(
        (r) => DioException.badCertificate(requestOptions: r, error: 'x'),
      ),
    ),
    (
      'a TLS handshake failure',
      failsWith(
        (r) => DioException.connectionError(
          requestOptions: r,
          reason: 'HandshakeException: Handshake error in client',
        ),
      ),
    ),
    (
      'a certificate failure of a native adapter',
      throwing(
        const _NativeClientException(
          'NSErrorClientException: The certificate for this server is '
          'invalid. [domain=NSURLErrorDomain, code=-1202], uri=$_url',
        ),
      ),
    ),
    (
      'a refused client certificate of a native adapter',
      throwing(
        const _NativeClientException(
          'NetworkClientException: net::ERR_BAD_SSL_CLIENT_AUTH_CERT, '
          'uri=$_url, errorCode=11, cronetInternalErrorCode=-117, '
          'immediatelyRetryable=false',
        ),
      ),
    ),
    for (final error in <Exception>[
      const CleartextBlockedException('http://tasks.example.com:80'),
      const ConnectionProfileLockedException('https://tasks.example.com:443'),
      const ConnectionProfileIncompleteException(
        'https://tasks.example.com:443',
      ),
      const ConnectionProfilesDamagedException(),
      const ClientCertificateRefusedException('https://tasks.example.com:443'),
    ])
      (
        'a request the connection settings stopped '
            '(${error.runtimeType})',
        failsWith(
          (r) => DioException.connectionError(
            requestOptions: r,
            reason: 'refused by the connection settings',
            error: error,
          ),
        ),
      ),
    (
      'an undecodable body',
      failsWith(
        (r) => DioException(
          requestOptions: r,
          error: const FormatException('Unexpected character'),
        ),
      ),
    ),
    (
      'a failure from the token source',
      failsWith(
        (r) => DioException(
          requestOptions: r,
          error: const NetworkFailure(NetworkProblem.unreachable),
        ),
      ),
    ),
  ]) {
    test('$description is not retried', () async {
      final (:dio, delays: _) = _client(sequence([route, json({})]));

      await _failure(dio.get<Object?>(_url));

      expect(adapterOf(dio).requests, hasLength(1));
    });
  }

  test('no retries when maxRetries is 0', () async {
    final (:dio, delays: _) = _client(status(503), maxRetries: 0);

    await _failure(dio.get<Object?>(_url));

    expect(adapterOf(dio).requests, hasLength(1));
  });

  test('cancelling during the wait ends the request', () async {
    final waiting = Completer<void>();
    final (:dio, delays: _) = _client(
      sequence([status(503), json({})]),
      delay: (_) {
        if (!waiting.isCompleted) waiting.complete();
        return Completer<void>().future;
      },
    );
    final cancelToken = CancelToken();

    final request = dio.get<Object?>(_url, cancelToken: cancelToken);
    await waiting.future;
    cancelToken.cancel();

    await expectLater(
      request,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(adapterOf(dio).requests, hasLength(1));
  });
}
