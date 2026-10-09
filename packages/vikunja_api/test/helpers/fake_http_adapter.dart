import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeRoute = FutureOr<ResponseBody> Function(RequestOptions request);

/// Answers requests by their full URL. Unknown URLs fail like a closed port.
final class FakeHttpAdapter implements HttpClientAdapter {
  new(this.routes);

  final Map<String, FakeRoute> routes;
  final List<RequestOptions> requests = [];

  List<String> get requestedUrls => [
    for (final request in requests) request.uri.toString(),
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = routes[options.uri.toString()] ?? refused;
    return await route(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(Map<String, FakeRoute> routes) =>
    Dio()..httpClientAdapter = FakeHttpAdapter(routes);

FakeHttpAdapter adapterOf(Dio dio) => dio.httpClientAdapter as FakeHttpAdapter;

FakeRoute json(Object? body, {int status = 200}) =>
    (_) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );

FakeRoute fixture(String name, {int status = 200}) =>
    (_) => ResponseBody.fromString(
      readFixture(name),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );

FakeRoute html(String body, {int status = 200}) =>
    (_) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );

FakeRoute redirect(String location, {int status = 302}) =>
    (_) => ResponseBody.fromString(
      '',
      status,
      isRedirect: true,
      headers: {
        'location': [location],
      },
    );

FakeRoute status(int code, {Map<String, List<String>> headers = const {}}) =>
    (_) => ResponseBody.fromString('', code, headers: headers);

FakeRoute delayed(Duration delay, FakeRoute route) => (request) async {
  await Future<void>.delayed(delay);
  return await route(request);
};

/// Answers nothing until the probe's own connect timeout fails the request.
Future<ResponseBody> timesOut(RequestOptions request) async {
  final timeout = request.connectTimeout!;
  await Future<void>.delayed(timeout);
  throw DioException.connectionTimeout(
    timeout: timeout,
    requestOptions: request,
  );
}

/// Answers nothing until Dio cancels the request.
Future<ResponseBody> hangs(RequestOptions request) =>
    Completer<ResponseBody>().future;

ResponseBody refused(RequestOptions request) =>
    throw DioException.connectionError(
      requestOptions: request,
      reason: 'Connection refused',
      error: const SocketException('Connection refused'),
    );

FakeRoute throwing(Exception error) =>
    (_) => throw error;

FakeRoute failsWith(DioException Function(RequestOptions request) build) =>
    (request) => throw build(request);

String readFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

Map<String, Object?> fixtureJson(String name) =>
    jsonDecode(readFixture(name)) as Map<String, Object?>;
