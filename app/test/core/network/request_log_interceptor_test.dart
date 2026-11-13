import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';

class _StubAdapter implements HttpClientAdapter {
  new(this.statusCode);

  final int statusCode;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({'token': 'response-secret'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'set-cookie': ['vikunja_refresh=cookie-secret'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<LogRecord> records;
  late Logger logger;

  setUp(() {
    records = [];
    logger = Logger.detached('http-test')..level = Level.ALL;
    logger.onRecord.listen(records.add);
  });

  Dio dioWith(_StubAdapter adapter) => Dio()
    ..httpClientAdapter = adapter
    ..interceptors.add(RequestLogInterceptor(logger: logger));

  Future<void> request(Dio dio) => dio.get<Object?>(
    'https://alice:pw@vikunja.example.com/api/v1/info?token=query-secret',
    options: Options(
      headers: {'Authorization': 'Bearer header-secret-0123456789'},
    ),
    data: {'password': 'body-secret'},
  );

  test('logs method, URL without query, status and duration only', () async {
    await request(dioWith(_StubAdapter(200)));

    expect(records, hasLength(1));
    final message = records.single.message;
    expect(
      message,
      matches(
        RegExp(
          r'^GET https://vikunja\.example\.com/api/v1/info -> 200 \d+ ms$',
        ),
      ),
    );
  });

  test('logs failures without leaking secrets', () async {
    await expectLater(
      request(dioWith(_StubAdapter(404))),
      throwsA(isA<DioException>()),
    );

    final message = records.single.message;
    expect(message, startsWith('GET https://vikunja.example.com/api/v1/info'));
    expect(message, contains('-> 404'));
    for (final secret in [
      'query-secret',
      'header-secret',
      'body-secret',
      'response-secret',
      'cookie-secret',
      'pw',
      'Authorization',
    ]) {
      expect(message, isNot(contains(secret)));
    }
  });

  test('createDio sets timeouts, User-Agent and the given adapter', () async {
    final adapter = _StubAdapter(200);
    final dio = createDio(
      userAgent: 'Vikunja-App/1.0+1 (android 15)',
      httpClientAdapter: adapter,
      logRequests: false,
    );

    await dio.get<Object?>('https://vikunja.example.com/api/v1/info');

    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));
    expect(dio.options.sendTimeout, const Duration(seconds: 15));
    expect(
      adapter.lastRequest?.headers['User-Agent'],
      'Vikunja-App/1.0+1 (android 15)',
    );
    expect(dio.interceptors.whereType<RequestLogInterceptor>(), isEmpty);
  });
}
