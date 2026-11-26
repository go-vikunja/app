import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

final class _LockedKeychain implements SecureStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(
    String key,
    String value, {
    bool recoverLostKey = false,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async => throw PlatformException(code: '-25308');

  @override
  Future<void> flush() async {}
}

void main() {
  late AuthFakes auth;
  final now = DateTime.utc(2026, 10, 9, 12);

  setUp(() => auth = AuthFakes());

  Future<void> purge([SecureStore? secureStore]) =>
      purgeSecretsLeftByPreviousInstall(
        preferences: auth.preferences,
        secureStore: secureStore ?? auth.secureStore,
      );

  test('a fresh install wipes what an earlier install left in the Keychain '
      'and remembers that it did', () async {
    auth.secureStore.values['account.old.refresh_token'] = 'left behind';

    await purge();

    expect(auth.secureStore.values, isEmpty);
    expect(auth.preferences.values, contains(installMarkerKey));

    auth.secureStore.values['account.new.refresh_token'] = 'signed in';
    await purge();
    expect(auth.secureStore.values, hasLength(1));
  });

  test('with the marker present nothing is wiped', () async {
    auth.preferences.values[installMarkerKey] = '1';
    auth.secureStore.values['account.a.refresh_token'] = 'live';

    await purge();

    expect(auth.secureStore.operations, isEmpty);
  });

  test('a registry from a build before the marker is an update, not a fresh '
      'install', () async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    auth.secureStore.operations.clear();

    await purge();

    expect(auth.secureStore.operations, isEmpty);
    expect(auth.secureStore.values, isNotEmpty);
    expect(auth.preferences.values, contains(installMarkerKey));
  });

  test('an unreadable registry is not taken for a fresh install', () async {
    auth.preferences.values[AccountRegistry.storageKey] = '{not json';

    await purge();

    expect(auth.secureStore.operations, isEmpty);
  });

  test('a locked Keychain leaves the marker unset, so the next start tries '
      'again', () async {
    await purge(_LockedKeychain());

    expect(auth.preferences.values, isNot(contains(installMarkerKey)));
  });

  test('a wipe that never answers does not hold the start, and leaves the '
      'marker unset', () async {
    await purgeSecretsLeftByPreviousInstall(
      preferences: auth.preferences,
      secureStore: _StuckKeystore(),
      wipeTimeout: const Duration(milliseconds: 20),
    ).timeout(const Duration(seconds: 5));

    expect(auth.preferences.values, isNot(contains(installMarkerKey)));
  });

  test('a retried start joins the check still running instead of wiping '
      'after the tokens it stored', () async {
    final registryRead = Completer<void>();
    auth.preferences.beforeRead = (key) async {
      if (key == AccountRegistry.storageKey) await registryRead.future;
    };
    final first = purge();
    await pumpEventQueue();
    final retried = purge();
    registryRead.complete();
    await Future.wait([first, retried]);
    expect(
      auth.secureStore.operations.where((op) => op.startsWith('deleteAll')),
      hasLength(1),
    );

    auth.secureStore.values['account.new.refresh_token'] = 'signed in';
    await purge();
    expect(auth.secureStore.values, hasLength(1));
  });
}

/// Like a Keystore whose plugin thread is stuck behind a call that never
/// answers.
final class _StuckKeystore implements SecureStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(
    String key,
    String value, {
    bool recoverLostKey = false,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() => Completer<void>().future;

  @override
  Future<void> flush() async {}
}
