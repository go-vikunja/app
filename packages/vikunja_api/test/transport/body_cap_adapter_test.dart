import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

const _url = 'https://tasks.example.com/api/v2/tasks';
const _cap = 4096;

/// Chunks of [chunkSize] spaces, which a JSON decoder keeps reading, until
/// the client stops listening.
final class _Endless {
  new({this.declared, this.status = 200});

  static const chunkSize = 1024;

  final int? declared;
  final int status;
  int sent = 0;
  bool cancelled = false;

  ResponseBody call(RequestOptions request) {
    late final StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () async {
        while (true) {
          await Future<void>.delayed(Duration.zero);
          if (cancelled) break;
          controller.add(Uint8List(chunkSize)..fillRange(0, chunkSize, 0x20));
          sent += chunkSize;
        }
      },
      onCancel: () => cancelled = true,
    );
    return ResponseBody(
      controller.stream,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (declared != null) Headers.contentLengthHeader: ['$declared'],
      },
    );
  }
}

Dio _dio(FakeRoute route, {int maxBytes = _cap}) => Dio()
  ..httpClientAdapter = BodyCapAdapter(
    FakeHttpAdapter({_url: route}),
    defaultMaxBytes: maxBytes,
  );

/// The body as [type] delivers it, a stream's read to its end.
Future<Object?> _read(
  Dio dio, {
  ResponseType type = ResponseType.bytes,
  Map<String, Object?> extra = const {},
  CancelToken? cancel,
}) async {
  final response = await dio.get<Object?>(
    _url,
    cancelToken: cancel,
    options: Options(responseType: type, extra: extra),
  );
  return switch (response.data) {
    final ResponseBody body => [
      await for (final chunk in body.stream) ...chunk,
    ],
    final data => data,
  };
}

Matcher _tooLarge(int maxBytes, {int status = 200}) =>
    isA<DioException>().having(
      normalizeError,
      'normalized',
      isA<UnexpectedResponse>()
          .having((failure) => failure.statusCode, 'statusCode', status)
          .having(
            (failure) => failure.message,
            'message',
            'a body larger than $maxBytes bytes',
          ),
    );

ResponseBody _bytes(int length, {int status = 200, int? declared}) =>
    ResponseBody.fromBytes(
      Uint8List(length),
      status,
      headers: {
        if (declared != null) Headers.contentLengthHeader: ['$declared'],
      },
    );

void main() {
  test('an answer within the cap passes through unchanged', () async {
    final body = utf8.encode('{"id":1}');
    final dio = _dio(
      (_) => ResponseBody.fromBytes(
        body,
        201,
        statusMessage: 'Created',
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          Headers.contentLengthHeader: ['${body.length}'],
          'x-request-id': ['r1'],
        },
      ),
      maxBytes: body.length,
    );

    final response = await dio.get<Object?>(_url);

    expect(response.data, {'id': 1});
    expect(response.statusCode, 201);
    expect(response.statusMessage, 'Created');
    expect(response.headers.value('x-request-id'), 'r1');
  });

  test('an error answer within the cap keeps its status and body', () async {
    final dio = _dio(json({'code': 3001, 'message': 'gone'}, status: 404));

    await expectLater(
      dio.get<Object?>(_url),
      throwsA(
        isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.badResponse)
            .having(normalizeError, 'normalized', isA<NotFound>()),
      ),
    );
  });

  for (final type in ResponseType.values) {
    group('as ${type.name}', () {
      test('exactly the cap passes', () async {
        final dio = _dio((_) => _bytes(_cap, declared: _cap));

        final data = await _read(dio, type: type);

        expect(data, isNotNull);
      });

      test('a Content-Length over the cap is refused before the body is '
          'read, and the connection closed', () async {
        final endless = _Endless(declared: _cap + 1);
        final dio = _dio(endless.call);

        await expectLater(_read(dio, type: type), throwsA(_tooLarge(_cap)));
        await pumpEventQueue();
        expect(endless.cancelled, isTrue);
        expect(endless.sent, 0);
      });

      test('an endless body is refused as it arrives, and the connection '
          'closed', () async {
        final endless = _Endless();
        final dio = _dio(endless.call);

        await expectLater(_read(dio, type: type), throwsA(_tooLarge(_cap)));
        await pumpEventQueue();
        expect(endless.cancelled, isTrue);
        expect(endless.sent, lessThan(_cap + 4 * _Endless.chunkSize));
      });

      test('a body longer than its Content-Length is refused too', () async {
        final dio = _dio(_Endless(declared: 100).call);

        await expectLater(_read(dio, type: type), throwsA(_tooLarge(_cap)));
      });
    });
  }

  test('an error answer over the cap fails like any other', () async {
    final dio = _dio(_Endless(status: 500).call);

    await expectLater(_read(dio), throwsA(_tooLarge(_cap, status: 500)));
  });

  test('a request sets its own cap or lifts it', () async {
    final dio = _dio((_) => _bytes(100), maxBytes: 10);

    expect(await _read(dio, extra: {maxBodyBytesKey: 100}), hasLength(100));
    expect(await _read(dio, extra: {maxBodyBytesKey: null}), hasLength(100));
    await expectLater(
      _read(dio, extra: {maxBodyBytesKey: 99}),
      throwsA(_tooLarge(99)),
    );
    await expectLater(_read(dio), throwsA(_tooLarge(10)));
  });

  test('the cap is 64 MiB unless the adapter is given another', () async {
    final dio = Dio()
      ..httpClientAdapter = BodyCapAdapter(
        FakeHttpAdapter({
          '$_url/at': (_) => _bytes(3, declared: 64 * 1024 * 1024),
          '$_url/over': (_) => _bytes(3, declared: 64 * 1024 * 1024 + 1),
        }),
      );

    expect((await dio.get<Object?>('$_url/at')).statusCode, 200);
    await expectLater(
      dio.get<Object?>('$_url/over'),
      throwsA(_tooLarge(defaultMaxBodyBytes)),
    );
  });

  test('a failure over the cap is never retried', () async {
    var fetches = 0;
    final dio = _dio((request) {
      fetches++;
      return _Endless().call(request);
    });
    dio.interceptors.add(RetryInterceptor(dio, delay: (_) async {}));

    await expectLater(dio.get<Object?>(_url), throwsA(_tooLarge(_cap)));
    expect(fetches, 1);
  });

  test('an answer without a body keeps its Content-Length', () async {
    final dio = Dio()
      ..httpClientAdapter = BodyCapAdapter(
        FakeHttpAdapter({
          _url: (request) => _bytes(
            0,
            status: request.method == 'HEAD' ? 200 : 204,
            declared: 1 << 40,
          ),
        }),
        defaultMaxBytes: _cap,
      );

    expect((await dio.head<Object?>(_url)).statusCode, 200);
    expect((await dio.get<Object?>(_url)).statusCode, 204);
  });

  test("the body's own failures pass through as they are", () async {
    const broken = HttpException('Connection closed while receiving data');
    final dio = _dio(
      (_) => ResponseBody(Stream.error(broken), 200, headers: {}),
    );

    await expectLater(
      _read(dio),
      throwsA(isA<DioException>().having((e) => e.error, 'error', broken)),
    );
  });

  test('a cancel while the body arrives ends it at the source', () async {
    final endless = _Endless();
    final dio = _dio(endless.call, maxBytes: 1 << 40);
    final cancel = CancelToken();
    final response = await dio.get<ResponseBody>(
      _url,
      cancelToken: cancel,
      options: Options(responseType: ResponseType.stream),
    );
    final chunks = response.data!.stream.listen((_) {
      if (!cancel.isCancelled) cancel.cancel();
    }, onError: (Object _) {});
    addTearDown(chunks.cancel);

    await pumpEventQueue();

    expect(endless.cancelled, isTrue);
  });

  group('over dart:io the connection is closed', () {
    for (final declared in [false, true]) {
      test(declared ? 'with a Content-Length' : 'without one', () async {
        var finished = false;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() {
          finished = true;
          return server.close(force: true);
        });
        server.listen((request) async {
          final response = request.response;
          if (declared) response.contentLength = 1 << 40;
          final chunk = Uint8List(64 * 1024);
          while (!finished) {
            response.add(chunk);
            await response.flush();
            await Future<void>.delayed(Duration.zero);
          }
        });
        final adapter = IOHttpClientAdapter();
        addTearDown(() => adapter.close(force: true));
        final dio = Dio()
          ..httpClientAdapter = BodyCapAdapter(
            adapter,
            defaultMaxBytes: 1024 * 1024,
          );

        await expectLater(
          dio.get<Object?>(
            'http://${server.address.address}:${server.port}/api/v1/tasks',
          ),
          throwsA(_tooLarge(1024 * 1024)),
        );
        // An answer read to its end would leave the connection open, idle.
        while (server.connectionsInfo().total > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }, timeout: const Timeout(Duration(seconds: 20)));
    }
  });
}
