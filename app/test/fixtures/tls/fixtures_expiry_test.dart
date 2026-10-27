import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _regenerate =
    'regenerate them with tool/gen_tls_test_certs.sh --fixtures';
const _margin = Duration(days: 60);

List<int> _fixture(String name) =>
    File('test/fixtures/tls/$name').readAsBytesSync();

Future<T> _handshake<T>(Future<T> step) async {
  try {
    return await step;
  } on TlsException catch (error) {
    fail('A handshake with the TLS fixtures failed ($error); $_regenerate.');
  }
}

void _expectValid(String name, X509Certificate certificate) {
  final expires = certificate.endValidity.toUtc().toIso8601String();
  expect(
    certificate.endValidity.difference(DateTime.now()),
    greaterThan(_margin),
    reason: '$name expires on $expires; $_regenerate.',
  );
}

// Reads both CA-chained leaves through one real mTLS handshake on loopback,
// the way the CA-trust and client-certificate tests use them.
void main() {
  test('the CA-chained TLS fixture leaves stay valid for 60 days', () async {
    final password = File('test/fixtures/tls/client-p12-password.txt')
        .readAsStringSync();
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      SecurityContext()
        ..useCertificateChainBytes(_fixture('server.pem'))
        ..usePrivateKeyBytes(_fixture('server.key'))
        ..setTrustedCertificatesBytes(_fixture('client-ca.pem'))
        ..setClientAuthoritiesBytes(_fixture('client-ca.pem')),
      requestClientCertificate: true,
      requireClientCertificate: true,
    );
    addTearDown(server.close);
    final accepted = server.first;

    final client = await _handshake(
      SecureSocket.connect(
        'localhost',
        server.port,
        context: SecurityContext()
          ..setTrustedCertificatesBytes(_fixture('ca.pem'))
          ..useCertificateChainBytes(_fixture('client.p12'), password: password)
          ..usePrivateKeyBytes(_fixture('client.p12'), password: password),
      ),
    );
    addTearDown(client.destroy);
    final serverSide = await _handshake(accepted);
    addTearDown(serverSide.destroy);

    _expectValid('server.pem', client.peerCertificate!);
    _expectValid('client.p12', serverSide.peerCertificate!);
  });
}
