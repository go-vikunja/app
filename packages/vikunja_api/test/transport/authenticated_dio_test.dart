import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/fake_token_source.dart';

ServerConnection _connection({required bool hasV2}) {
  const info = ServerInfo(version: ServerVersion(2, 7, 0));
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
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

final class _ClosableAdapter implements HttpClientAdapter {
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 200);

  @override
  void close({bool force = false}) => closed = true;
}

final class _Recorder extends Interceptor {
  final seenAuthorization = <Object?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    seenAuthorization.add(options.headers['Authorization']);
    handler.next(options);
  }
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
  for (final (hasV2, expected) in [
    (true, 'https://tasks.example.com/vikunja/api/v2/'),
    (false, 'https://tasks.example.com/vikunja/api/v1/'),
  ]) {
    test('the base URL is the preferred API: $expected', () {
      final dio = createAuthenticatedDio(
        base: Dio(),
        connection: _connection(hasV2: hasV2),
        tokens: FakeTokenSource(current: 't'),
      );

      expect(dio.options.baseUrl, expected);
    });
  }

  test("the base's timeouts, headers and adapter are used", () async {
    final base = fakeDio({
      'https://tasks.example.com/vikunja/api/v2/info': json({}),
    });
    base.options
      ..connectTimeout = const Duration(seconds: 3)
      ..receiveTimeout = const Duration(seconds: 4)
      ..headers['User-Agent'] = 'Taskuna/1.0.0';

    final dio = createAuthenticatedDio(
      base: base,
      connection: _connection(hasV2: true),
      tokens: FakeTokenSource(current: 't'),
    );
    await dio.get<Object?>('info');

    final sent = adapterOf(base).requests.single;
    expect(sent.connectTimeout, const Duration(seconds: 3));
    expect(sent.receiveTimeout, const Duration(seconds: 4));
    expect(sent.headers['User-Agent'], 'Taskuna/1.0.0');
    expect(base.options.headers.containsKey('Authorization'), isFalse);
  });

  test("closing an account's client leaves the shared adapter open", () {
    final adapter = _ClosableAdapter();
    final base = Dio()..httpClientAdapter = adapter;

    createAuthenticatedDio(
      base: base,
      connection: _connection(hasV2: true),
      tokens: FakeTokenSource(current: 't'),
    ).close(force: true);

    expect(adapter.closed, isFalse);
  });

  test('extra interceptors run after the bearer was added', () async {
    final recorder = _Recorder();
    final base = fakeDio({
      'https://tasks.example.com/vikunja/api/v2/user': json({}),
    });

    await createAuthenticatedDio(
      base: base,
      connection: _connection(hasV2: true),
      tokens: FakeTokenSource(current: 't'),
      interceptors: [recorder],
    ).get<Object?>('user');

    expect(recorder.seenAuthorization, ['Bearer t']);
  });

  test('a redirect, e.g. to a login proxy, is not followed', () async {
    const portal = 'https://auth.example.com/?rd=tasks';
    final base = fakeDio({
      'https://tasks.example.com/vikunja/api/v2/user': redirect(portal),
      portal: html('<html>Sign in</html>'),
    });

    final dio = createAuthenticatedDio(
      base: base,
      connection: _connection(hasV2: true),
      tokens: FakeTokenSource(current: 't'),
    );
    final failure = await _failure(dio.get<Object?>('user'));

    expect(dio.options.followRedirects, isFalse);
    expect(base.options.followRedirects, isTrue);
    expect(
      failure,
      isA<UnexpectedResponse>().having((f) => f.statusCode, 'status', 302),
    );
    expect(adapterOf(base).requestedUrls, [
      'https://tasks.example.com/vikunja/api/v2/user',
    ]);
    expect(adapterOf(base).requests.single.followRedirects, isFalse);
  });
}
