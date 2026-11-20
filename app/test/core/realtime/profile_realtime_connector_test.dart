import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/network/platform_network.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/tls_fixtures.dart';

final class _LockedSecureStore implements SecureStore {
  new(this.inner);

  final SecureStore inner;
  bool locked = false;

  @override
  Future<String?> read(String key) async {
    if (locked) throw Exception('Keychain locked');
    return await inner.read(key);
  }

  @override
  Future<void> write(String key, String value, {bool recoverLostKey = false}) =>
      inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> deleteAll() => inner.deleteAll();

  @override
  Future<void> flush() => inner.flush();
}

final class _CountingPreferences implements PreferencesStore {
  final _inner = MemoryPreferencesStore();
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> getString(String key) {
    if (key == NetworkProfiles.storageKey) reads++;
    return _inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) {
    if (key == NetworkProfiles.storageKey) writes++;
    return _inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _inner.remove(key);
}

/// Upgrades every request and records its headers.
final class _UpgradingServer {
  new(this._server) {
    _server.listen((request) async {
      requests.add(request.headers);
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
    });
  }

  static Future<_UpgradingServer> plain() async =>
      _UpgradingServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  static Future<_UpgradingServer> caSigned() async => _UpgradingServer(
    await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext('server.pem', 'server.key'),
    ),
  );

  static Future<_UpgradingServer> selfSigned() async => _UpgradingServer(
    await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext('selfsigned.pem', 'selfsigned.key'),
    ),
  );

  final HttpServer _server;
  final List<HttpHeaders> requests = [];
  final List<WebSocket> sockets = [];

  int get port => _server.port;

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }
}

final class _FakePlatformNetwork implements PlatformNetwork {
  new(this.userCaPems, {this.proxy = 'DIRECT'});

  final List<String> userCaPems;
  final String proxy;
  final asked = <Uri>[];

  @override
  Future<PlatformNetworkSettings> settingsFor(Uri url) async {
    asked.add(url);
    return (userCaPems: userCaPems, proxy: proxy);
  }
}

// Real upgrades on loopback, so what the server sees is checked.
void main() {
  late MemoryPreferencesStore preferences;
  late MemorySecureStore secureStore;
  late _LockedSecureStore secure;
  late NetworkProfiles profiles;
  late ProfileRealtimeConnector connector;

  setUp(() {
    preferences = MemoryPreferencesStore();
    secureStore = MemorySecureStore();
    secure = _LockedSecureStore(secureStore);
    profiles = NetworkProfiles(preferences: preferences, secureStore: secure);
    connector = ProfileRealtimeConnector(
      profiles: profiles,
      userAgent: 'Vikunja-App/test',
    );
  });

  Future<void> open(Uri url, {Map<String, String> headers = const {}}) async {
    final socket = await connector.connect(url, headers: headers);
    await socket.close();
  }

  group('ws://', () {
    late _UpgradingServer server;
    late OriginKey origin;
    late Uri url;

    setUp(() async {
      server = await _UpgradingServer.plain();
      origin = OriginKey.fromString('http://127.0.0.1:${server.port}');
      url = Uri.parse('ws://127.0.0.1:${server.port}/api/v2/ws');
    });
    tearDown(() => server.close());

    test('without consent the socket is never opened', () async {
      await expectLater(open(url), throwsA(isA<CleartextBlockedException>()));
      expect(server.requests, isEmpty);
    });

    test('without TLS settings of its own the socket goes through the '
        "system's proxy", () async {
      await profiles.consentToCleartext(
        OriginKey.of(Uri.parse('ws://tasks.invalid/api/v2/ws')),
      );
      await ProfileRealtimeConnector(
            profiles: profiles,
            userAgent: 'Vikunja-App/test',
            platformNetwork: _FakePlatformNetwork(
              const [],
              proxy: 'PROXY 127.0.0.1:${server.port}',
            ),
          )
          .connect(Uri.parse('ws://tasks.invalid/api/v2/ws'))
          .then((socket) => socket.close());

      expect(server.requests, hasLength(1));
    });

    test('with consent the upgrade carries the profile headers and the '
        "app's User-Agent; a request header of the same name wins", () async {
      await profiles.consentToCleartext(origin);
      await profiles.setHeaders(origin, {
        'CF-Access-Client-Id': 'dummy-id',
        'CF-Access-Client-Secret': 'dummy-secret',
      });

      await open(
        url,
        headers: const {
          'cf-access-client-id': 'from-caller',
          'User-Agent': 'replaced',
        },
      );

      final headers = server.requests.single;
      expect(headers.value('CF-Access-Client-Secret'), 'dummy-secret');
      expect(headers['cf-access-client-id'], ['from-caller']);
      expect(headers.value(HttpHeaders.userAgentHeader), 'Vikunja-App/test');
    });

    test('a stored value the transport refuses needs re-entry, never '
        'quoted', () async {
      await profiles.consentToCleartext(origin);
      await profiles.setHeaders(origin, {'X-Token': 'placeholder'});
      secureStore.values[NetworkProfileSecrets.keyFor(
        NetworkProfile.idFor(origin),
      )] = jsonEncode({
        'headers': {'X-Token': 'dummy forced'},
      });
      await profiles.reload();

      Object? failure;
      try {
        await open(url);
      } on Object catch (error) {
        failure = error;
      }

      expect(failure, isA<ConnectionProfileIncompleteException>());
      expect('$failure', isNot(contains('forced')));
      expect(server.requests, isEmpty);
    });

    group('a refused connection', () {
      late Uri closedUrl;
      late OriginKey closedOrigin;

      setUp(() async {
        final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = closed.port;
        await closed.close();
        closedUrl = Uri.parse('ws://127.0.0.1:$port/api/v2/ws');
        closedOrigin = OriginKey.fromString('http://127.0.0.1:$port');
        await profiles.consentToCleartext(closedOrigin);
      });

      test('stays a socket error with a header value short enough to occur '
          'by chance', () async {
        await profiles.setHeaders(closedOrigin, {'X-Gate': '1'});

        await expectLater(open(closedUrl), throwsA(isA<SocketException>()));
      });

      test(
        'keeps its kind without the text when that quotes a secret',
        () async {
          await profiles.setHeaders(closedOrigin, {'X-Gate': '127.0.0.1'});

          Object? failure;
          try {
            await open(closedUrl);
          } on Object catch (error) {
            failure = error;
          }

          expect(failure, isA<SocketException>());
          expect('$failure', isNot(contains('127.0.0.1')));
        },
      );
    });

    test('locked secrets fail closed', () async {
      await profiles.consentToCleartext(origin);
      await profiles.setHeaders(origin, {'X-Token': 'dummy'});
      await profiles.reload();
      secure.locked = true;

      await expectLater(
        open(url),
        throwsA(isA<ConnectionProfileLockedException>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('wss:// with a pin', () {
    late _UpgradingServer server;
    late OriginKey origin;
    late Uri url;

    setUp(() async {
      server = await _UpgradingServer.selfSigned();
      origin = OriginKey.fromString('https://localhost:${server.port}');
      url = Uri.parse('wss://localhost:${server.port}/api/v2/ws');
    });
    tearDown(() => server.close());

    Future<PinMismatch?> recordedIn(NetworkProfiles store) async {
      PinMismatch? mismatch;
      for (var i = 0; i < 40 && mismatch == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        mismatch = (await store.metadataFor(origin))?.lastPinMismatch;
      }
      return mismatch;
    }

    test('the pinned client upgrades with the headers', () async {
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      await profiles.setHeaders(origin, {'X-Token': 'dummy-wss'});

      await open(url);

      expect(server.requests.single.value('X-Token'), 'dummy-wss');
    });

    test(
      'another pin fails in the handshake and records the mismatch',
      () async {
        await profiles.trustCertificate(
          origin,
          tlsFixtureCertificate('server.pem'),
        );

        await expectLater(open(url), throwsA(isA<HandshakeException>()));

        final mismatch = await recordedIn(profiles);
        expect(mismatch?.sha256, tlsFixtureSha256('selfsigned.pem'));
        expect(server.requests, isEmpty);
      },
    );

    test('reconnects that meet the same certificate leave the stored '
        'settings alone', () async {
      final counted = _CountingPreferences();
      final store = NetworkProfiles(
        preferences: counted,
        secureStore: MemorySecureStore(),
        // Keeps the read settings cached, so any read is the recorder's.
        clock: () => DateTime.utc(2026, 11, 19, 12),
      );
      final socket = ProfileRealtimeConnector(
        profiles: store,
        userAgent: 'Vikunja-App/test',
      );
      await store.trustCertificate(origin, tlsFixtureCertificate('server.pem'));
      await expectLater(
        socket.connect(url),
        throwsA(isA<HandshakeException>()),
      );
      expect(await recordedIn(store), isNotNull);
      counted
        ..reads = 0
        ..writes = 0;

      for (var i = 0; i < 2; i++) {
        await expectLater(
          socket.connect(url),
          throwsA(isA<HandshakeException>()),
        );
      }
      await pumpEventQueue();

      expect(counted.reads, 0);
      expect(counted.writes, 0);
    });

    test(
      'after "Keep current" the same certificate is recorded again',
      () async {
        await profiles.trustCertificate(
          origin,
          tlsFixtureCertificate('server.pem'),
        );
        await expectLater(open(url), throwsA(isA<HandshakeException>()));
        expect(await recordedIn(profiles), isNotNull);

        await profiles.dismissPinMismatch(origin);
        await expectLater(open(url), throwsA(isA<HandshakeException>()));

        expect(
          (await recordedIn(profiles))?.sha256,
          tlsFixtureSha256('selfsigned.pem'),
        );
      },
    );

    test('without a profile the default context refuses the self-signed '
        'server', () async {
      await expectLater(open(url), throwsA(isA<HandshakeException>()));
    });

    test('without a profile a user CA from the platform opens a server it '
        'signed, asked for the handshake URL', () async {
      final signed = await _UpgradingServer.caSigned();
      addTearDown(signed.close);
      final signedUrl = Uri.parse('wss://localhost:${signed.port}/api/v2/ws');
      final without = _FakePlatformNetwork(const []);
      await expectLater(
        ProfileRealtimeConnector(
          profiles: profiles,
          userAgent: 'Vikunja-App/test',
          platformNetwork: without,
        ).connect(signedUrl),
        throwsA(isA<HandshakeException>()),
      );

      final platform = _FakePlatformNetwork([tlsFixtureText('ca.pem')]);
      await ProfileRealtimeConnector(
        profiles: profiles,
        userAgent: 'Vikunja-App/test',
        platformNetwork: platform,
      ).connect(signedUrl).then((socket) => socket.close());

      expect(platform.asked, [
        Uri.parse('https://localhost:${signed.port}/api/v2/ws'),
      ]);
    });

    test('a server with TLS settings of its own does not ask the '
        'platform', () async {
      await profiles.trustCertificate(
        origin,
        tlsFixtureCertificate('selfsigned.pem'),
      );
      final platform = _FakePlatformNetwork(const []);
      await ProfileRealtimeConnector(
        profiles: profiles,
        userAgent: 'Vikunja-App/test',
        platformNetwork: platform,
      ).connect(url).then((socket) => socket.close());

      expect(platform.asked, isEmpty);
    });
  });

  group('wss:// and a client certificate refused (TLS 1.3, dart:io)', () {
    ProfileRealtimeConnector checking() => ProfileRealtimeConnector(
      profiles: profiles,
      userAgent: 'Vikunja-App/test',
      refusalCheckTimeout: const Duration(seconds: 2),
      refusalCheckWait: const Duration(milliseconds: 300),
    );

    Future<Uri> trustedCa(int port) async {
      await profiles.trustCaCertificate(
        OriginKey.fromString('https://localhost:$port'),
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );
      return Uri.parse('wss://localhost:$port/api/v2/ws');
    }

    test('a server that ends the upgrade without naming the alert is '
        'confirmed by a handshake-only check', () async {
      final server = await MutualTlsServer.start();
      addTearDown(server.close);
      final url = await trustedCa(server.port);

      await expectLater(
        checking().connect(url),
        throwsA(isA<ClientCertificateRefusedException>()),
      );
      expect(server.requestsReceived, 0);
    });

    test('a server that hangs up on the upgrade but not on a handshake is '
        'not confirmed: the error stands and the socket retries', () async {
      final server = await HangUpTlsServer.start();
      addTearDown(server.close);
      final url = await trustedCa(server.port);

      await expectLater(
        checking().connect(url),
        throwsA(
          allOf(
            isA<IOException>(),
            isNot(isA<ClientCertificateRefusedException>()),
          ),
        ),
      );
    });
  });
}
