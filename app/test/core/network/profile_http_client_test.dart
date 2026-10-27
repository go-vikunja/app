import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/network/profile_http_client.dart';

import '../../helpers/tls_fixtures.dart';

// Real handshakes on loopback with the committed dummy set; plain test()
// so the sockets run outside a fake clock.
void main() {
  final at = DateTime.utc(2026, 10, 27, 12);

  OriginKey localhost(int port) =>
      OriginKey.fromString('https://localhost:$port');

  NetworkProfile pinned(OriginKey origin, String sha256) => NetworkProfile(
    origin: origin,
    pin: PinnedCertificate(
      certificate: CertificateInfo(
        sha256: sha256,
        subject: 'x',
        issuer: 'x',
        notBefore: at,
        notAfter: at,
      ),
      trustedAt: at,
    ),
  );

  NetworkProfile caTrusting(
    OriginKey origin, {
    ProfileSecrets? secrets,
    bool client = false,
  }) => NetworkProfile(
    origin: origin,
    caCertificate: CaCertificate(
      fileName: 'ca.pem',
      pem: tlsFixtureText('ca.pem'),
      importedAt: at,
    ),
    clientCertificate: client
        ? ClientCertificate(fileName: 'client.p12', importedAt: at)
        : null,
    secrets: secrets ?? ProfileSecrets.none,
  );

  Future<String> get(HttpClient client, OriginKey origin) async {
    try {
      final request = await client.getUrl(
        origin.uri.replace(path: '/api/v1/info'),
      );
      final response = await request.close();
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  group('pin', () {
    late RecordingTlsServer server;

    setUp(() async => server = await RecordingTlsServer.start());
    tearDown(() => server.close());

    test('the pinned self-signed leaf is accepted', () async {
      final origin = localhost(server.port);

      final body = await get(
        profileHttpClient(pinned(origin, tlsFixtureSha256('selfsigned.pem'))),
        origin,
      );

      expect(body, 'ok');
      expect(server.requests, hasLength(1));
    });

    test('another leaf fails in the handshake: no request byte reaches the '
        'server, and the mismatch hook sees the leaf', () async {
      final origin = localhost(server.port);
      final seen = <CertificateInfo>[];

      await expectLater(
        get(
          profileHttpClient(pinned(origin, '00' * 32), onPinMismatch: seen.add),
          origin,
        ),
        throwsA(isA<HandshakeException>()),
      );

      expect(server.requests, isEmpty);
      expect(seen.single.sha256, tlsFixtureSha256('selfsigned.pem'));
      expect(seen.single.selfSigned, isTrue);
    });

    test('a throwing hook does not break the handshake', () async {
      final origin = localhost(server.port);

      await expectLater(
        get(
          profileHttpClient(
            pinned(origin, '00' * 32),
            onPinMismatch: (_) => throw StateError('hook failed'),
          ),
          origin,
        ),
        throwsA(isA<HandshakeException>()),
      );
      expect(server.requests, isEmpty);
    });

    test('the pin holds only for its own host and port', () async {
      final sha256 = tlsFixtureSha256('selfsigned.pem');
      final check = pinnedCertificateCheck(localhost(server.port), sha256);
      X509Certificate? leaf;
      try {
        await SecureSocket.connect(
          'localhost',
          server.port,
          onBadCertificate: (certificate) {
            leaf = certificate;
            return false;
          },
        );
      } on HandshakeException {
        // Captured the leaf.
      }

      expect(check(leaf!, 'localhost', server.port), isTrue);
      expect(check(leaf!, 'LOCALHOST', server.port), isTrue);
      expect(check(leaf!, 'other.example', server.port), isFalse);
      expect(check(leaf!, 'localhost', server.port + 1), isFalse);
    });

    test('an IPv6 origin: the host check compares the bare address', () async {
      final RecordingTlsServer v6;
      try {
        v6 = await RecordingTlsServer.start(
          address: InternetAddress.loopbackIPv6,
        );
      } on SocketException {
        markTestSkipped('No IPv6 loopback here');
        return;
      }
      addTearDown(v6.close);
      final origin = OriginKey.of(Uri.parse('https://[::1]:${v6.port}'));
      expect(origin.host, '::1');

      final body = await get(
        profileHttpClient(pinned(origin, tlsFixtureSha256('selfsigned.pem'))),
        origin,
      );

      expect(body, 'ok');
    });
  });

  group('CA trust', () {
    test('a leaf from the trusted CA passes, without a callback', () async {
      final server = await RecordingTlsServer.start(
        certificate: 'server.pem',
        key: 'server.key',
      );
      addTearDown(server.close);

      final body = await get(
        profileHttpClient(caTrusting(localhost(server.port))),
        localhost(server.port),
      );

      expect(body, 'ok');
    });

    test('a leaf from elsewhere fails before any request', () async {
      final server = await RecordingTlsServer.start();
      addTearDown(server.close);

      await expectLater(
        get(
          profileHttpClient(caTrusting(localhost(server.port))),
          localhost(server.port),
        ),
        throwsA(isA<HandshakeException>()),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('mTLS (TLS 1.3)', () {
    late MutualTlsServer server;

    setUp(() async => server = await MutualTlsServer.start());
    tearDown(() => server.close());

    ProfileSecrets identity(String file) => ProfileSecrets(
      pkcs12: tlsFixture(file),
      pkcs12Password: tlsFixturePassword,
    );

    test('the client certificate from the PKCS#12 is presented', () async {
      final origin = localhost(server.port);

      final body = await get(
        profileHttpClient(
          caTrusting(origin, client: true, secrets: identity('client.p12')),
        ),
        origin,
      );

      expect(body, 'ok');
      expect(server.clientSubjects.single, contains('Rurana test client'));
    });

    test('the legacy PKCS#12 encryption works too', () async {
      final origin = localhost(server.port);

      final body = await get(
        profileHttpClient(
          caTrusting(
            origin,
            client: true,
            secrets: identity('client-legacy.p12'),
          ),
        ),
        origin,
      );

      expect(body, 'ok');
    });

    test(
      'without a certificate, and with one from another CA, the server '
      'ends the connection before the response and gets no request',
      () async {
        final origin = localhost(server.port);

        await expectLater(
          get(profileHttpClient(caTrusting(origin)), origin),
          throwsA(isA<HttpException>()),
        );
        await expectLater(
          get(
            profileHttpClient(
              caTrusting(
                origin,
                client: true,
                secrets: identity('wrong-client.p12'),
              ),
            ),
            origin,
          ),
          throwsA(anyOf(isA<HttpException>(), isA<SocketException>())),
        );
        expect(server.requestsReceived, 0);
      },
    );

    test('missing PKCS#12 secrets refuse to build the context', () {
      expect(
        () => profileSecurityContext(caTrusting(localhost(1), client: true)),
        throwsArgumentError,
      );
      expect(
        () => profileSecurityContext(
          caTrusting(
            localhost(1),
            client: true,
            secrets: ProfileSecrets(
              pkcs12: tlsFixture('client.p12'),
              pkcs12Password: 'wrong',
            ),
          ),
        ),
        throwsA(isA<TlsException>()),
      );
    });
  });
}
