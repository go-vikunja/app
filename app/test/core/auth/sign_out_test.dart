import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  late DateTime now;
  late AuthFakes fakes;
  late SessionManagers sessions;
  late SignOut signOut;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    fakes = AuthFakes();
    sessions = SessionManagers(
      tokenStore: fakes.tokenStore,
      clockOffsets: fakes.clockOffsets,
      tokenGateway: fakes.tokenGateway,
      connectionFor: (id) async => (await fakes.registry.find(id))?.connection,
      markNeedsReauth: fakes.registry.markNeedsReauth,
      clock: () => now,
      sleep: (_) async {},
    );
    signOut = SignOut(
      registry: fakes.registry,
      tokenStore: fakes.tokenStore,
      clockOffsets: fakes.clockOffsets,
      sessions: sessions,
      accountGateway: fakes.accountGateway,
      logoutTimeout: const Duration(milliseconds: 50),
    );
  });

  test('logs out on the server and forgets the account', () async {
    final tokens = issueTokens(issuedAt: now);
    final alice = await fakes.seedAccount(fullServer270(), tokens: tokens);
    final bob = await fakes.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );

    await signOut(alice.id);

    expect(fakes.accountGateway.logoutTokens, [tokens.accessToken]);
    expect(await fakes.tokenStore.read(alice.id), isNull);
    expect(await fakes.tokenStore.read(bob.id), isNotNull);
    final registry = await fakes.registry.load();
    expect(registry.accounts.map((entry) => entry.id), [bob.id]);
    expect(registry.activeAccountId, bob.id);
  });

  test('refreshes first when the access token is about to expire', () async {
    final old = issueTokens(
      issuedAt: now.subtract(const Duration(minutes: 10)),
    );
    final alice = await fakes.seedAccount(fullServer270(), tokens: old);
    final fresh = issueTokens(issuedAt: now);
    fakes.tokenGateway.onRefresh = (_) async => fresh;

    await signOut(alice.id);

    expect(fakes.tokenGateway.refreshedTokens, [old.refreshToken]);
    expect(fakes.accountGateway.logoutTokens, [fresh.accessToken]);
    expect(fakes.secureStore.values, isEmpty);
  });

  test('signs out locally when the server cannot be reached', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    fakes.accountGateway.onLogout = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await signOut(alice.id);

    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test('does not wait forever for the server', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    fakes.accountGateway.onLogout = (_) => Completer<void>().future;

    await signOut(alice.id);

    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test('skips the server for a session that already ended', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
      needsReauth: true,
    );

    await signOut(alice.id);

    expect(fakes.accountGateway.logoutTokens, isEmpty);
    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test('waits for a refresh in flight, then wipes its result too', () async {
    final old = issueTokens(
      issuedAt: now.subtract(const Duration(minutes: 10)),
    );
    final alice = await fakes.seedAccount(fullServer270(), tokens: old);
    final response = Completer<TokenSet>();
    fakes.tokenGateway.onRefresh = (_) => response.future;
    final request = sessions.forAccount(alice.id).validAccessToken();
    await pumpEventQueue();

    final signingOut = signOut(alice.id);
    await pumpEventQueue();
    final fresh = issueTokens(issuedAt: now);
    response.complete(fresh);
    await signingOut;

    expect(await request, fresh.accessToken);
    expect(fakes.tokenGateway.refreshedTokens, [old.refreshToken]);
    expect(fakes.accountGateway.logoutTokens, [fresh.accessToken]);
    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
  });

  test('does not wait for a refresh that never finishes, and writes nothing '
      'when it finishes later', () async {
    final old = issueTokens(
      issuedAt: now.subtract(const Duration(minutes: 10)),
    );
    final alice = await fakes.seedAccount(fullServer270(), tokens: old);
    final response = Completer<TokenSet>();
    fakes.tokenGateway.onRefresh = (_) => response.future;
    fakes.secureStore.operations.clear();

    await signOut(alice.id);

    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);

    response.complete(issueTokens(issuedAt: now));
    await pumpEventQueue();
    expect(fakes.secureStore.values, isEmpty);
    expect(fakes.secureStore.operations, isNot(contains(startsWith('write'))));
  });

  test('a request after the account was retired cannot write its tokens '
      'back', () async {
    final tokens = issueTokens(issuedAt: now);
    final alice = await fakes.seedAccount(fullServer270(), tokens: tokens);
    fakes.accountGateway.onLogout = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    fakes.tokenGateway.onRefresh = (_) async =>
        issueTokens(issuedAt: now, refreshToken: 'resurrected');
    final deleting = Completer<void>();
    final releaseDelete = Completer<void>();
    final deleted = Completer<void>();
    var deletes = 0;
    fakes.secureStore
      ..beforeDelete = (_) async {
        if (!deleting.isCompleted) deleting.complete();
        await releaseDelete.future;
        if (++deletes == 2) scheduleMicrotask(deleted.complete);
      }
      // A write that is not tracked would land after the wipe.
      ..beforeWrite = (_) => deleted.future;

    final signingOut = signOut(alice.id);
    await deleting.future;
    // A list or sync request that got 401 code 11 right now.
    final late = sessions
        .forAccount(alice.id)
        .refreshAfterRejection(tokens.accessToken);
    releaseDelete.complete();
    await signingOut;

    expect(await late, isNull);
    expect(fakes.tokenGateway.refreshedTokens, isEmpty);
    expect(fakes.secureStore.values, isEmpty);
  });

  test('removes the stored server clock offset', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    await fakes.clockOffsets.write(alice.id, const Duration(seconds: 42));

    await signOut(alice.id);

    expect(await fakes.clockOffsets.read(alice.id), isNull);
  });
}
