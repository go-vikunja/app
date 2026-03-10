import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/core/network/token_lock.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock for [SettingsDatasource]
class MockSettingsDatasource implements SettingsDatasource {
  String? _token;
  String? _refreshCookie;

  @override
  Future<String?> getUserToken() async => _token;

  @override
  Future<String?> getRefreshCookie() async => _refreshCookie;

  @override
  Future<void> saveUserToken(String? token) async => _token = token;

  @override
  Future<void> saveRefreshCookie(String? cookie) async =>
      _refreshCookie = cookie;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockResponseHeaders extends Fake implements HttpHeaders {
  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == 'set-cookie') {
      return ['vikunja_refresh_token=new_cookie; Path=/'];
    }
    return null;
  }

  @override
  String? value(String name) {
    if (name.toLowerCase() == 'set-cookie') {
      return 'vikunja_refresh_token=new_cookie; Path=/';
    }
    return null;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    // Mocking forEach to actually call the action for 'set-cookie'
    action('set-cookie', ['vikunja_refresh_token=new_cookie; Path=/']);
  }
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  HttpHeaders get headers => MockResponseHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Return empty token response
    var data = utf8.encode(jsonEncode({'token': 'new_token'}));
    return Stream.value(data).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => 0;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => "OK";
}

class MockHttpClientIo extends Fake implements HttpClient {
  static int refreshCallCount = 0;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    if (url.path.endsWith('/user/token/refresh')) {
      refreshCallCount++;
      await Future.delayed(const Duration(milliseconds: 50));
      return MockHttpClientRequest();
    }

    throw UnimplementedError("URL not mocked: $url");
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method == 'POST' && url.path.endsWith('/user/token/refresh')) {
      return postUrl(url);
    }
    throw UnimplementedError("Method $method for $url not mocked");
  }

  @override
  bool Function(X509Certificate cert, String host, int port)?
  badCertificateCallback;

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
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  String method = 'POST';

  @override
  Uri get uri => Uri.parse('https://api.example.com/api/v1/user/token/refresh');

  @override
  set contentLength(int value) {}

  @override
  int get contentLength => 0;

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> get done async => MockHttpClientResponse();
}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClientIo();
  }
}

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }
}

class MockTokenLock implements TokenLockInterface {
  final _completerQueue = <Completer<void>>[];
  bool _isLocked = false;

  @override
  Future<T> synchronized<T>(Future<T> Function() callback) async {
    while (_isLocked) {
      final completer = Completer<void>();
      _completerQueue.add(completer);
      await completer.future;
    }

    _isLocked = true;
    try {
      return await callback();
    } finally {
      _isLocked = false;
      if (_completerQueue.isNotEmpty) {
        final next = _completerQueue.removeAt(0);
        next.complete();
      }
    }
  }
}

void main() {
  group('Concurrent Token Refresh Tests', () {
    late MockSettingsDatasource settings;

    setUp(() async {
      settings = MockSettingsDatasource();
      MockHttpClientIo.refreshCallCount = 0;

      HttpOverrides.global = TestHttpOverrides();
      PathProviderPlatform.instance = MockPathProviderPlatform();

      TokenLock.setLockImplementation(MockTokenLock());

      settings._token = 'old_token';
      settings._refreshCookie = 'old_cookie';
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    test(
      'Concurrent refresh requests from same client instance are deduped locally (intraisolate)',
      () async {
        final client = Client(
          base: 'https://api.example.com',
          token: 'old_token',
          refreshCookie: 'old_cookie',
          settingsDatasource: settings,
        );

        // Fire two refresh requests simultaneously
        final future1 = client.tryRefreshToken();
        final future2 = client.tryRefreshToken();

        final results = await Future.wait([future1, future2]);

        expect(results[0], true, reason: "First request should succeed");
        expect(results[1], true, reason: "Second request should succeed");

        // Verify only one network call was made
        expect(MockHttpClientIo.refreshCallCount, 1);

        // Verify client state updated
        expect(client.token, 'new_token');
      },
    );

    test(
      'Concurrent refresh requests from different client instances are serialized (interisolate simulation)',
      () async {
        final client1 = Client(
          base: 'https://api.example.com',
          token: 'old_token',
          refreshCookie: 'old_cookie',
          settingsDatasource: settings,
        );

        final client2 = Client(
          base: 'https://api.example.com',
          token: 'old_token',
          refreshCookie: 'old_cookie',
          settingsDatasource: settings,
        );

        // Fire simultaneous refresh requests from different "isolates"
        final future1 = client1.tryRefreshToken();
        final future2 = client2.tryRefreshToken();

        final results = await Future.wait([future1, future2]);

        expect(results[0], true);
        expect(results[1], true);

        // CRITICAL CHECK: Only 1 network call should occur.
        // The second client should have found the updated token in storage.
        expect(
          MockHttpClientIo.refreshCallCount,
          1,
          reason: "Should coalesce to a single network refresh",
        );

        // Both clients should have the new token
        expect(client1.token, 'new_token');
        expect(client2.token, 'new_token');
      },
    );
  });
}
