import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

void main() {
  final origin = OriginKey.fromString('https://vikunja.example.com:443');
  final certificate = CertificateInfo(
    sha256: 'AB' * 32,
    subject: '/CN=vikunja.example.com',
    issuer: '/CN=vikunja.example.com',
    notBefore: DateTime.utc(2026),
    notAfter: DateTime.utc(2027),
  );
  final at = DateTime.utc(2026, 10, 27, 12);

  test('a certificate valid for less than 100 days is short-lived', () {
    CertificateInfo valid(Duration lifetime) => CertificateInfo(
      sha256: certificate.sha256,
      subject: certificate.subject,
      issuer: certificate.issuer,
      notBefore: certificate.notBefore,
      notAfter: certificate.notBefore.add(lifetime),
    );

    expect(valid(const Duration(hours: 12)).isShortLived, isTrue);
    expect(valid(const Duration(days: 90)).isShortLived, isTrue);
    expect(valid(const Duration(days: 100)).isShortLived, isFalse);
    expect(certificate.isShortLived, isFalse);
  });

  test('the id is the first 32 hex digits of sha256(origin string)', () {
    expect(
      NetworkProfile.idFor(origin),
      // sha256("https://vikunja.example.com:443")
      allOf(hasLength(32), matches(RegExp(r'^[0-9a-f]{32}$'))),
    );
    expect(NetworkProfile.idFor(origin), NetworkProfile.idFor(origin));
    expect(
      NetworkProfile.idFor(origin),
      isNot(NetworkProfile.idFor(OriginKey.fromString('https://a.b:443'))),
    );
  });

  test('round-trips through JSON and keeps unknown fields', () {
    final json = {
      'revision': 4,
      'pin': {...certificate.toJson(), 'trustedAt': at.toIso8601String()},
      'clientCertificate': {
        'fileName': 'phone.p12',
        'importedAt': at.toIso8601String(),
      },
      'headerNames': ['CF-Access-Client-Id', 'CF-Access-Client-Secret'],
      'lastPinMismatch': {
        ...certificate.toJson(),
        'sha256': 'CD' * 32,
        'seenAt': at.toIso8601String(),
      },
      'futureField': {'kept': true},
    };

    final profile = NetworkProfile.fromJson(
      origin,
      jsonDecode(jsonEncode(json)),
    );

    expect(profile.revision, 4);
    expect(profile.pin?.sha256, 'AB' * 32);
    expect(profile.pin?.trustedAt, at);
    expect(profile.clientCertificate?.fileName, 'phone.p12');
    expect(profile.headerNames, hasLength(2));
    expect(profile.lastPinMismatch?.sha256, 'CD' * 32);
    expect(profile.needsDartIo, isTrue);
    expect(profile.namesSecrets, isTrue);
    final written = profile.toJson();
    expect(written['futureField'], {'kept': true});
    expect(written['id'], profile.id);
    expect(
      NetworkProfile.fromJson(origin, jsonDecode(jsonEncode(written))).toJson(),
      written,
    );
  });

  test('an entry with both a pin and a CA cannot be read', () {
    expect(
      () => NetworkProfile.fromJson(origin, {
        'revision': 1,
        'pin': {...certificate.toJson(), 'trustedAt': at.toIso8601String()},
        'caCertificate': {
          'fileName': 'ca.pem',
          'pem': '-----BEGIN CERTIFICATE-----',
          'importedAt': at.toIso8601String(),
        },
      }),
      throwsFormatException,
    );
  });

  test('a malformed entry cannot be read', () {
    for (final json in <Object?>[
      'nope',
      {'revision': 'one'},
      {'revision': 1, 'headerNames': 'X'},
      {
        'revision': 1,
        'pin': {'sha256': 'not hex'},
      },
    ]) {
      expect(
        () => NetworkProfile.fromJson(origin, json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });

  test('header-only profiles stay on the native stack', () {
    final headers = NetworkProfile(origin: origin, headerNames: const ['X']);

    expect(headers.needsDartIo, isFalse);
    expect(headers.namesSecrets, isTrue);
    expect(NetworkProfile(origin: origin).isEmpty, isTrue);
  });

  test('only the headers the metadata names are sent', () {
    final profile = NetworkProfile(
      origin: origin,
      headerNames: const ['X-Named'],
      secrets: const ProfileSecrets(headers: {'X-Named': 'a', 'X-Stale': 'b'}),
    );

    expect(profile.headers, {'X-Named': 'a'});
  });

  test('no secret in toString or in the metadata JSON', () {
    final profile = NetworkProfile(
      origin: origin,
      headerNames: const ['CF-Access-Client-Secret'],
      clientCertificate: ClientCertificate(fileName: 'p.p12', importedAt: at),
      secrets: ProfileSecrets(
        headers: const {'CF-Access-Client-Secret': 'dummy-header-secret'},
        pkcs12: Uint8List.fromList([1, 2, 3]),
        pkcs12Password: 'dummy-fixture-password',
      ),
    );

    for (final text in [
      profile.toString(),
      jsonEncode(profile.toJson()),
      profile.secrets.toString(),
    ]) {
      expect(text, isNot(contains('dummy-header-secret')));
      expect(text, isNot(contains('dummy-fixture-password')));
    }
    expect(profile.secrets.secretTexts, [
      'dummy-header-secret',
      'dummy-fixture-password',
    ]);
  });

  test('secrets round-trip through their secure-storage JSON', () {
    final stored = NetworkProfileSecrets.encode(
      ProfileSecrets(
        headers: const {'X': 'v'},
        pkcs12: Uint8List.fromList([0, 255, 7]),
        pkcs12Password: 'pw',
      ),
    );

    final secrets = NetworkProfileSecrets.decode(stored);

    expect(secrets.headers, {'X': 'v'});
    expect(secrets.pkcs12, [0, 255, 7]);
    expect(secrets.pkcs12Password, 'pw');
    expect(
      () => NetworkProfileSecrets.decode('{"pkcs12":"%%%"}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          isNot(contains('%%%')),
        ),
      ),
    );
  });
}
