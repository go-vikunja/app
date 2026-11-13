import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/bootstrap/previous_app_start.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/previous_app_fakes.dart';
import '../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _oldToken = 'previous-refresh-token';

void main() {
  late AuthFakes auth;
  late FakePreviousAppPlatform platform;
  final connection = fullServer270(root: 'https://vikunja.example.com');
  final server = Uri.parse('https://vikunja.example.com');

  setUp(() {
    auth = AuthFakes();
    platform = FakePreviousAppPlatform();
    final now = DateTime.now().toUtc();
    auth.tokenGateway.onRefresh = (_) async =>
        issueTokens(issuedAt: now, userId: _alice.id);
    auth.accountGateway.onCurrentUser = (_) async => _alice;
  });

  ProviderContainer containerWith({SecureStore? secureStore}) {
    final container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(secureStore ?? auth.secureStore),
        preferencesStoreProvider.overrideWithValue(auth.preferences),
        webAuthenticatorProvider.overrideWithValue(auth.webAuthenticator),
        tokenGatewayProvider.overrideWithValue(auth.tokenGateway),
        accountGatewayProvider.overrideWithValue(auth.accountGateway),
        linkShareGatewayProvider.overrideWithValue(auth.linkShareGateway),
        serverConnectorProvider.overrideWithValue(
          FakeServerConnector.succeeding(connection),
        ),
        previousAppPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the import comes before the registry, whose first read wipes what '
      'it reads', () {
    test('in this order it finds the server and the token, and the wipe '
        'then deletes them', () async {
      auth.secureStore.values.addAll(previousAppValues());
      final container = containerWith();

      final findings = await importPreviousApp(container);
      await container.read(accountsProvider.future);

      expect(findings?.record.server, server);
      expect(findings?.refreshToken, _oldToken);
      expect(auth.secureStore.values, isEmpty);
      expect(auth.secureStore.operations.last, 'deleteAll');
      expect(auth.preferences.values[installMarkerKey], isNotNull);
    });

    test('the other way round it finds nothing', () async {
      auth.secureStore.values.addAll(previousAppValues());
      final container = containerWith();

      await container.read(accountsProvider.future);
      final findings = await importPreviousApp(container);

      expect(findings?.record.server, isNull);
      expect(findings?.refreshToken, isNull);
    });

    test('bootstrap calls them in that order', () {
      final source = File('lib/bootstrap/bootstrap.dart').readAsStringSync();
      final import = source.indexOf('importPreviousApp(');
      final registry = source.indexOf('accountsProvider.future');
      final start = source.indexOf('startPreviousApp(');

      expect(import, isNonNegative);
      expect(registry, greaterThan(import));
      expect(start, greaterThan(registry));
    });
  });

  test('a first start over the previous app keeps its session once, after '
      'the wipe', () async {
    auth.secureStore.values.addAll(previousAppValues());
    final container = containerWith();

    final findings = await importPreviousApp(container);
    await container.read(accountsProvider.future);
    await startPreviousApp(container, findings);

    expect(
      container.read(previousAppProvider).value?.session,
      isA<PreviousAppSessionKeeping>(),
    );
    expect(container.read(previousAppProvider).value?.note, isNotNull);
    await pumpEventQueue();
    expect(auth.tokenGateway.refreshedTokens, [_oldToken]);
    expect(
      container.read(previousAppProvider).value?.session,
      isA<PreviousAppSessionKept>(),
    );
  });

  test('no try while the old entries could not be wiped: the marker is not '
      'set', () async {
    final failingWipe = _FailingWipe(auth.secureStore);
    auth.secureStore.values.addAll(previousAppValues());
    final container = containerWith(secureStore: failingWipe);

    final findings = await importPreviousApp(container);
    await container.read(accountsProvider.future);
    await startPreviousApp(container, findings);
    await pumpEventQueue();

    expect(findings?.refreshToken, _oldToken);
    expect(auth.preferences.values[installMarkerKey], isNull);
    expect(container.read(previousAppProvider).value?.note, isNotNull);
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
  });

  group('no try', () {
    Future<ProviderContainer> afterWipe() async {
      final container = containerWith();
      await container.read(accountsProvider.future);
      return container;
    }

    test('with an account registered', () async {
      await auth.seedAccount(
        connection,
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      auth.preferences.values[installMarkerKey] = '1';
      final container = await afterWipe();

      await startPreviousApp(
        container,
        PreviousAppFindings(
          record: PreviousAppRecord(server: server),
          refreshToken: _oldToken,
        ),
      );
      await pumpEventQueue();

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });

    test('without a token', () async {
      final container = await afterWipe();

      await startPreviousApp(
        container,
        PreviousAppFindings(record: PreviousAppRecord(server: server)),
      );
      await pumpEventQueue();

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(container.read(previousAppProvider).value?.note, isNotNull);
    });

    test('without a server', () async {
      final container = await afterWipe();

      await startPreviousApp(
        container,
        const PreviousAppFindings(
          record: PreviousAppRecord(),
          refreshToken: _oldToken,
        ),
      );
      await pumpEventQueue();

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });

    test('without findings, and without a note', () async {
      final container = await afterWipe();

      await startPreviousApp(container, null);
      await pumpEventQueue();

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(container.read(previousAppProvider).value?.note, isNull);
    });
  });

  test('an import that does not finish in time is given up', () async {
    platform.onTraces = () => Completer<PreviousAppTraces>().future;
    final container = containerWith();

    final findings = await importPreviousApp(
      container,
      timeout: const Duration(milliseconds: 20),
    );

    expect(findings, isNull);
  });
}

/// Like a Keystore that fails while the first start wipes it.
final class _FailingWipe implements SecureStore {
  new(this._inner);

  final MemorySecureStore _inner;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> deleteAll() async => throw Exception('Keystore unavailable');
}
