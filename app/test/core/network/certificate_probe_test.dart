import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/certificate_probe.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  OriginKey localhost(int port) =>
      OriginKey.fromString('https://localhost:$port');

  group('fetch', () {
    test(
      'shows the leaf of a self-signed server without sending HTTP',
      () async {
        final server = await RecordingTlsServer.start();
        addTearDown(server.close);

        final result = await const CertificateProbe().fetch(
          localhost(server.port),
        );

        final certificate = (result as ProbedCertificate).certificate;
        expect(certificate.sha256, tlsFixtureSha256('selfsigned.pem'));
        expect(certificate.subject, contains('Rurana test self-signed'));
        expect(certificate.selfSigned, isTrue);
        expect(certificate.der, isNotEmpty);
        expect(result.deviceTrusted, isFalse);
        expect(server.requests, isEmpty);
      },
    );

    test('says whether the device trusts the certificate, without sending '
        'HTTP', () async {
      final server = await RecordingTlsServer.start(
        certificate: 'server.pem',
        key: 'server.key',
      );
      addTearDown(server.close);
      final origin = localhost(server.port);

      final trusted = await CertificateProbe(
        deviceTrust: SecurityContext()
          ..setTrustedCertificatesBytes(tlsFixture('ca.pem')),
      ).fetch(origin);
      final untrusted = await const CertificateProbe().fetch(origin);

      expect((trusted as ProbedCertificate).deviceTrusted, isTrue);
      expect(trusted.certificate.sha256, tlsFixtureSha256('server.pem'));
      expect((untrusted as ProbedCertificate).deviceTrusted, isFalse);
      expect(untrusted.certificate.sha256, tlsFixtureSha256('server.pem'));
      expect(server.requests, isEmpty);
    });

    test('shows the leaf of a CA-signed server, not the CA', () async {
      final server = await RecordingTlsServer.start(
        certificate: 'server.pem',
        key: 'server.key',
      );
      addTearDown(server.close);

      final result = await const CertificateProbe().fetch(
        localhost(server.port),
      );

      final certificate = (result as ProbedCertificate).certificate;
      expect(certificate.sha256, tlsFixtureSha256('server.pem'));
      expect(certificate.selfSigned, isFalse);
    });

    test('a closed port is unreachable', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();

      final result = await const CertificateProbe().fetch(localhost(port));

      expect(
        (result as CertificateProbeFailed).problem,
        CertificateProbeProblem.unreachable,
      );
    });

    test('a plain http server is not TLS', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) => request.response.close());

      final result = await const CertificateProbe().fetch(
        localhost(server.port),
      );

      expect(
        (result as CertificateProbeFailed).problem,
        CertificateProbeProblem.notTls,
      );
    });

    test('a server that never answers times out', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final held = <Socket>[];
      server.listen(held.add);
      addTearDown(() async {
        for (final socket in held) {
          socket.destroy();
        }
        await server.close();
      });

      final result = await const CertificateProbe(
        timeout: Duration(milliseconds: 300),
      ).fetch(localhost(server.port));

      expect(
        (result as CertificateProbeFailed).problem,
        CertificateProbeProblem.timeout,
      );
    });
  });

  group('verifyWithCa', () {
    test('trusted when the CA signed the leaf', () async {
      final server = await RecordingTlsServer.start(
        certificate: 'server.pem',
        key: 'server.key',
      );
      addTearDown(server.close);

      final check = await const CertificateProbe().verifyWithCa(
        localhost(server.port),
        tlsFixtureText('ca.pem'),
      );

      expect(check, isA<CaTrusted>());
      expect(server.requests, isEmpty);
    });

    test('not trusted: shows the leaf the CA did not sign', () async {
      final server = await RecordingTlsServer.start();
      addTearDown(server.close);

      final check = await const CertificateProbe().verifyWithCa(
        localhost(server.port),
        tlsFixtureText('ca.pem'),
      );

      expect(
        (check as CaNotTrusted).leaf.sha256,
        tlsFixtureSha256('selfsigned.pem'),
      );
    });

    test('trusted on an mTLS server that then refuses the missing client '
        'certificate', () async {
      final server = await MutualTlsServer.start();
      addTearDown(server.close);

      final check = await const CertificateProbe().verifyWithCa(
        localhost(server.port),
        tlsFixtureText('ca.pem'),
      );

      expect(check, isA<CaTrusted>());
    });

    test("presents the origin's stored client certificate", () async {
      final server = await MutualTlsServer.start();
      addTearDown(server.close);
      final profiles = NetworkProfiles(
        preferences: MemoryPreferencesStore(),
        secureStore: MemorySecureStore(),
      );
      await profiles.setClientCertificate(
        localhost(server.port),
        fileName: 'client.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );

      final check = await CertificateProbe(profiles: profiles)
          .verifyWithCa(localhost(server.port), tlsFixtureText('ca.pem'));
      for (var i = 0; i < 40 && server.clientSubjects.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      expect(check, isA<CaTrusted>());
      expect(server.clientSubjects.single, contains('Rurana test client'));
    });

    test('a file with a private key, without certificates or with other '
        'blocks is invalid', () async {
      const probe = CertificateProbe();
      final origin = localhost(1);

      for (final pem in [
        tlsFixtureText('server.key'),
        '${tlsFixtureText('ca.pem')}\n${tlsFixtureText('server.key')}',
        'not a pem',
        '-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----\n',
        '-----BEGIN CERTIFICATE-----\nnot base64\n-----END CERTIFICATE-----\n',
        '${tlsFixtureText('ca.pem')}\n' * 700,
      ]) {
        expect(
          await probe.verifyWithCa(origin, pem),
          isA<CaFileInvalid>(),
          reason: pem.length > 80 ? pem.substring(0, 80) : pem,
        );
      }
    });

    test('an unreachable server fails the check', () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();

      final check = await const CertificateProbe().verifyWithCa(
        localhost(port),
        tlsFixtureText('ca.pem'),
      );

      expect(
        (check as CaCheckFailed).problem,
        CertificateProbeProblem.unreachable,
      );
    });
  });
}
