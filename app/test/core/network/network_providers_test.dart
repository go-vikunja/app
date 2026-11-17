import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_profile.dart';
import 'package:vikunja_mobile/core/network/network_profile_adapter.dart';
import 'package:vikunja_mobile/core/network/network_profile_providers.dart';
import 'package:vikunja_mobile/core/network/network_profile_secrets.dart';
import 'package:vikunja_mobile/core/network/network_profiles.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/tls_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryPreferencesStore preferences;

  ProviderContainer container({MemorySecureStore? secureStore}) {
    final container = ProviderContainer(
      overrides: [
        clientIdentityProvider.overrideWithValue(
          const ClientIdentity(
            appVersion: '1.0.0',
            buildNumber: '1',
            platform: 'android',
            osVersion: '15',
          ),
        ),
        preferencesStoreProvider.overrideWithValue(preferences),
        secureStoreProvider.overrideWithValue(
          secureStore ?? MemorySecureStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => preferences = MemoryPreferencesStore());

  final origin = OriginKey.fromString('https://vikunja.example.com:443');

  test('both Dios go through the profile adapter over one shared table, '
      'and edits never rebuild them', () async {
    final providers = container();
    final dio = providers.read(dioProvider);
    final authDio = providers.read(authDioProvider);
    expect(dio.httpClientAdapter, isA<NetworkProfileAdapter>());
    expect(authDio.httpClientAdapter, isA<NetworkProfileAdapter>());
    expect(
      identical(dio.httpClientAdapter, authDio.httpClientAdapter),
      isFalse,
    );
    final profiles = providers.read(networkProfilesProvider);

    await profiles.setHeaders(origin, {'X-Token': 'dummy'});
    await profiles.trustCertificate(
      origin,
      tlsFixtureCertificate('selfsigned.pem'),
    );
    await profiles.forget(origin);

    expect(identical(providers.read(dioProvider), dio), isTrue);
    expect(identical(providers.read(authDioProvider), authDio), isTrue);
    expect(
      identical(providers.read(networkProfilesProvider), profiles),
      isTrue,
    );
  });

  test("the reset reads the registry for the accounts' origins", () async {
    final auth = AuthFakes();
    preferences = auth.preferences;
    await auth.seedAccount(
      insecureServer(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    final account = OriginKey.fromString('http://192.168.1.20:3456');
    final secureStore = MemorySecureStore();
    final providers = container(secureStore: secureStore);
    final profiles = providers.read(networkProfilesProvider);
    await profiles.consentToCleartext(account);
    await profiles.setHeaders(account, {'X-Token': 'dummy'});
    final secret = NetworkProfileSecrets.keyFor(NetworkProfile.idFor(account));
    expect(secureStore.values, contains(secret));
    preferences.values[NetworkProfiles.storageKey] = '{nope';

    await profiles.resetAll();

    expect(secureStore.values, isNot(contains(secret)));
  });

  test('the screen state follows edits made in this isolate', () async {
    final providers = container();
    final states = <ConnectionProfileStatus?>[];
    final revisions = <int?>[];
    providers
      ..listen(
        connectionProfileProvider(origin),
        (_, next) => states.add(next.value?.status),
        fireImmediately: true,
      )
      ..listen(
        connectionProfileRevisionProvider(origin),
        (_, next) => revisions.add(next?.revision),
        fireImmediately: true,
      );
    await pumpEventQueue();
    final profiles = providers.read(networkProfilesProvider);

    await profiles.trustCertificate(
      origin,
      tlsFixtureCertificate('selfsigned.pem'),
    );
    await pumpEventQueue();
    await profiles.recordPinMismatch(
      origin,
      tlsFixtureCertificate('server.pem'),
    );
    await pumpEventQueue();

    expect(states.nonNulls, [
      ConnectionProfileStatus.ok,
      ConnectionProfileStatus.ok,
      ConnectionProfileStatus.pinMismatch,
    ]);
    expect(revisions, [null, 0, 1]);
  });
}
