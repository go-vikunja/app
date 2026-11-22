import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/accounts_without_tokens.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

final class _LockedSecureStore implements SecureStore {
  @override
  Future<String?> read(String key) async =>
      throw PlatformException(code: '-25308');

  @override
  Future<void> write(
    String key,
    String value, {
    bool recoverLostKey = false,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<void> flush() async {}
}

/// Refuses reads while [locked], like a Keystore failure that passes.
final class _FlakySecureStore implements SecureStore {
  new(this._inner);

  final MemorySecureStore _inner;
  bool locked = false;

  @override
  Future<String?> read(String key) async {
    if (locked) throw PlatformException(code: 'keystore');
    return await _inner.read(key);
  }

  @override
  Future<void> write(String key, String value, {bool recoverLostKey = false}) =>
      _inner.write(key, value, recoverLostKey: recoverLostKey);

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<void> deleteAll() => _inner.deleteAll();

  @override
  Future<void> flush() => _inner.flush();
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
      auth.linkShareStore,
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

    await flagAccountsWithoutTokens(
      auth.registry,
      auth.tokenStore,
      auth.linkShareStore,
    );

    expect(await needsReauth(entry.id), isTrue);
  });

  test('writes nothing when every account has its tokens', () async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    final writes = <AccountRegistryState>[];
    final subscription = auth.registry.changes.listen(writes.add);
    addTearDown(subscription.cancel);

    await flagAccountsWithoutTokens(
      auth.registry,
      auth.tokenStore,
      auth.linkShareStore,
    );
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
      LinkShareStore(_LockedSecureStore()),
    );

    expect(await needsReauth(entry.id), isFalse);
  });

  group('guests', () {
    test(
      'a guest counts while its hash is stored, a token alone does not',
      () async {
        final withToken = await auth.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now),
        );
        final hashOnly = await auth.seedGuest(
          fullServer270(),
          token: null,
          shareId: 85,
        );
        final lost = await auth.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now, shareId: 86),
          shareId: 86,
        );
        auth.secureStore.values.remove(LinkShareStore.hashKey(lost.id));

        await flagAccountsWithoutTokens(
          auth.registry,
          auth.tokenStore,
          auth.linkShareStore,
        );

        expect(await needsReauth(withToken.id), isFalse);
        expect(await needsReauth(hashOnly.id), isFalse);
        expect(await needsReauth(lost.id), isTrue);
      },
    );

    test("a guest is never checked against a user's tokens, nor a user "
        "against a guest's secrets", () async {
      final guest = await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: now),
      );
      final user = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
        activate: false,
      );
      await auth.secureStore.write(LinkShareStore.hashKey(user.id), 'x');
      await auth.tokenStore.delete(user.id);

      await flagAccountsWithoutTokens(
        auth.registry,
        auth.tokenStore,
        auth.linkShareStore,
      );

      expect(await needsReauth(guest.id), isFalse);
      expect(await needsReauth(user.id), isTrue);
    });
  });

  group('with diagnostics (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;

    setUp(() => diagnostics = SessionDiagnostics(auth.preferences));

    Future<void> check(
      TokenStore tokens,
      DateTime at, {
      LinkShareStore? links,
    }) => flagAccountsWithoutTokens(
      auth.registry,
      tokens,
      links ?? auth.linkShareStore,
      diagnostics: diagnostics,
      clock: () => at,
    );

    test('missing tokens are recorded', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      await auth.tokenStore.delete(entry.id);

      await check(auth.tokenStore, now);

      final diagnosis = (await diagnostics.lastEnd(entry.id))!;
      expect(diagnosis.cause, SessionEndCause.missingTokens);
      expect(diagnosis.part, AppPart.app);
      expect(diagnosis.at, now);
    });

    test('storage that stays unreadable for a day asks for a new '
        'sign-in', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final locked = TokenStore(_LockedSecureStore());

      await check(locked, now);
      await check(locked, now.add(const Duration(hours: 23)));
      expect(await needsReauth(entry.id), isFalse);
      expect(await diagnostics.lastEnd(entry.id), isNull);

      await check(
        locked,
        now.add(unreadableTokensGrace + const Duration(minutes: 1)),
      );
      expect(await needsReauth(entry.id), isTrue);
      expect(
        (await diagnostics.lastEnd(entry.id))!.cause,
        SessionEndCause.storageUnreadable,
      );
    });

    test('a read that works again at a start begins the day anew', () async {
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final locked = TokenStore(_LockedSecureStore());

      await check(locked, now);
      await check(auth.tokenStore, now.add(const Duration(hours: 1)));
      await check(locked, now.add(const Duration(hours: 30)));

      expect(await needsReauth(entry.id), isFalse);
    });

    // A fresh engine's first Keystore read is where a passing failure
    // shows, so the read at every start may fail while the session
    // manager reads the tokens fine all day.
    test('a good read by a session manager begins the day anew', () async {
      final store = _FlakySecureStore(auth.secureStore);
      final tokens = TokenStore(store);
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final sessions = SessionManagers(
        tokenStore: tokens,
        clockOffsets: ServerClockOffsets(auth.preferences),
        tokenGateway: auth.tokenGateway,
        connectionFor: (_) async => entry.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        diagnostics: diagnostics,
        clock: () => now,
      );

      store.locked = true;
      await check(tokens, now);
      store.locked = false;
      await sessions.forAccount(entry.id).validAccessToken();
      store.locked = true;
      await check(tokens, now.add(const Duration(hours: 25)));

      expect(await needsReauth(entry.id), isFalse);
      expect(await diagnostics.lastEnd(entry.id), isNull);
    });

    test('a session manager that read fine before a start failed notes its '
        'next good read again', () async {
      final store = _FlakySecureStore(auth.secureStore);
      final tokens = TokenStore(store);
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      auth.tokenGateway.onRefresh = (_) async => issueTokens(issuedAt: now);
      final manager = SessionManagers(
        tokenStore: tokens,
        clockOffsets: ServerClockOffsets(auth.preferences),
        tokenGateway: auth.tokenGateway,
        connectionFor: (_) async => entry.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        diagnostics: diagnostics,
        clock: () => now,
      ).forAccount(entry.id);

      await manager.validAccessToken();
      store.locked = true;
      await check(tokens, now);
      store.locked = false;
      await manager.refreshNow();
      store.locked = true;
      await check(tokens, now.add(const Duration(hours: 25)));

      expect(await needsReauth(entry.id), isFalse);
    });

    test("a good read of a guest's link begins the day anew", () async {
      final store = _FlakySecureStore(auth.secureStore);
      final links = LinkShareStore(store);
      final guest = await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: now),
      );
      final sessions = LinkShareSessions(
        store: links,
        gateway: auth.linkShareGateway,
        connectionFor: (_) async => guest.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        diagnostics: diagnostics,
        clock: () => now,
      );

      store.locked = true;
      await check(auth.tokenStore, now, links: links);
      store.locked = false;
      await sessions.forAccount(guest.id).validAccessToken();
      store.locked = true;
      await check(
        auth.tokenStore,
        now.add(const Duration(hours: 25)),
        links: links,
      );

      expect(await needsReauth(guest.id), isFalse);
      expect(await diagnostics.lastEnd(guest.id), isNull);
    });
  });
}
