/// A `dart:io` [HttpClient] stand-in installed through [HttpOverrides].
///
/// Needed wherever production code reaches for `dart:io` directly instead of
/// taking an injectable `http.Client` — `Client.tryRefreshToken` (which builds
/// its own `IOClient`) and `VersionDataSource` (which calls `http.get`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Answers every request with [handler], regardless of verb.
class MockHttpClientIo extends Fake implements HttpClient {
  MockHttpClientIo(this.handler);

  /// Called with the request's url, method and decoded body.
  final http.Response Function(Uri url, String method, String body) handler;

  /// Every request this client saw, in order.
  final List<({Uri url, String method})> requests = [];

  @override
  bool Function(X509Certificate, String, int)? badCertificateCallback;
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add((url: url, method: method));
    return _MockHttpClientRequest(url, method, handler);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
}

/// Installs [factory] as the process-wide `HttpClient` source.
class TestHttpOverrides extends HttpOverrides {
  TestHttpOverrides(this._factory);

  final HttpClient Function() _factory;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _factory();
}

/// Routes all `dart:io` HTTP traffic to [handler] for the duration of the test
/// and restores the previous overrides afterwards.
MockHttpClientIo installMockHttpClient(
  http.Response Function(Uri url, String method, String body) handler,
) {
  final client = MockHttpClientIo(handler);
  final previous = HttpOverrides.current;
  HttpOverrides.global = TestHttpOverrides(() => client);
  addTearDown(() => HttpOverrides.global = previous);
  return client;
}

/// A 1x1 transparent PNG, enough for `NetworkImage` to decode successfully.
final Uint8List transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Answers every `dart:io` HTTP request with a transparent pixel, so widgets
/// that render a `NetworkImage` (the settings avatar, for one) do not attempt a
/// real request during a test.
void mockNetworkImages() {
  installMockHttpClient(
    (_, _, _) => http.Response.bytes(
      transparentPixelPng,
      200,
      headers: {'content-type': 'image/png'},
    ),
  );
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  _MockHttpClientRequest(this._url, this.method, this._handler);

  final Uri _url;
  final http.Response Function(Uri, String, String) _handler;
  final List<int> _body = [];

  @override
  String method;

  @override
  HttpHeaders get headers => _MockHttpHeaders();
  @override
  Encoding encoding = utf8;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  Uri get uri => _url;
  @override
  set contentLength(int value) {}
  @override
  int get contentLength => 0;

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  void write(Object? object) {
    if (object != null) _body.addAll(utf8.encode(object.toString()));
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async =>
      _MockHttpClientResponse(_handler(_url, method, utf8.decode(_body)));

  @override
  Future<HttpClientResponse> get done => close();
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  _MockHttpClientResponse(this._response);

  final http.Response _response;

  @override
  int get statusCode => _response.statusCode;
  @override
  HttpHeaders get headers => _MockResponseHeaders();
  @override
  int get contentLength => _response.bodyBytes.length;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(_response.bodyBytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class _MockResponseHeaders extends Fake implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;
  @override
  String? value(String name) => null;
  @override
  void forEach(void Function(String, List<String>) action) {}
}
