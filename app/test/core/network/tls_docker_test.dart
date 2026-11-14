@Tags(['tls-docker'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/certificate_info.dart';
import 'package:vikunja_mobile/core/network/certificate_probe.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/realtime/realtime_providers.dart';

import '../../helpers/auth_fakes.dart';

// The opt-in `tls` compose profile (test_servers/tls/README.md): start it,
// seed it with tool/seed_e2e_user.sh and tool/tls_e2e.py, then
// VIKUNJA_APP_TLS_DOCKER=1 flutter test --tags tls-docker
// Everything goes through the app's own NetworkProfileAdapter (dart:io
// stands in for the platform adapter) and ProfileRealtimeConnector. No
// secret, share hash or token is ever printed.
final String? _dockerSkip =
    Platform.environment['VIKUNJA_APP_TLS_DOCKER'] != '1'
    ? 'Set VIKUNJA_APP_TLS_DOCKER=1 and start the tls compose profile'
    : null;

const _generated = '../test_servers/tls/generated';

Uint8List _material(String name) => File('$_generated/$name').readAsBytesSync();

String _materialText(String name) =>
    File('$_generated/$name').readAsStringSync();

String _manifestSha256(String name) {
  final manifest =
      jsonDecode(_materialText('manifest.json')) as Map<String, Object?>;
  final certificates = manifest['certificates']! as Map<String, Object?>;
  return (certificates[name]! as Map<String, Object?>)['sha256']! as String;
}

Map<String, String> _env(String path) => {
  for (final line in File(path).readAsLinesSync())
    if (line.indexOf('=') case final at when at > 0 && !line.startsWith('#'))
      line.substring(0, at): line.substring(at + 1),
};

OriginKey _origin(int port) => OriginKey.fromString('https://localhost:$port');

/// The test CA as a user-installed CA, which the platform adapter (Cronet)
/// trusts on a device.
HttpClientAdapter _platformWithUserCa() => IOHttpClientAdapter(
  createHttpClient: () => HttpClient(
    context: SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(_material('ca.pem')),
  ),
);

/// The hash of the share tool/tls_e2e.py seeded, read over the host-only
/// plain port with the dummy E2E user.
Future<String> _seededShareHash() async {
  final user = _env('../test_servers/seed/e2e-user.env');
  final seeding = Dio(BaseOptions(baseUrl: 'http://localhost:34531/api/v1'));
  try {
    final login = await seeding.post<Map<String, Object?>>(
      '/login',
      data: {
        'username': user['E2E_USERNAME'],
        'password': user['E2E_PASSWORD'],
      },
    );
    final auth = Options(
      headers: {'Authorization': 'Bearer ${login.data!['token']}'},
    );
    final projects = await seeding.get<List<Object?>>(
      '/projects',
      options: auth,
    );
    final project = projects.data!.cast<Map<String, Object?>>().firstWhere(
      (project) => project['title'] == 'TLS-Test',
    );
    final shares = await seeding.get<List<Object?>>(
      '/projects/${project['id']}/shares',
      options: auth,
    );
    return shares.data!.cast<Map<String, Object?>>().firstWhere(
          (share) => share['name'] == 'tls-e2e',
        )['hash']!
        as String;
  } finally {
    seeding.close(force: true);
  }
}

void main() {
  late NetworkProfiles profiles;
  late Future<String> shareHash;

  setUpAll(() {
    if (_dockerSkip == null) shareHash = _seededShareHash();
  });

  setUp(() {
    profiles = NetworkProfiles(
      preferences: MemoryPreferencesStore(),
      secureStore: MemorySecureStore(),
    );
  });

  Dio dio({HttpClientAdapter? platform}) {
    final dio = createDio(
      userAgent: 'Rurana/tls-docker',
      httpClientAdapter: platform ?? IOHttpClientAdapter(),
      profiles: profiles,
      logRequests: false,
    );
    addTearDown(() => dio.close(force: true));
    return dio;
  }

  Future<ServerConnection> connect(
    int port, {
    HttpClientAdapter? platform,
    String scheme = 'https',
  }) =>
      DioServerConnector(dio(platform: platform))
          .connect('$scheme://localhost:$port');

  Matcher failsWith(Matcher failure) => throwsA(failure);

  /// A link-share guest: the auth POST and a project read, both through
  /// the profile.
  Future<void> expectGuestWorks(
    ServerConnection connection, {
    HttpClientAdapter? platform,
  }) async {
    final client = dio(platform: platform);
    final auth = await LinkShareAuthClient(
      client,
      connection,
    ).authenticate(await shareHash);
    final api = connection.apiBaseUri(ApiVersion.v1);
    final project = await client.getUri<Map<String, Object?>>(
      api.replace(path: '${api.path}/projects/${auth.projectId}'),
      options: Options(headers: {'Authorization': 'Bearer ${auth.token.jwt}'}),
    );
    expect(project.data!['title'], 'TLS-Test');
  }

  Future<void> expectRealtimeOpens(ServerConnection connection) async {
    final socket = await ProfileRealtimeConnector(
      profiles: profiles,
      userAgent: 'Rurana/tls-docker',
    ).connect(realtimeUri(connection));
    await socket.close();
  }

  group('34528, self-signed leaf', skip: _dockerSkip, () {
    test('without a profile the certificate is rejected, and the probe '
        'shows the generated certificate', () async {
      await expectLater(
        connect(34528),
        failsWith(
          isA<TlsFailure>().having(
            (f) => f.certificateRejected,
            'certificateRejected',
            isTrue,
          ),
        ),
      );
      final probed = await CertificateProbe(profiles: profiles)
          .fetch(_origin(34528));
      expect(
        probed,
        isA<ProbedCertificate>().having(
          (p) => p.certificate.sha256,
          'sha256',
          _manifestSha256('selfsigned.pem'),
        ),
      );
    });

    test('the trusted probe connects, signs in a guest and opens the '
        'realtime socket', () async {
      final probed = await CertificateProbe(
        profiles: profiles,
      ).fetch(_origin(34528)) as ProbedCertificate;
      await profiles.trustCertificate(_origin(34528), probed.certificate);

      final connection = await connect(34528);
      expect(
        connection.rootUri.toString(),
        startsWith('https://localhost:34528'),
      );
      await expectGuestWorks(connection);
      await expectRealtimeOpens(connection);
    });

    test('another pinned certificate fails in the handshake and records '
        'the one the server showed', () async {
      await profiles.trustCertificate(
        _origin(34528),
        CertificateInfo(
          sha256: 'AB' * 32,
          subject: '/CN=Rurana test renewed (dummy)',
          issuer: '/CN=Rurana test renewed (dummy)',
          notBefore: DateTime.utc(2026),
          notAfter: DateTime.utc(2027),
        ),
      );
      await expectLater(
        connect(34528),
        failsWith(
          isA<TlsFailure>().having(
            (f) => f.certificateRejected,
            'certificateRejected',
            isTrue,
          ),
        ),
      );
      String? recorded;
      for (var i = 0; i < 40 && recorded == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        recorded = (await profiles.metadataFor(_origin(34528)))
            ?.lastPinMismatch
            ?.sha256;
      }
      expect(recorded, _manifestSha256('selfsigned.pem'));
      await expectLater(
        ProfileRealtimeConnector(
          profiles: profiles,
          userAgent: 'Rurana/tls-docker',
        ).connect(Uri.parse('wss://localhost:34528/api/v2/ws')),
        throwsA(isA<TlsException>()),
      );
    });
  });

  group('34529, client certificate required', skip: _dockerSkip, () {
    final password = _dockerSkip == null
        ? _materialText('client-p12-password.txt')
        : '';

    Future<void> trustTestCa() => profiles.trustCaCertificate(
      _origin(34529),
      fileName: 'ca.pem',
      pem: _materialText('ca.pem'),
    );

    Future<void> useClientCertificate(String file) =>
        profiles.setClientCertificate(
          _origin(34529),
          fileName: file,
          bytes: _material(file),
          password: password,
        );

    Matcher clientCertificateRefused() => isA<TlsFailure>().having(
      (f) => f.clientCertificateRefused,
      'clientCertificateRefused',
      isTrue,
    );

    test('without a profile the test CA is unknown', () async {
      await expectLater(
        connect(34529),
        failsWith(
          isA<TlsFailure>().having(
            (f) => f.certificateRejected,
            'certificateRejected',
            isTrue,
          ),
        ),
      );
    });

    test('the CA file checks out even though the server then refuses the '
        'missing client certificate', () async {
      expect(
        await CertificateProbe(profiles: profiles)
            .verifyWithCa(_origin(34529), _materialText('ca.pem')),
        isA<CaTrusted>(),
      );
      expect(
        await CertificateProbe(profiles: profiles)
            .verifyWithCa(_origin(34529), _materialText('client-ca.pem')),
        isA<CaNotTrusted>(),
      );
    });

    test('CA trust without a client certificate is a refused client '
        'certificate, and the connector stops there', () async {
      await trustTestCa();
      await expectLater(connect(34529), failsWith(clientCertificateRefused()));
      await expectLater(
        ProfileRealtimeConnector(
          profiles: profiles,
          userAgent: 'Rurana/tls-docker',
        ).connect(Uri.parse('wss://localhost:34529/api/v2/ws')),
        throwsA(isA<ClientCertificateRefusedException>()),
      );
    });

    test('a client certificate from another CA is refused', () async {
      await trustTestCa();
      await useClientCertificate('wrong-client.p12');
      await expectLater(connect(34529), failsWith(clientCertificateRefused()));
    });

    test('CA trust and the client certificate connect, sign in a guest and '
        'open the realtime socket', () async {
      await trustTestCa();
      await useClientCertificate('client.p12');
      final connection = await connect(34529);
      await expectGuestWorks(connection);
      await expectRealtimeOpens(connection);
    });

    test('the legacy PKCS#12 and a pin instead of the CA work too', () async {
      await profiles.trustCertificate(
        _origin(34529),
        CertificateInfo(
          sha256: _manifestSha256('server.pem'),
          subject: 'server',
          issuer: 'ca',
          notBefore: DateTime.utc(2026),
          notAfter: DateTime.utc(2027),
        ),
      );
      await useClientCertificate('client-legacy.p12');
      final connection = await connect(34529);
      await expectRealtimeOpens(connection);
    });
  });

  group('34530, access-header gate', skip: _dockerSkip, () {
    final access = _dockerSkip == null
        ? _env('$_generated/access.env')
        : const <String, String>{};
    Map<String, String> headers({String? secret}) => {
      'CF-Access-Client-Id': access['VIKUNJA_APP_TEST_ACCESS_ID']!,
      'CF-Access-Client-Secret':
          secret ?? access['VIKUNJA_APP_TEST_ACCESS_SECRET']!,
    };

    test('without headers the server is behind a login proxy', () async {
      await expectLater(
        connect(34530, platform: _platformWithUserCa()),
        failsWith(isA<BehindLoginProxy>()),
      );
    });

    test('header-only on the platform adapter connects and signs in a '
        'guest', () async {
      await profiles.setHeaders(_origin(34530), headers());
      final connection = await connect(34530, platform: _platformWithUserCa());
      await expectGuestWorks(connection, platform: _platformWithUserCa());
      // dart:io's default context knows no user CA: realtime falls back to
      // polling until the CA is trusted in the app.
      await expectLater(
        ProfileRealtimeConnector(
          profiles: profiles,
          userAgent: 'Rurana/tls-docker',
        ).connect(realtimeUri(connection)),
        throwsA(isA<TlsException>()),
      );
    });

    test('a wrong secret is behind the login proxy again', () async {
      await profiles.setHeaders(_origin(34530), headers(secret: '0' * 64));
      await expectLater(
        connect(34530, platform: _platformWithUserCa()),
        failsWith(isA<BehindLoginProxy>()),
      );
    });

    test('headers with the CA trusted in the app connect and open the '
        'realtime socket', () async {
      await profiles.setHeaders(_origin(34530), headers());
      await profiles.trustCaCertificate(
        _origin(34530),
        fileName: 'ca.pem',
        pem: _materialText('ca.pem'),
      );
      final connection = await connect(34530);
      await expectGuestWorks(connection);
      await expectRealtimeOpens(connection);
    });
  });

  group('34531, plain http', skip: _dockerSkip, () {
    test('only the info probe goes out before the consent', () async {
      final origin = OriginKey.fromString('http://localhost:34531');
      final connection = await connect(34531, scheme: 'http');
      expect(connection.isInsecure, isTrue);
      await expectLater(
        LinkShareAuthClient(dio(), connection).authenticate(await shareHash),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.problem,
            'problem',
            NetworkProblem.cleartextBlocked,
          ),
        ),
      );
      await expectLater(
        ProfileRealtimeConnector(
          profiles: profiles,
          userAgent: 'Rurana/tls-docker',
        ).connect(realtimeUri(connection)),
        throwsA(isA<CleartextBlockedException>()),
      );

      await profiles.consentToCleartext(origin);
      await expectGuestWorks(connection);
      await expectRealtimeOpens(connection);
    });
  });
}
