import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/network/client_certificate.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/tls_fixtures.dart';

// Runs the profile paths that log (requests, failures, refused settings,
// the realtime connector) with every logger on, and greps the output.
void main() {
  test('header values and the PKCS#12 password never reach a log', () async {
    final access = tlsAccessValues();
    final id = access['RURANA_TEST_ACCESS_ID']!;
    final secret = access['RURANA_TEST_ACCESS_SECRET']!;
    final password = tlsFixturePassword;
    expect([id, secret, password], everyElement(isNotEmpty));

    final logs = <String>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(
      (record) => logs.add(
        '${record.loggerName} ${record.message} ${record.error ?? ''} '
        '${record.stackTrace ?? ''}',
      ),
    );
    addTearDown(subscription.cancel);

    final secureStore = MemorySecureStore();
    final profiles = NetworkProfiles(
      preferences: MemoryPreferencesStore(),
      secureStore: secureStore,
    );
    final pinnedServer = await RecordingTlsServer.start();
    addTearDown(pinnedServer.close);
    final mtlsServer = await MutualTlsServer.start();
    addTearDown(mtlsServer.close);
    final pinned = OriginKey.fromString(
      'https://localhost:${pinnedServer.port}',
    );
    final mtls = OriginKey.fromString('https://localhost:${mtlsServer.port}');
    final headers = {
      'CF-Access-Client-Id': id,
      'CF-Access-Client-Secret': secret,
    };

    await profiles.trustCertificate(
      pinned,
      tlsFixtureCertificate('selfsigned.pem'),
    );
    await profiles.setHeaders(pinned, headers);
    await profiles.trustCaCertificate(
      mtls,
      fileName: 'ca.pem',
      pem: tlsFixtureText('ca.pem'),
    );
    await profiles.setHeaders(mtls, headers);
    await profiles.setClientCertificate(
      mtls,
      fileName: 'wrong-client.p12',
      bytes: tlsFixture('wrong-client.p12'),
      password: password,
    );
    validateClientCertificate(tlsFixture('client.p12'), '$password-wrong');

    // Debug mode, so the request log is on.
    final dio = createDio(userAgent: 'Rurana/test', profiles: profiles);
    addTearDown(dio.close);
    await dio.get<String>('https://localhost:${pinnedServer.port}/api/v1/info');
    await expectLater(
      dio.get<String>('https://localhost:${mtlsServer.port}/api/v1/info'),
      throwsA(isA<DioException>()),
    );

    // A stored value forced past validation, on both the request and the
    // socket path.
    secureStore.values[NetworkProfileSecrets.keyFor(
      NetworkProfile.idFor(pinned),
    )] = jsonEncode({
      'headers': {
        'CF-Access-Client-Id': '$id ',
        'CF-Access-Client-Secret': secret,
      },
    });
    await profiles.reload();
    await expectLater(
      dio.get<String>('https://localhost:${pinnedServer.port}/api/v1/info'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      ProfileRealtimeConnector(
        profiles: profiles,
        userAgent: 'Rurana/test',
      ).connect(Uri.parse('wss://localhost:${pinnedServer.port}/api/v2/ws')),
      throwsA(anything),
    );
    await pumpEventQueue();

    expect(logs, isNotEmpty);
    final output = logs.join('\n');
    for (final value in [id, secret, password]) {
      expect(output, isNot(contains(value)));
    }
  });
}
