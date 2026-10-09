import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/accounts_without_tokens.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

final class _LockedSecureStore implements SecureStore {
  @override
  Future<String?> read(String key) async =>
      throw PlatformException(code: '-25308');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}

void main() {
  late AuthFakes auth;
  final now = DateTime.utc(2026, 10, 9, 12);

  setUp(() => auth = AuthFakes());

  Future<bool> needsReauth(String accountId) async =>
      (await AccountRegistry(auth.preferences).find(accountId))!
          .account
          .needsReauth;

  test('marks an account whose tokens are gone and keeps the others', () async {
    final orphan = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    final intact = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    await auth.tokenStore.delete(orphan.id);

    final state = await flagAccountsWithoutTokens(
      auth.registry,
      auth.tokenStore,
    );

    expect(state.find(orphan.id)!.account.needsReauth, isTrue);
    expect(state.find(intact.id)!.account.needsReauth, isFalse);
    expect(state.activeAccountId, orphan.id);
    expect(await needsReauth(orphan.id), isTrue);
    expect(await needsReauth(intact.id), isFalse);
  });

  test('an access token alone does not count as signed in', () async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    auth.secureStore.values.remove(TokenStore.refreshTokenKey(entry.id));

    await flagAccountsWithoutTokens(auth.registry, auth.tokenStore);

    expect(await needsReauth(entry.id), isTrue);
  });

  test('writes nothing when every account has its tokens', () async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    final writes = <AccountRegistryState>[];
    final subscription = auth.registry.changes.listen(writes.add);
    addTearDown(subscription.cancel);

    await flagAccountsWithoutTokens(auth.registry, auth.tokenStore);
    await pumpEventQueue();

    expect(writes, isEmpty);
  });

  test('unreadable secure storage is not taken as missing tokens', () async {
    final entry = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );

    await flagAccountsWithoutTokens(
      auth.registry,
      TokenStore(_LockedSecureStore()),
    );

    expect(await needsReauth(entry.id), isFalse);
  });
}
