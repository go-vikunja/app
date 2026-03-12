import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/token_lock.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

const _baseUrl = 'https://api.example.com';
const _oldToken = 'old_token';
const _oldCookie = 'old_cookie';
const _refreshDelay = Duration(milliseconds: 300);

/// Tracks timing of concurrent refresh calls.
class _RefreshLog {
  static final List<_RefreshEvent> events = [];
  static int callCount = 0;

  static void reset() {
    events.clear();
    callCount = 0;
  }

  static void record(int id, DateTime start, DateTime end) {
    events.add(_RefreshEvent(id, start, end));
  }

  /// Returns true when at least two recorded refresh calls overlapped in time.
  static bool get hadOverlap {
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        if (events[i].start.isBefore(events[j].end) &&
            events[j].start.isBefore(events[i].end)) {
          return true;
        }
      }
    }
    return false;
  }
}

class _RefreshEvent {
  final int id;
  final DateTime start;
  final DateTime end;
  _RefreshEvent(this.id, this.start, this.end);

  @override
  String toString() => 'RefreshEvent#$id($start -> $end)';
}

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

class FileMockSettingsDatasource implements SettingsDatasource {
  final File file;
  FileMockSettingsDatasource(this.file);

  Future<Map<String, dynamic>> _read() async {
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      return content.isEmpty ? {} : jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async =>
      file.writeAsString(jsonEncode(data), flush: true);

  @override
  Future<String?> getUserToken() async => (await _read())['token'];
  @override
  Future<String?> getRefreshCookie() async => (await _read())['cookie'];

  @override
  Future<void> saveUserToken(String? token) async {
    final data = await _read();
    data['token'] = token;
    await _write(data);
  }

  @override
  Future<void> saveRefreshCookie(String? cookie) async {
    final data = await _read();
    data['cookie'] = cookie;
    await _write(data);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

String _tokenForCall(int callId) => 'token_from_call_$callId';
String _cookieForCall(int callId) => 'cookie_from_call_$callId';

class MockResponseHeaders extends Fake implements HttpHeaders {
  final int callId;
  MockResponseHeaders(this.callId);

  String get _setCookieValue =>
      'vikunja_refresh_token=${_cookieForCall(callId)}; Path=/';

  @override
  List<String>? operator [](String name) =>
      name.toLowerCase() == 'set-cookie' ? [_setCookieValue] : null;

  @override
  String? value(String name) =>
      name.toLowerCase() == 'set-cookie' ? _setCookieValue : null;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    action('set-cookie', [_setCookieValue]);
  }
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  final int callId;
  MockHttpClientResponse(this.callId);

  @override
  int get statusCode => 200;
  @override
  HttpHeaders get headers => MockResponseHeaders(callId);
  @override
  int get contentLength => 0;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final body = utf8.encode(jsonEncode({'token': _tokenForCall(callId)}));
    return Stream.value(body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  final int callId;
  MockHttpClientRequest(this.callId);

  @override
  final HttpHeaders headers = MockHttpHeaders();
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
  Uri get uri => Uri.parse('$_baseUrl/api/v1/user/token/refresh');
  @override
  set contentLength(int value) {}
  @override
  int get contentLength => 0;

  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse(callId);
  @override
  void add(List<int> data) {}
  @override
  void write(Object? object) {}
  @override
  Future addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> get done async => MockHttpClientResponse(callId);
}

class MockHttpClientIo extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    if (!url.path.endsWith('/user/token/refresh')) {
      throw UnimplementedError('URL not mocked: $url');
    }
    final id = ++_RefreshLog.callCount;
    final start = DateTime.now();
    await Future.delayed(_refreshDelay);
    final end = DateTime.now();
    _RefreshLog.record(id, start, end);
    return MockHttpClientRequest(id);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method == 'POST' && url.path.endsWith('/user/token/refresh')) {
      return postUrl(url);
    }
    throw UnimplementedError('$method $url not mocked');
  }

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
}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => MockHttpClientIo();
}

// -- Helpers --

Client _createClient(SettingsDatasource settings) {
  final client = Client(base: _baseUrl);
  client.settingsDatasource = settings;
  return client;
}

Future<void> _isolateEntryPoint(List<dynamic> args) async {
  final sendPort = args[0] as SendPort;
  final rootToken = args[1] as RootIsolateToken;
  final settingsPath = args[2] as String;
  final lockDirPath = args[3] as String;

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
  HttpOverrides.global = TestHttpOverrides();
  TokenLock.setLockDirectory(Directory(lockDirPath));

  final client = _createClient(FileMockSettingsDatasource(File(settingsPath)));

  sendPort.send('ready');
  final result = await client.tryRefreshToken();
  sendPort.send({
    'result': result,
    'callCount': _RefreshLog.callCount,
    'events': _RefreshLog.events
        .map(
          (e) => {
            'id': e.id,
            'startMicros': e.start.microsecondsSinceEpoch,
            'endMicros': e.end.microsecondsSinceEpoch,
          },
        )
        .toList(),
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Concurrent Token Refresh', () {
    late MockSettingsDatasource settings;

    setUp(() {
      _RefreshLog.reset();
      HttpOverrides.global = TestHttpOverrides();
      settings = MockSettingsDatasource()
        .._token = _oldToken
        .._refreshCookie = _oldCookie;
    });

    tearDown(() => HttpOverrides.global = null);

    testWidgets('two clients can both successfully refresh at the same time', (
      tester,
    ) async {
      final client1 = _createClient(settings);
      final client2 = _createClient(settings);

      final results = await Future.wait([
        client1.tryRefreshToken(),
        client2.tryRefreshToken(),
      ]);

      // Both calls succeed.
      expect(results[0], isTrue, reason: 'First refresh should succeed');
      expect(results[1], isTrue, reason: 'Second refresh should succeed');

      // Both calls go through the lock, so each makes its own network call.
      expect(
        _RefreshLog.callCount,
        equals(2),
        reason: 'Both refreshes should hit the network (serialized by lock)',
      );

      // The in-process mutex serializes them, so they must NOT overlap.
      expect(
        _RefreshLog.hadOverlap,
        isFalse,
        reason: 'In-process lock should serialize concurrent refresh calls',
      );
    });

    testWidgets('sequential refreshes both succeed independently', (
      tester,
    ) async {
      final client = _createClient(settings);

      final first = await client.tryRefreshToken();
      expect(first, isTrue, reason: 'First sequential refresh should succeed');

      final second = await client.tryRefreshToken();
      expect(
        second,
        isTrue,
        reason: 'Second sequential refresh should succeed',
      );

      expect(
        _RefreshLog.callCount,
        equals(2),
        reason: 'Two sequential refreshes should each hit the network',
      );
    });

    testWidgets(
      'two isolates can both refresh simultaneously and both succeed',
      (tester) async {
        final tempDir = await Directory.systemTemp.createTemp();
        final settingsFile = File('${tempDir.path}/settings.json');
        final lockDir = await Directory.systemTemp.createTemp('lock_test');

        TokenLock.setLockDirectory(lockDir);

        final fileSettings = FileMockSettingsDatasource(settingsFile);
        await fileSettings.saveUserToken(_oldToken);
        await fileSettings.saveRefreshCookie(_oldCookie);

        final client = _createClient(fileSettings);

        // Spawn a background isolate that will also try to refresh.
        final port = ReceivePort();
        await Isolate.spawn(_isolateEntryPoint, [
          port.sendPort,
          RootIsolateToken.instance!,
          settingsFile.path,
          lockDir.path,
        ]);

        final iterator = StreamIterator(port);

        // Wait for the background isolate to be ready.
        await iterator.moveNext();
        expect(iterator.current, 'ready');

        // Fire the main-isolate refresh at the same time.
        final mainFuture = client.tryRefreshToken();

        // Collect background isolate result.
        await iterator.moveNext();
        final bgData = iterator.current as Map<dynamic, dynamic>;
        final bgResult = bgData['result'] as bool;

        final mainResult = await mainFuture;

        // Both isolates should succeed.
        expect(
          mainResult,
          isTrue,
          reason: 'Main isolate refresh should succeed',
        );
        expect(
          bgResult,
          isTrue,
          reason: 'Background isolate refresh should succeed',
        );

        // Together they should each make exactly one network call.
        final bgCallCount = bgData['callCount'] as int;
        final totalCalls = _RefreshLog.callCount + bgCallCount;
        expect(
          totalCalls,
          equals(2),
          reason: 'Both isolates should each make one network refresh call',
        );

        // The filesystem lock serializes them, so they must NOT overlap.
        final bgEvents = (bgData['events'] as List).cast<Map>();
        for (final e in bgEvents) {
          _RefreshLog.record(
            e['id'] as int,
            DateTime.fromMicrosecondsSinceEpoch(e['startMicros'] as int),
            DateTime.fromMicrosecondsSinceEpoch(e['endMicros'] as int),
          );
        }
        expect(
          _RefreshLog.hadOverlap,
          isFalse,
          reason:
              'Cross-isolate filesystem lock should serialize refresh calls',
        );

        // Cleanup
        TokenLock.setLockDirectory(null);
        if (await settingsFile.exists()) await settingsFile.delete();
        if (await lockDir.exists()) await lockDir.delete(recursive: true);
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      },
    );
  });
}
