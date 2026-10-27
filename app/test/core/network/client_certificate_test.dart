import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/client_certificate.dart';

import '../../helpers/tls_fixtures.dart';

void main() {
  test('the PKCS#12 fixtures are accepted with their password', () {
    for (final name in [
      'client.p12',
      'client-legacy.p12',
      'wrong-client.p12',
    ]) {
      expect(
        validateClientCertificate(tlsFixture(name), tlsFixturePassword),
        isNull,
        reason: name,
      );
    }
  });

  test('a wrong password, garbage and a key-less PEM are one problem', () {
    final problems = [
      validateClientCertificate(tlsFixture('client.p12'), 'wrong'),
      validateClientCertificate(tlsFixture('client-legacy.p12'), ''),
      validateClientCertificate(
        Uint8List.fromList('not a certificate'.codeUnits),
        'x',
      ),
      validateClientCertificate(tlsFixture('client.pem'), ''),
    ];

    expect(
      problems,
      everyElement(ClientCertificateProblem.wrongPasswordOrUnsupported),
    );
  });

  test('empty and too large files, and over-long passwords', () {
    expect(
      validateClientCertificate(Uint8List(0), 'x'),
      ClientCertificateProblem.empty,
    );
    expect(
      validateClientCertificate(Uint8List(maxClientCertificateBytes + 1), 'x'),
      ClientCertificateProblem.tooLarge,
    );
    expect(
      validateClientCertificate(tlsFixture('client.p12'), 'p' * 1024),
      ClientCertificateProblem.wrongPasswordOrUnsupported,
    );
  });

  test('only the error type is logged, never the password', () async {
    final records = <String>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => records.add('${record.message} ${record.error ?? ''}'),
    );
    addTearDown(subscription.cancel);

    validateClientCertificate(tlsFixture('client.p12'), 'dummy-wrong-password');
    await pumpEventQueue();

    expect(records, isNotEmpty);
    expect(records.join('\n'), isNot(contains('dummy-wrong-password')));
  });

  // What dart:io (Dart 3.13.5) reports, so the mapping above stays right.
  group('the dart:io texts behind wrongPasswordOrUnsupported', () {
    test(
      'the chain with a wrong password: TlsException INCORRECT_PASSWORD',
      () {
        expect(
          () => SecurityContext().useCertificateChainBytes(
            tlsFixture('client.p12'),
            password: 'wrong',
          ),
          throwsA(
            isA<TlsException>().having(
              (e) => e.toString(),
              'text',
              contains('INCORRECT_PASSWORD'),
            ),
          ),
        );
      },
    );

    test('the key with a wrong password, empty input or garbage: '
        'ArgumentError "Expected private key, but none was found"', () {
      for (final bytes in [
        tlsFixture('client.p12'),
        Uint8List(0),
        Uint8List.fromList('garbage'.codeUnits),
      ]) {
        expect(
          () => SecurityContext().usePrivateKeyBytes(bytes, password: 'wrong'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'text',
              contains('Expected private key, but none was found'),
            ),
          ),
        );
      }
    });

    test('a password over 1023 characters: ArgumentError PEM_BUFSIZE', () {
      expect(
        () => SecurityContext().usePrivateKeyBytes(
          tlsFixture('client.p12'),
          password: 'p' * 1024,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'text',
            contains('Password length is greater than 1023 (PEM_BUFSIZE)'),
          ),
        ),
      );
    });
  });
}
