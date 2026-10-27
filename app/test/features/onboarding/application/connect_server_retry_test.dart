import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/origin_key.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/connection_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/server_connections.dart';

/// Reads nothing back and refuses every write.
final class _UnwritablePreferences implements PreferencesStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('storage full');

  @override
  Future<void> remove(String key) async => throw StateError('storage full');
}

void main() {
  final root = Uri.parse('https://vikunja.example.com');
  late FakeServerConnector connector;
  late AuthFakes auth;
  late ProviderContainer container;

  ProviderContainer containerWith(List<Override> overrides) =>
      ProviderContainer.test(
        overrides: [
          serverConnectorProvider.overrideWithValue(connector),
          ...overrides,
        ],
      );

  setUp(() {
    connector = FakeServerConnector();
    auth = AuthFakes();
    container = containerWith(auth.overrides);
  });

  ConnectServerController controller() =>
      container.read(connectServerControllerProvider.notifier);
  ConnectServerState state() => container.read(connectServerControllerProvider);

  /// Fails with [failure] on the first attempt only.
  void failOnce(Exception failure, ServerConnection connection) {
    var failed = false;
    connector.handler = (_) async {
      if (failed) return connection;
      failed = true;
      throw failure;
    };
  }

  test('opens the address again after a change of its settings', () async {
    failOnce(TlsFailure(root, certificateRejected: true), oauthServer230());
    await controller().connect('vikunja.example.com');
    expect(state(), isA<ConnectServerFailed>());

    await controller().retryAfterConnectionChange();

    expect(connector.inputs, ['vikunja.example.com', 'vikunja.example.com']);
    expect(state(), isA<ConnectServerConnected>());
    expect(container.read(currentServerProvider), isNotNull);
  });

  test('keeps nothing to retry after a failure no setting fixes', () async {
    failOnce(ServerUnreachable(root), oauthServer230());
    await controller().connect('vikunja.example.com');

    await controller().retryAfterConnectionChange();

    expect(connector.inputs, hasLength(1));
    expect(state(), isA<ConnectServerFailed>());
  });

  test('reset and a new address forget what was opened', () async {
    connector.handler = (_) async => throw BehindLoginProxy(root);
    await controller().connect('vikunja.example.com');
    controller().reset();
    await controller().retryAfterConnectionChange();
    expect(connector.inputs, hasLength(1));

    await controller().connect('vikunja.example.com');
    await controller().connect('other.example.com');
    await controller().retryAfterConnectionChange();
    expect(connector.inputs, [
      'vikunja.example.com',
      'vikunja.example.com',
      'other.example.com',
      'other.example.com',
    ]);
  });

  test('accepting http records the consent for the origin first', () async {
    final server = insecureServer();
    connector.handler = (_) async => server;
    await controller().connect('192.168.1.20:3456');

    await controller().acceptInsecureConnection();

    expect(state(), isA<ConnectServerConnected>());
    final profile = await profilesOver(auth)
        .metadataFor(OriginKey.of(server.rootUri));
    expect(profile?.hasCleartextConsent, isTrue);
  });

  test('a consent that cannot be stored fails without going on', () async {
    container = containerWith([
      preferencesStoreProvider.overrideWithValue(_UnwritablePreferences()),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
    ]);
    connector.handler = (_) async => insecureServer();
    await controller().connect('192.168.1.20:3456');

    await controller().acceptInsecureConnection();

    expect(
      state(),
      isA<ConnectServerFailed>()
          .having((failed) => failed.failure, 'failure', isNull)
          .having(
            (failed) => failed.input,
            'input',
            'http://192.168.1.20:3456',
          ),
    );
    expect(container.read(currentServerProvider), isNull);
  });
}
