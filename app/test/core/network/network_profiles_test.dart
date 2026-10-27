import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/tls_fixtures.dart';

/// Counts reads and can fail them, like a Keychain before the first unlock.
final class _SecureStore implements SecureStore {
  final inner = MemorySecureStore();
  int reads = 0;
  Exception? readFailure;

  @override
  Future<String?> read(String key) async {
    reads++;
    if (readFailure case final failure?) throw failure;
    return await inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> deleteAll() => inner.deleteAll();
}

/// Records writes in order with the secure store's operations, and can fail
/// reads.
final class _Preferences implements PreferencesStore {
  new(this.log);

  final List<String> log;
  final values = <String, String>{};
  Exception? readFailure;

  @override
  Future<String?> getString(String key) async {
    if (readFailure case final failure?) throw failure;
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    log.add('preferences $key');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

final class _SecretsLog extends _SecureStore {
  new(this.log);

  final List<String> log;

  @override
  Future<void> write(String key, String value) {
    log.add('write $key');
    return super.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    log.add('delete $key');
    return super.delete(key);
  }
}

void main() {
  final https = OriginKey.fromString('https://vikunja.example.com:443');
  final http = OriginKey.fromString('http://192.168.1.20:3456');
  final other = OriginKey.fromString('https://other.example.com:8443');
  late List<String> log;
  late _Preferences preferences;
  late _SecretsLog secure;
  late DateTime now;
  late List<Uri> accountRoots;

  setUp(() {
    log = [];
    preferences = _Preferences(log);
    secure = _SecretsLog(log);
    now = DateTime.utc(2026, 10, 27, 12);
    accountRoots = [];
  });

  NetworkProfiles profiles() => NetworkProfiles(
    preferences: preferences,
    secureStore: secure,
    accountRoots: () async => accountRoots,
    clock: () => now,
  );

  Map<String, Object?> stored() =>
      jsonDecode(preferences.values[NetworkProfiles.storageKey]!)
          as Map<String, Object?>;

  Map<String, Object?> storedEntry(OriginKey origin) =>
      (stored()['profiles']! as Map<String, Object?>)['$origin']!
          as Map<String, Object?>;

  final certificate = tlsFixtureCertificate('selfsigned.pem');
  final other1 = CertificateInfo(
    sha256: '11' * 32,
    subject: '/CN=impostor',
    issuer: '/CN=impostor',
    notBefore: DateTime.utc(2026),
    notAfter: DateTime.utc(2027),
  );

  group('reading', () {
    test('no profile without stored settings', () async {
      expect(await profiles().forOrigin(https), isNull);
    });

    test('a pin and its secrets-free metadata never read secure storage, '
        'and neither does a consent', () async {
      final writer = profiles();
      await writer.trustCertificate(https, certificate);
      await writer.consentToCleartext(http);
      secure.reads = 0;

      final reader = profiles();
      final pinned = await reader.forOrigin(https);
      final consented = await reader.forOrigin(http);

      expect(pinned?.pin?.sha256, certificate.sha256);
      expect(consented?.hasCleartextConsent, isTrue);
      expect(secure.reads, 0);
    });

    test('headers come with their values, only the named ones', () async {
      await profiles().setHeaders(https, {
        'CF-Access-Client-Id': ' dummy-id ',
        'CF-Access-Client-Secret': 'dummy-secret',
      });

      final profile = await profiles().forOrigin(https);

      expect(profile?.headers, {
        'CF-Access-Client-Id': 'dummy-id',
        'CF-Access-Client-Secret': 'dummy-secret',
      });
      expect(storedEntry(https)['headerNames'], [
        'CF-Access-Client-Id',
        'CF-Access-Client-Secret',
      ]);
      expect(
        preferences.values[NetworkProfiles.storageKey],
        isNot(contains('dummy-secret')),
      );
    });

    test('metadata is cached for 30 s, then read again', () async {
      final reader = profiles();
      expect(await reader.metadataFor(https), isNull);
      // Another isolate writes.
      final elsewhere = NetworkProfiles(
        preferences: preferences,
        secureStore: secure,
      );
      await elsewhere.trustCertificate(https, certificate);
      // Same isolate here, so the write is seen at once.
      expect((await reader.metadataFor(https))?.pin, isNotNull);

      preferences.values[NetworkProfiles.storageKey] = jsonEncode({
        'schemaVersion': 1,
        'cleartextMigrated': true,
        'profiles': <String, Object?>{},
      });
      expect((await reader.metadataFor(https))?.pin, isNotNull);
      now = now.add(const Duration(seconds: 31));
      expect(await reader.metadataFor(https), isNull);
    });
  });

  group('secrets that cannot be read', () {
    test('a throwing read fails closed as locked, retried after 5 s', () async {
      await profiles().setHeaders(https, {'X-Token': 'dummy'});
      final reader = profiles();
      secure.readFailure = Exception('Keychain locked');

      await expectLater(
        reader.forOrigin(https),
        throwsA(isA<ConnectionProfileLockedException>()),
      );
      secure
        ..readFailure = null
        ..reads = 0;
      await expectLater(
        reader.forOrigin(https),
        throwsA(isA<ConnectionProfileLockedException>()),
      );
      expect(secure.reads, 0, reason: 'fails fast within 5 s');

      now = now.add(const Duration(seconds: 5));
      expect((await reader.forOrigin(https))?.headers, {'X-Token': 'dummy'});
    });

    test('concurrent first reads share one secure read', () async {
      await profiles().setHeaders(https, {'X-Token': 'dummy'});
      final reader = profiles();
      secure.reads = 0;

      await Future.wait([reader.forOrigin(https), reader.forOrigin(https)]);

      expect(secure.reads, 1);
    });

    test('missing or partial secrets need re-entry', () async {
      final writer = profiles();
      await writer.setHeaders(https, {'X-A': 'a', 'X-B': 'b'});
      final key = NetworkProfileSecrets.keyFor(NetworkProfile.idFor(https));

      secure.inner.values[key] = jsonEncode({
        'headers': {'X-A': 'a'},
      });
      await expectLater(
        profiles().forOrigin(https),
        throwsA(isA<ConnectionProfileIncompleteException>()),
      );

      secure.inner.values[key] = 'not json';
      await expectLater(
        profiles().forOrigin(https),
        throwsA(isA<ConnectionProfileIncompleteException>()),
      );

      secure.inner.values.remove(key);
      final reader = profiles();
      await expectLater(
        reader.forOrigin(https),
        throwsA(isA<ConnectionProfileIncompleteException>()),
      );
      expect(
        (await reader.stateFor(https)).status,
        ConnectionProfileStatus.needsReentry,
      );
    });

    test('a client certificate without its password needs re-entry', () async {
      await profiles().setClientCertificate(
        https,
        fileName: 'client.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );
      final key = NetworkProfileSecrets.keyFor(NetworkProfile.idFor(https));
      final secrets =
          jsonDecode(secure.inner.values[key]!) as Map<String, Object?>;
      secure.inner.values[key] = jsonEncode(
        {...secrets}..remove('pkcs12Password'),
      );

      await expectLater(
        profiles().forOrigin(https),
        throwsA(isA<ConnectionProfileIncompleteException>()),
      );
    });

    test('unreadable secrets show as unavailable', () async {
      await profiles().setHeaders(https, {'X-Token': 'dummy'});
      secure.readFailure = Exception('locked');

      final state = await profiles().stateFor(https);

      expect(state.status, ConnectionProfileStatus.unavailable);
      expect(state.profile?.headerNames, ['X-Token']);
    });
  });

  group('damaged metadata', () {
    for (final (what, json) in [
      ('not JSON', '{nope'),
      (
        'a newer schema',
        jsonEncode({'schemaVersion': 2, 'profiles': <String, Object?>{}}),
      ),
      (
        'an entry with both a pin and a CA',
        jsonEncode({
          'schemaVersion': 1,
          'cleartextMigrated': true,
          'profiles': {
            '$https': {
              'revision': 1,
              'pin': {
                ...certificate.toJson(),
                'trustedAt': '2026-10-27T12:00:00Z',
              },
              'caCertificate': {
                'fileName': 'ca.pem',
                'pem': tlsFixtureText('ca.pem'),
                'importedAt': '2026-10-27T12:00:00Z',
              },
            },
          },
        }),
      ),
    ]) {
      test('$what: every read and edit fails closed until reset', () async {
        preferences.values[NetworkProfiles.storageKey] = json;
        final damaged = profiles();

        await expectLater(
          damaged.forOrigin(other),
          throwsA(isA<ConnectionProfilesDamagedException>()),
        );
        await expectLater(
          damaged.consentToCleartext(http),
          throwsA(isA<ConnectionProfilesDamagedException>()),
        );
        expect(
          (await damaged.stateFor(https)).status,
          ConnectionProfileStatus.damaged,
        );

        await damaged.resetAll();

        expect(await damaged.forOrigin(https), isNull);
        expect(stored()['profiles'], isEmpty);
      });
    }

    test(
      'a preferences read that throws is unavailable, not damaged',
      () async {
        preferences.readFailure = Exception('platform');
        final reader = profiles();

        await expectLater(
          reader.forOrigin(https),
          throwsA(isA<ConnectionProfileLockedException>()),
        );
        expect(
          (await reader.stateFor(https)).status,
          ConnectionProfileStatus.unavailable,
        );
        preferences.readFailure = null;
        now = now.add(const Duration(seconds: 5));
        expect(await reader.forOrigin(https), isNull);
      },
    );

    test('the reset deletes the secrets of every origin it can derive and '
        'does not migrate consents again', () async {
      accountRoots = [Uri.parse('http://192.168.1.20:3456/')];
      final writer = profiles();
      await writer.setHeaders(other, {'X-Token': 'dummy'});
      await writer.setHeaders(http, {'X-Token': 'dummy'});
      expect(secure.inner.values, hasLength(2));

      await writer.resetAll();

      expect(secure.inner.values, isEmpty);
      expect(stored()['cleartextMigrated'], isTrue);
      expect(await profiles().forOrigin(http), isNull);
    });
  });

  group('cleartext migration', () {
    test('http accounts get consent once; https ones and existing entries '
        'nothing', () async {
      accountRoots = [
        Uri.parse('http://192.168.1.20:3456/'),
        Uri.parse('https://vikunja.example.com/'),
      ];

      final profile = await profiles().forOrigin(http);

      expect(profile?.cleartextConsentAt, now);
      expect(profile?.revision, 1);
      expect(await profiles().forOrigin(https), isNull);
      expect(stored()['cleartextMigrated'], isTrue);
    });

    test("one instance's revoke survives another's migration run", () async {
      accountRoots = [Uri.parse('http://192.168.1.20:3456/')];
      final a = profiles();
      final b = profiles();
      await a.forOrigin(http);

      await a.revokeCleartext(http);
      // B never loaded; its first read must not migrate again.
      final seenByB = await b.forOrigin(http);

      expect(seenByB?.hasCleartextConsent ?? false, isFalse);
      expect(stored()['profiles'], isNot(contains('$http')));
    });

    test('an edit before any read writes the migration with it', () async {
      accountRoots = [Uri.parse('http://192.168.1.20:3456/')];

      await profiles().trustCertificate(https, certificate);

      expect(storedEntry(http)['cleartextConsentAt'], isNotNull);
      expect(storedEntry(https)['pin'], isNotNull);
    });
  });

  group('edits', () {
    test('a pin and a CA replace each other and clear a mismatch', () async {
      final edits = profiles();
      await edits.trustCertificate(https, certificate);
      await edits.recordPinMismatch(https, other1);
      expect((await edits.metadataFor(https))?.lastPinMismatch, isNotNull);

      await edits.trustCaCertificate(
        https,
        fileName: 'ca.pem',
        pem: tlsFixtureText('ca.pem'),
      );
      var profile = await edits.metadataFor(https);
      expect(profile?.pin, isNull);
      expect(profile?.caCertificate?.fileName, 'ca.pem');
      expect(profile?.lastPinMismatch, isNull);

      await edits.trustCertificate(https, certificate);
      profile = await edits.metadataFor(https);
      expect(profile?.caCertificate, isNull);
      expect(profile?.pin?.trustedAt, now);
    });

    test('a CA file with a private key is refused', () {
      expect(
        () => profiles().trustCaCertificate(
          https,
          fileName: 'server.key',
          pem: tlsFixtureText('server.key'),
        ),
        throwsArgumentError,
      );
    });

    test('every edit raises the revision; a mismatch record does not and '
        'is written once', () async {
      final edits = profiles();
      await edits.trustCertificate(https, certificate);
      final first = (await edits.metadataFor(https))!.revision;

      await edits.recordPinMismatch(https, other1);
      log.clear();
      await edits.recordPinMismatch(https, other1);
      expect(log, isEmpty);
      expect((await edits.metadataFor(https))!.revision, first);

      await edits.dismissPinMismatch(https);
      expect((await edits.metadataFor(https))!.revision, first);
      await edits.setHeaders(https, {'X-Token': 'dummy'});
      expect((await edits.metadataFor(https))!.revision, first + 1);
    });

    test('a forgotten origin set up again never repeats a revision', () async {
      final edits = profiles();
      await edits.trustCertificate(https, certificate);
      await edits.setHeaders(https, {'X-Token': 'dummy'});
      final before = (await edits.metadataFor(https))!.revision;

      await edits.forget(https);
      await edits.trustCertificate(https, certificate);

      expect((await edits.metadataFor(https))!.revision, greaterThan(before));
    });

    test(
      "one instance's new pin survives another's stale mismatch record",
      () async {
        final a = profiles();
        final b = profiles();
        await a.trustCertificate(https, certificate);
        await b.forOrigin(https);

        await a.trustCertificate(https, other1);
        // B still holds the old pin; the server it saw showed other1.
        await b.recordPinMismatch(https, other1);

        final profile = await profiles().metadataFor(https);
        expect(profile?.pin?.sha256, other1.sha256);
        expect(profile?.lastPinMismatch, isNull);
      },
    );

    test('secrets are written before the metadata, deleted after it', () async {
      final edits = profiles();
      final key = NetworkProfileSecrets.keyFor(NetworkProfile.idFor(https));

      await edits.setHeaders(https, {'X-Token': 'dummy'});
      expect(log, ['write $key', 'preferences ${NetworkProfiles.storageKey}']);

      log.clear();
      await edits.forget(https);
      expect(log, ['preferences ${NetworkProfiles.storageKey}', 'delete $key']);
      expect(secure.inner.values, isEmpty);
    });

    test('headers and a client certificate share one entry and keep each '
        'other', () async {
      final edits = profiles();
      await edits.setHeaders(https, {'X-Token': 'dummy'});
      await edits.setClientCertificate(
        https,
        fileName: 'client.p12',
        bytes: tlsFixture('client.p12'),
        password: tlsFixturePassword,
      );

      var profile = await profiles().forOrigin(https);
      expect(profile?.headers, {'X-Token': 'dummy'});
      expect(profile?.secrets.pkcs12, tlsFixture('client.p12'));

      await edits.setHeaders(https, {});
      profile = await profiles().forOrigin(https);
      expect(profile?.headerNames, isEmpty);
      expect(profile?.secrets.pkcs12Password, tlsFixturePassword);

      await edits.removeClientCertificate(https);
      expect(await profiles().forOrigin(https), isNull);
      expect(secure.inner.values, isEmpty);
    });

    test('a client certificate dart:io refuses is not stored', () async {
      await expectLater(
        profiles().setClientCertificate(
          https,
          fileName: 'client.p12',
          bytes: tlsFixture('client.p12'),
          password: 'wrong',
        ),
        throwsArgumentError,
      );
      expect(preferences.values, isEmpty);
    });

    test('headers HeaderRules refuses are not stored, and the error names '
        'no value', () async {
      await expectLater(
        profiles().setHeaders(https, {'X-Token': 'dummy secret'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'text',
            isNot(contains('dummy')),
          ),
        ),
      );
      expect(secure.inner.values, isEmpty);
    });

    test('headers for an http origin need its consent first', () async {
      final edits = profiles();
      await expectLater(
        edits.setHeaders(http, {'X-Token': 'dummy'}),
        throwsStateError,
      );

      await edits.consentToCleartext(http);
      await edits.setHeaders(http, {'X-Token': 'dummy'});

      expect((await edits.forOrigin(http))?.headers, {'X-Token': 'dummy'});
    });

    test(
      'headers of an http origin can be removed without its consent',
      () async {
        final edits = profiles();
        await edits.consentToCleartext(http);
        await edits.setHeaders(http, {'X-Token': 'dummy'});
        await edits.revokeCleartext(http);

        await edits.setHeaders(http, {});

        expect(await edits.metadataFor(http), isNull);
        expect(secure.inner.values, isEmpty);
      },
    );

    test('pins and certificates are for https, consent for http', () {
      final edits = profiles();
      expect(
        () => edits.trustCertificate(http, certificate),
        throwsArgumentError,
      );
      expect(() => edits.consentToCleartext(https), throwsArgumentError);
      expect(() => edits.revokeCleartext(https), throwsArgumentError);
    });

    test('a revoked consent with nothing else removes the entry', () async {
      final edits = profiles();
      await edits.consentToCleartext(http);

      await edits.revokeCleartext(http);

      expect(await edits.metadataFor(http), isNull);
    });

    test('other entries and unknown fields are kept as stored', () async {
      preferences.values[NetworkProfiles.storageKey] = jsonEncode({
        'schemaVersion': 1,
        'cleartextMigrated': true,
        'futureTopLevel': 'kept',
        'profiles': {
          'not an origin key': {'kept': true},
          '$other': {'revision': 3, 'futureField': 1},
        },
      });

      await profiles().trustCertificate(https, certificate);

      final document = stored();
      expect(document['futureTopLevel'], 'kept');
      final entries = document['profiles']! as Map<String, Object?>;
      expect(entries['not an origin key'], {'kept': true});
      expect(entries['$other'], {'revision': 3, 'futureField': 1});
    });

    test('edits announce their origin', () async {
      final edits = profiles();
      final changes = <OriginKey?>[];
      final subscription = edits.changes.listen(changes.add);
      addTearDown(subscription.cancel);

      await edits.trustCertificate(https, certificate);
      await edits.resetAll();
      await pumpEventQueue();

      expect(changes, [https, null]);
    });
  });

  group('state for screens', () {
    test('ok, mismatch and no profile', () async {
      final edits = profiles();
      expect((await edits.stateFor(https)).profile, isNull);

      await edits.trustCertificate(https, certificate);
      expect((await edits.stateFor(https)).status, ConnectionProfileStatus.ok);

      await edits.recordPinMismatch(https, other1);
      final state = await edits.stateFor(https);
      expect(state.status, ConnectionProfileStatus.pinMismatch);
      expect(state.profile?.lastPinMismatch?.sha256, other1.sha256);
    });
  });

  test('writes of instances in one isolate run one at a time', () async {
    final a = profiles();
    final b = profiles();

    await Future.wait([
      a.setHeaders(https, {'X-A': 'a'}),
      b.trustCertificate(other, certificate),
      a.consentToCleartext(http),
    ]);

    final entries = stored()['profiles']! as Map<String, Object?>;
    expect(entries.keys, containsAll(['$https', '$other', '$http']));
  });
}
