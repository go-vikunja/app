import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';
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
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> deleteAll() => inner.deleteAll();
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

        PinMismatch? mismatch;
        for (var i = 0; i < 40 && mismatch == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          mismatch = (await profiles.metadataFor(origin))?.lastPinMismatch;
        }
        expect(mismatch?.sha256, tlsFixtureSha256('selfsigned.pem'));
        expect(server.requests, isEmpty);
      },
    );

    test('without a profile the default context refuses the self-signed '
        'server', () async {
      await expectLater(open(url), throwsA(isA<HandshakeException>()));
    });
  });
}
