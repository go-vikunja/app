import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart' show preConsentProbeKey;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_adapter.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/tls_fixtures.dart';

const _secret = 'dummy-cf-secret-0123';

/// The native stack: records what reached it, answers 200 or [failure].
final class _Platform implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Exception Function(RequestOptions sent)? failure;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (failure case final fail?) throw fail(options);
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) => closed = true;
}

final class _FailingSecureStore implements SecureStore {
  new(this.inner);

  final SecureStore inner;
  bool failReads = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw Exception('Keychain locked');
    return await inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> deleteAll() => inner.deleteAll();
}

/// Wraps the real dart:io adapter to see which ones were made and closed.
final class _TrackedAdapter implements HttpClientAdapter {
  new(this.inner, {this.failFirst = false});

  final HttpClientAdapter inner;
  bool failFirst;
  bool closed = false;
  int fetches = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    fetches++;
    if (failFirst) {
      failFirst = false;
      throw StateError(
        "Can't establish connection after the adapter was "
        'closed.',
      );
    }
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    inner.close(force: force);
  }
}

/// Hangs up on every request; records when a connection that sent nothing
/// is closed by the client.
final class _QuietCloseTlsServer {
  new _(this._server);

  static Future<_QuietCloseTlsServer> start() async => _QuietCloseTlsServer._(
    await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      serverContext('server.pem', 'server.key'),
    ),
  ).._listen();

  final SecureServerSocket _server;
  final _open = <SecureSocket>[];
  final quietConnectionClosed = Completer<void>();

  int get port => _server.port;

  void _listen() {
    _server.listen((socket) {
      _open.add(socket);
      var sentData = false;
      void closed() {
        if (!sentData && !quietConnectionClosed.isCompleted) {
          quietConnectionClosed.complete();
        }
      }

      socket.listen(
        (_) {
          sentData = true;
          socket.destroy();
        },
        onDone: closed,
        onError: (Object _) => closed(),
      );
    }, onError: (Object _) {});
  }

  Future<void> close() async {
    for (final socket in _open) {
      socket.destroy();
    }
    await _server.close();
  }
}

/// Forwards the first connection at once and every later one only after a
/// delay, so that a later TLS handshake outlasts a short timeout.
final class _DelayingProxy {
  new _(this._server, this._target, this._delay);

  static Future<_DelayingProxy> start(int target, Duration delay) async =>
      _DelayingProxy._(
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
        target,
        delay,
      ).._listen();

  final ServerSocket _server;
  final int _target;
  final Duration _delay;
  final _sockets = <Socket>[];
  var _accepted = 0;

  int get port => _server.port;

  void _listen() {
    _server.listen((client) async {
      _sockets.add(client);
      if (_accepted++ > 0) await Future<void>.delayed(_delay);
      final upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _target,
      );
      _sockets.add(upstream);
      client.listen(
        upstream.add,
        onDone: upstream.destroy,
        onError: (Object _) => upstream.destroy(),
      );
      upstream.listen(
        client.add,
        onDone: client.destroy,
        onError: (Object _) => client.destroy(),
      );
    });
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }
}

void main() {
  late MemoryPreferencesStore preferences;
  late MemorySecureStore secureStore;
  late _FailingSecureStore secure;
  late NetworkProfiles profiles;
  late _Platform platform;

  setUp(() {
    preferences = MemoryPreferencesStore();
    secureStore = MemorySecureStore();
    secure = _FailingSecureStore(secureStore);
    profiles = NetworkProfiles(preferences: preferences, secureStore: secure);
    platform = _Platform();
  });

  Dio dio({NetworkProfileAdapter? adapter, HttpClientAdapter? transport}) {
    final dio = createDio(
      userAgent: 'Vikunja-App/test',
      httpClientAdapter: transport ?? platform,
      profiles: profiles,
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    addTearDown(dio.close);
    return dio;
  }

  NetworkProfileAdapter adapterOver(
    HttpClientAdapter transport, {
    HttpClientAdapter Function(CreateHttpClient create)? createDartIoAdapter,
  }) => NetworkProfileAdapter(
    transport,
    profiles,
    refusalCheckTimeout: const Duration(seconds: 2),
    refusalCheckWait: const Duration(milliseconds: 300),
    createDartIoAdapter: createDartIoAdapter,
  );

  final api = OriginKey.fromString('https://vikunja.example.com:443');

  Matcher failsWith<T>() => throwsA(
    isA<DioException>()
        .having((e) => e.type, 'type', DioExceptionType.connectionError)
        .having((e) => e.error, 'error', isA<T>()),
  );

  group('no profile', () {
    test('goes to the platform adapter unchanged', () async {
      await dio().get<String>('https://vikunja.example.com/api/v1/info');

      expect(platform.requests.single.headers.keys, isNot(contains('X-Token')));
      expect(platform.requests.single.followRedirects, isFalse);
    });
  });

  group('headers', () {
    setUp(
      () => profiles.setHeaders(api, {
        'CF-Access-Client-Id': 'dummy-cf-id',
        'CF-Access-Client-Secret': _secret,
      }),
    );

    test('are merged into a copy for their origin only, with redirects '
        'off', () async {
      final client = dio();
      final caller = Options(followRedirects: true);

      await client.get<String>(
        'https://vikunja.example.com/api/v1/tasks',
        options: caller,
      );
      await client.get<String>('https://vikunja.example.com:3456/api/v1/info');
      await client.get<String>('https://other.example.com/api/v1/info');

      final sent = platform.requests[0];
      expect(sent.headers['CF-Access-Client-Secret'], _secret);
      expect(sent.headers['CF-Access-Client-Id'], 'dummy-cf-id');
      expect(sent.followRedirects, isFalse);
      expect(caller.headers, isNull);
      for (final unprofiled in platform.requests.skip(1)) {
        expect(unprofiled.headers.keys, isNot(contains('CF-Access-Client-Id')));
      }
    });

    test('a request header of the same name wins, ignoring case', () async {
      await dio().get<String>(
        'https://vikunja.example.com/api/v1/info',
        options: Options(headers: {'cf-access-client-id': 'from-request'}),
      );

      final headers = platform.requests.single.headers;
      expect(headers['cf-access-client-id'], 'from-request');
      expect(
        headers.keys.where(
          (name) => name.toLowerCase() == 'cf-access-client-id',
        ),
        hasLength(1),
      );
      expect(headers['CF-Access-Client-Secret'], _secret);
    });

    test(
      "errors leave with the caller's options, without the headers",
      () async {
        platform.failure = (sent) => DioException.connectionError(
          requestOptions: sent,
          reason: 'refused',
          error: const SocketException('refused'),
        );

        await expectLater(
          dio().get<String>('https://vikunja.example.com/api/v1/info'),
          throwsA(
            isA<DioException>()
                .having((e) => e.error, 'error', isA<SocketException>())
                .having(
                  (e) => e.requestOptions.headers.values.join(' '),
                  'headers',
                  isNot(contains(_secret)),
                ),
          ),
        );
      },
    );

    test(
      'a value the transport refuses needs re-entry, without quoting it',
      () async {
        platform.failure = (sent) => FormatException(
          'Invalid HTTP header field value',
          sent.headers['CF-Access-Client-Secret'],
        );

        await expectLater(
          dio().get<String>('https://vikunja.example.com/api/v1/info'),
          failsWith<ConnectionProfileIncompleteException>(),
        );
        try {
          await dio().get<String>('https://vikunja.example.com/api/v1/info');
        } on DioException catch (error) {
          expect(
            '$error ${error.message} ${error.error}',
            isNot(contains(_secret)),
          );
        }
      },
    );

    test('an error that quotes a secret keeps its kind, without the '
        'text', () async {
      Future<DioException> failure() async {
        try {
          await dio().get<String>('https://vikunja.example.com/api/v1/info');
        } on DioException catch (error) {
          return error;
        }
        fail('The request did not fail');
      }

      platform.failure = (sent) => Exception('echo: $_secret');
      final generic = await failure();
      platform.failure = (sent) => DioException.connectionError(
        requestOptions: sent,
        reason: 'echo: $_secret',
        error: const SocketException('refused by $_secret', port: 443),
      );
      final socket = await failure();

      for (final error in [generic, socket]) {
        expect(error.type, DioExceptionType.connectionError);
        expect(error.error, isNot(isA<ConnectionProfileIncompleteException>()));
        expect(
          '$error ${error.message} ${error.error}',
          isNot(contains(_secret)),
        );
      }
      expect(socket.error, isA<SocketException>());
    });
  });

  group('a header value short enough to occur by chance', () {
    setUp(() => profiles.setHeaders(api, {'X-Mobile-Gate': '1'}));

    test('leaves a refused connection unreachable', () async {
      platform.failure = (sent) => DioException.connectionError(
        requestOptions: sent,
        reason: 'refused',
        error: const SocketException(
          'Connection refused',
          osError: OSError('Connection refused', 111),
          port: 44312,
        ),
      );

      await expectLater(
        dio().get<String>('https://vikunja.example.com/api/v1/info'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.connectionError)
              .having((e) => e.error, 'error', isA<SocketException>()),
        ),
      );
    });

    test('leaves a timeout a timeout', () async {
      platform.failure = (sent) => DioException.connectionTimeout(
        requestOptions: sent,
        timeout: const Duration(seconds: 10),
      );

      await expectLater(
        dio().get<String>('https://vikunja.example.com/api/v1/info'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
    });
  });

  group('storage that cannot be read fails closed', () {
    test('locked secrets: no request leaves', () async {
      await profiles.setHeaders(api, {'X-Token': 'dummy'});
      await profiles.reload();
      secure.failReads = true;

      await expectLater(
        dio().get<String>('https://vikunja.example.com/api/v1/info'),
        failsWith<ConnectionProfileLockedException>(),
      );
      expect(platform.requests, isEmpty);
    });

    test('damaged metadata: no request leaves, to any origin', () async {
      preferences.values[NetworkProfiles.storageKey] = '{damaged';

      await expectLater(
        dio().get<String>('https://unprofiled.example.com/api/v1/info'),
        failsWith<ConnectionProfilesDamagedException>(),
      );
      expect(platform.requests, isEmpty);
    });
  });

  group('cleartext', () {
    late HttpServer server;
    late List<HttpHeaders> arrived;
    late OriginKey origin;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      arrived = [];
      server.listen((request) {
        arrived.add(request.headers);
        request.response.write('{}');
        unawaited(request.response.close());
      });
      origin = OriginKey.fromString('http://127.0.0.1:${server.port}');
      // A header profile whose consent was revoked afterwards.
      await profiles.consentToCleartext(origin);
      await profiles.setHeaders(origin, {'X-Token': 'dummy-http-header'});
      await profiles.revokeCleartext(origin);
    });
    tearDown(() => server.close(force: true));

    Options probe({String method = 'GET', Map<String, Object?>? headers}) =>
        Options(
          method: method,
          headers: headers,
          extra: {preConsentProbeKey: true},
        );

    test('only the marked /info probe goes out, without the profile', () async {
      final client = dio(transport: IOHttpClientAdapter());
      final base = 'http://127.0.0.1:${server.port}';

      await client.get<String>('$base/vikunja/api/v1/info', options: probe());
      await client.get<String>('$base/api/v2/info', options: probe());

      expect(arrived, hasLength(2));
      expect(arrived.first.value('X-Token'), isNull);

      for (final (path, options) in [
        ('/api/v1/info', Options()),
        ('/api/v1/user', probe()),
        ('/api/v1/info', probe(method: 'POST')),
        ('/api/v1/info', probe(headers: {'authorization': 'Bearer x'})),
      ]) {
        await expectLater(
          client.request<String>('$base$path', options: options),
          failsWith<CleartextBlockedException>(),
          reason: '$path ${options.method} ${options.headers}',
        );
      }
      expect(arrived, hasLength(2));
    });

    test('with consent, requests go out with the headers', () async {
      await profiles.consentToCleartext(origin);
      final client = dio(transport: IOHttpClientAdapter());

      await client.get<String>('http://127.0.0.1:${server.port}/api/v1/user');

      expect(arrived.single.value('X-Token'), 'dummy-http-header');
    });

    test('an origin without any profile is blocked too', () async {
      await expectLater(
        dio().get<String>('http://192.168.1.20:3456/api/v1/user'),
        failsWith<CleartextBlockedException>(),
      );
      expect(platform.requests, isEmpty);
    });
  });

  group('dart:io path', () {
    late RecordingTlsServer server;
    late OriginKey origin;

    setUp(() async {
      server = await RecordingTlsServer.start();
      origin = OriginKey.fromString('https://localhost:${server.port}');
    });
    tearDown(() => server.close());

    String url() => 'https://localhost:${server.port}/api/v1/info';

    test('a pinned origin leaves the native stack and gets through', () async {
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.setHeaders(origin, {'X-Token': 'dummy-pinned-header'});

      final response = await dio().get<String>(url());

      expect(response.data, 'ok');
      expect(platform.requests, isEmpty);
      expect(server.requests.single.value('X-Token'), 'dummy-pinned-header');
    });

    test('a pin mismatch fails before any request and is recorded once, '
        'without a revision change', () async {
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('server.pem'),
      );
      final revision = (await profiles.metadataFor(origin))!.revision;
      final client = dio();

      for (var i = 0; i < 2; i++) {
        await expectLater(
          client.get<String>(url()),
          throwsA(
            isA<DioException>().having(
              (e) => e.error,
              'error',
              isA<HandshakeException>(),
            ),
          ),
        );
      }
      PinMismatch? mismatch;
      for (var i = 0; i < 40 && mismatch == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        mismatch = (await profiles.metadataFor(origin))?.lastPinMismatch;
      }

      expect(server.requests, isEmpty);
      expect(mismatch?.sha256, tlsFixtureSha256('selfsigned.pem'));
      expect((await profiles.metadataFor(origin))!.revision, revision);
    });

    test(
      'after "Keep current" the same certificate is recorded again',
      () async {
        await profiles.trustCertificate(
          origin,
          tlsFixtureCertificate('server.pem'),
        );
        final client = dio();
        Future<PinMismatch?> recorded() async {
          PinMismatch? mismatch;
          for (var i = 0; i < 40 && mismatch == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            mismatch = (await profiles.metadataFor(origin))?.lastPinMismatch;
          }
          return mismatch;
        }

        await expectLater(
          client.get<String>(url()),
          throwsA(isA<DioException>()),
        );
        expect(await recorded(), isNotNull);
        await profiles.dismissPinMismatch(origin);
        await expectLater(
          client.get<String>(url()),
          throwsA(isA<DioException>()),
        );

        expect((await recorded())?.sha256, tlsFixtureSha256('selfsigned.pem'));
      },
    );

    test('an edit closes the old dart:io adapter; the next request uses a '
        'new one', () async {
      final made = <_TrackedAdapter>[];
      final adapter = adapterOver(
        platform,
        createDartIoAdapter: (create) {
          final tracked = _TrackedAdapter(
            IOHttpClientAdapter(createHttpClient: create),
          );
          made.add(tracked);
          return tracked;
        },
      );
      final client = dio(adapter: adapter);
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );

      await client.get<String>(url());
      await client.get<String>(url());
      expect(made, hasLength(1));

      await profiles.setHeaders(origin, {'X-Token': 'dummy'});
      await client.get<String>(url());

      expect(made, hasLength(2));
      expect(made.first.closed, isTrue);
      expect(made.last.closed, isFalse);

      // Without a profile the origin is the native stack's again.
      await profiles.forget(origin);
      await client.get<String>(url());
      expect(made.last.closed, isTrue);
      expect(platform.requests, hasLength(1));
    });

    test('a closed adapter is retried once on a fresh one', () async {
      final made = <_TrackedAdapter>[];
      final adapter = adapterOver(
        platform,
        createDartIoAdapter: (create) {
          final tracked = _TrackedAdapter(
            IOHttpClientAdapter(createHttpClient: create),
            failFirst: made.isEmpty,
          );
          made.add(tracked);
          return tracked;
        },
      );
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );

      final response = await dio(adapter: adapter).get<String>(url());

      expect(response.data, 'ok');
      expect(made, hasLength(2));
      expect(made.first.closed, isTrue);
      expect(server.requests, hasLength(1));
    });

    test('a stored value forced past validation needs re-entry and is '
        'never quoted', () async {
      const forced = 'dummy forced-value';
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.setHeaders(origin, {'X-Token': 'placeholder'});
      secureStore.values[NetworkProfileSecrets.keyFor(
        NetworkProfile.idFor(origin),
      )] = jsonEncode({
        'headers': {'X-Token': forced},
      });
      await profiles.reload();
      final logs = <String>[];
      Logger.root.level = Level.ALL;
      final subscription = Logger.root.onRecord.listen(
        (record) => logs.add('${record.message} ${record.error ?? ''}'),
      );
      addTearDown(subscription.cancel);

      Object? failure;
      try {
        await dio().get<String>(url());
      } on DioException catch (error) {
        failure = error;
      }

      expect(
        failure,
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<ConnectionProfileIncompleteException>(),
        ),
      );
      final failureText = [
        '$failure',
        (failure! as DioException).message,
        (failure as DioException).error,
      ].join(' ');
      expect(failureText, isNot(contains('forced-value')));
      expect(logs.join('\n'), isNot(contains('forced-value')));
      expect(server.requests, isEmpty);
    });

    test(
      'a stored client certificate dart:io refuses needs re-entry',
      () async {
        await profiles.setClientCertificate(
          origin,
          fileName: 'client.p12',
          bytes: tlsFixture('client.p12'),
          password: tlsFixturePassword,
        );
        final key = NetworkProfileSecrets.keyFor(NetworkProfile.idFor(origin));
        final stored =
            jsonDecode(secureStore.values[key]!) as Map<String, Object?>;
        secureStore.values[key] = jsonEncode({
          ...stored,
          'pkcs12Password': 'not-the-password',
        });
        await profiles.reload();

        await expectLater(
          dio().get<String>(url()),
          failsWith<ConnectionProfileIncompleteException>(),
        );
      },
    );
  });

  group('client certificate refused (TLS 1.3, dart:io)', () {
    late MutualTlsServer server;
    late OriginKey origin;

    setUp(() async {
      server = await MutualTlsServer.start();
      origin = OriginKey.fromString('https://localhost:${server.port}');
      await profiles.trustCaCertificate(
        origin,
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );
    });
    tearDown(() => server.close());

    Future<Response<String>> get() =>
        dio(adapter: adapterOver(platform))
            .get<String>('https://localhost:${server.port}/api/v1/info');

    test(
      'without a certificate: confirmed by a handshake-only check',
      () async {
        await expectLater(
          get(),
          failsWith<ClientCertificateRefusedException>(),
        );
        expect(server.requestsReceived, 0);
      },
    );

    test('with a certificate from another CA: confirmed', () async {
      await profiles.setClientCertificate(
        origin,
        fileName: 'wrong-client.p12',
        bytes: tlsFixture('wrong-client.p12'),
        password: tlsFixturePassword,
      );

      await expectLater(get(), failsWith<ClientCertificateRefusedException>());
    });

    test('a stored value that is part of the origin does not hide the '
        'refusal', () async {
      await profiles.setHeaders(origin, {'X-Gate': 'localhost'});

      await expectLater(get(), failsWith<ClientCertificateRefusedException>());
    });

    test('with the right certificate: through', () async {
      await profiles.setClientCertificate(
        origin,
        fileName: 'client.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );

      expect((await get()).data, 'ok');
    });

    test('a server that hangs up on the request but not on a handshake is '
        'not confirmed', () async {
      final hangUp = await HangUpTlsServer.start();
      addTearDown(hangUp.close);
      final hangUpOrigin = OriginKey.fromString(
        'https://localhost:${hangUp.port}',
      );
      await profiles.trustCaCertificate(
        hangUpOrigin,
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );

      await expectLater(
        dio(adapter: adapterOver(platform))
            .get<String>('https://localhost:${hangUp.port}/api/v1/info'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            anyOf(isA<HttpException>(), isA<SocketException>()),
          ),
        ),
      );
    });
  });

  test('a client-certificate check whose handshake outlasts its timeout '
      'closes the socket once the handshake completes', () async {
    final server = await _QuietCloseTlsServer.start();
    addTearDown(server.close);
    final proxy = await _DelayingProxy.start(
      server.port,
      const Duration(milliseconds: 800),
    );
    addTearDown(proxy.close);
    final origin = OriginKey.fromString('https://localhost:${proxy.port}');
    await profiles.trustCaCertificate(
      origin,
      fileName: 'ca.pem',
      pem: tlsFixtureText('ca.pem'),
    );
    final adapter = NetworkProfileAdapter(
      platform,
      profiles,
      refusalCheckTimeout: const Duration(milliseconds: 300),
      refusalCheckWait: const Duration(milliseconds: 300),
    );

    await expectLater(
      dio(adapter: adapter)
          .get<String>('https://localhost:${proxy.port}/api/v1/info'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isNot(isA<ClientCertificateRefusedException>()),
        ),
      ),
    );

    await server.quietConnectionClosed.future.timeout(
      const Duration(seconds: 3),
    );
  });

  test('close closes the platform adapter and every dart:io adapter', () async {
    final server = await RecordingTlsServer.start();
    addTearDown(server.close);
    final origin = OriginKey.fromString('https://localhost:${server.port}');
    await profiles.trustCertificate(
      origin,
      tlsFixtureCertificate('selfsigned.pem'),
    );
    final made = <_TrackedAdapter>[];
    final adapter = adapterOver(
      platform,
      createDartIoAdapter: (create) {
        final tracked = _TrackedAdapter(
          IOHttpClientAdapter(createHttpClient: create),
        );
        made.add(tracked);
        return tracked;
      },
    );
    await dio(adapter: adapter)
        .get<String>('https://localhost:${server.port}/api/v1/info');

    adapter.close();

    expect(platform.closed, isTrue);
    expect(made.single.closed, isTrue);
  });
}
