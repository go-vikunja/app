import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _accountId = 'a1';

// The managers of the background action isolate (D26, architecture §5.8):
// they never call the token endpoint.
void main() {
  late DateTime now;
  late TokenStore tokenStore;
  late List<String> refreshCalls;
  late List<SessionEnded> ended;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    tokenStore = TokenStore(MemorySecureStore());
    refreshCalls = [];
    ended = [];
  });

  SessionManager createManager() => SessionManager(
    accountId: _accountId,
    tokenStore: tokenStore,
    clockOffsets: ServerClockOffsets(MemoryPreferencesStore()),
    refresh: (refreshToken) async {
      refreshCalls.add(refreshToken);
      return issueTokens(issuedAt: now);
    },
    onSessionEnded: (failure) async => ended.add(failure),
    clock: () => now,
    refreshes: false,
  );

  Future<TokenSet> store({required Duration expiresIn}) async {
    final tokens = issueTokens(
      issuedAt: now.add(expiresIn).subtract(const Duration(minutes: 10)),
    );
    await tokenStore.write(_accountId, tokens);
    return tokens;
  }

  test('hands out the stored token while it is valid, even within the '
      'refresh margin', () async {
    final stored = await store(expiresIn: const Duration(seconds: 30));

    expect(await createManager().validAccessToken(), stored.accessToken);
    expect(refreshCalls, isEmpty);
  });

  test('an expired token fails as rejected without a refresh and without '
      'ending the session', () async {
    await store(expiresIn: Duration.zero);

    await expectLater(
      createManager().validAccessToken(),
      throwsA(isA<TokenRejected>()),
    );
    expect(refreshCalls, isEmpty);
    expect(ended, isEmpty);
  });

  test('tokens a sibling isolate stored meanwhile are adopted', () async {
    await store(expiresIn: Duration.zero);
    final manager = createManager();
    await expectLater(
      manager.validAccessToken(),
      throwsA(isA<TokenRejected>()),
    );
    final fresh = issueTokens(issuedAt: now);
    await tokenStore.write(_accountId, fresh);

    expect(await manager.validAccessToken(), fresh.accessToken);
    expect(refreshCalls, isEmpty);
  });

  test('after a rejection only a newer stored token is offered', () async {
    final stored = await store(expiresIn: const Duration(minutes: 5));
    final manager = createManager();
    await manager.validAccessToken();

    expect(await manager.refreshAfterRejection(stored.accessToken), isNull);
    final fresh = issueTokens(issuedAt: now);
    await tokenStore.write(_accountId, fresh);
    expect(
      await manager.refreshAfterRejection(stored.accessToken),
      fresh.accessToken,
    );
    expect(refreshCalls, isEmpty);
  });

  test('the background action overrides give every account non-refreshing '
      'managers', () async {
    final auth = AuthFakes();
    final expired = issueTokens(
      issuedAt: now.subtract(const Duration(minutes: 20)),
    );
    final alice = await auth.seedAccount(fullServer270(), tokens: expired);
    final container = ProviderContainer(
      overrides: [...auth.overrides, ...backgroundActionOverrides],
    );
    addTearDown(container.dispose);
    auth.tokenGateway.onRefresh = (_) async => issueTokens(issuedAt: now);

    await expectLater(
      container
          .read(sessionManagersProvider)
          .forAccount(alice.id)
          .validAccessToken(),
      throwsA(isA<TokenRejected>()),
    );
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
  });

  test('SessionManagers passes the policy on', () async {
    await store(expiresIn: Duration.zero);
    final managers = SessionManagers(
      tokenStore: tokenStore,
      clockOffsets: ServerClockOffsets(MemoryPreferencesStore()),
      tokenGateway: FakeTokenGateway(),
      connectionFor: (_) async => null,
      markNeedsReauth: (_) async {},
      clock: () => now,
      refreshes: false,
    );

    await expectLater(
      managers.forAccount(_accountId).validAccessToken(),
      throwsA(isA<TokenRejected>()),
    );
  });
}
