import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _accountId = 'a1';
const _raceLost = RefreshRaceLost(message: 'already used');

void main() {
  late DateTime now;
  late MemorySecureStore secureStore;
  late TokenStore tokenStore;
  late MemoryPreferencesStore preferences;
  late ServerClockOffsets clockOffsets;
  late List<String> refreshCalls;
  late Future<TokenSet> Function(String refreshToken) onRefresh;
  late List<SessionEnded> ended;
  late List<Duration> sleeps;
  late Future<void> Function(int sleepIndex)? duringSleep;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    secureStore = MemorySecureStore();
    tokenStore = TokenStore(secureStore);
    preferences = MemoryPreferencesStore();
    clockOffsets = ServerClockOffsets(preferences);
    refreshCalls = [];
    onRefresh = (_) async => issueTokens(issuedAt: now);
    ended = [];
    sleeps = [];
    duringSleep = null;
  });

  SessionManager createManager() => SessionManager(
    accountId: _accountId,
    tokenStore: tokenStore,
    clockOffsets: clockOffsets,
    refresh: (refreshToken) {
      refreshCalls.add(refreshToken);
      return onRefresh(refreshToken);
    },
    onSessionEnded: (failure) async => ended.add(failure),
    clock: () => now,
    sleep: (duration) async {
      sleeps.add(duration);
      await duringSleep?.call(sleeps.length);
    },
  );

  /// Tokens that expire [expiresIn] from now, as storage holds them.
  Future<TokenSet> store({required Duration expiresIn}) async {
    final tokens = issueTokens(
      issuedAt: now.add(expiresIn).subtract(const Duration(minutes: 10)),
    );
    await tokenStore.write(_accountId, tokens);
    return tokens;
  }

  Future<String?> storedRefreshToken() async =>
      (await tokenStore.read(_accountId))?.refreshToken;

  group('validAccessToken', () {
    test('uses the stored token while it is valid', () async {
      final stored = await store(expiresIn: const Duration(minutes: 5));

      expect(await createManager().validAccessToken(), stored.accessToken);
      expect(refreshCalls, isEmpty);
    });

    test(
      'refreshes within 60 s of expiry and stores the rotated tokens',
      () async {
        final stored = await store(expiresIn: const Duration(seconds: 59));
        final fresh = issueTokens(issuedAt: now);
        onRefresh = (_) async => fresh;

        expect(await createManager().validAccessToken(), fresh.accessToken);
        expect(refreshCalls, [stored.refreshToken]);
        expect(await storedRefreshToken(), fresh.refreshToken);
      },
    );

    test('does not refresh with more than 60 s left', () async {
      await store(expiresIn: const Duration(seconds: 61));

      await createManager().validAccessToken();

      expect(refreshCalls, isEmpty);
    });

    test(
      'hands out the new token only after the refresh token is stored',
      () async {
        await store(expiresIn: Duration.zero);
        final fresh = issueTokens(issuedAt: now);
        onRefresh = (_) async => fresh;
        secureStore.operations.clear();
        final gate = Completer<void>();
        secureStore.beforeWrite = (key) =>
            key.endsWith('refresh_token') ? gate.future : Future.value();

        String? result;
        unawaited(createManager().validAccessToken().then((t) => result = t));
        await pumpEventQueue();
        expect(result, isNull);

        gate.complete();
        await pumpEventQueue();
        expect(result, fresh.accessToken);
        expect(secureStore.operations, [
          'write account.a1.refresh_token',
          'write account.a1.access_token',
        ]);
      },
    );

    test('concurrent callers share one refresh', () async {
      final stored = await store(expiresIn: Duration.zero);
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final results = Future.wait([
        manager.validAccessToken(),
        manager.validAccessToken(),
        manager.refreshAfterRejection(stored.accessToken),
      ]);
      await pumpEventQueue();
      final fresh = issueTokens(issuedAt: now);
      response.complete(fresh);

      expect(await results, everyElement(fresh.accessToken));
      expect(refreshCalls, [stored.refreshToken]);
    });

    test('a later call reuses the refreshed token', () async {
      await store(expiresIn: Duration.zero);
      final manager = createManager();
      final first = await manager.validAccessToken();

      now = now.add(const Duration(minutes: 5));

      expect(await manager.validAccessToken(), first);
      expect(refreshCalls, hasLength(1));
    });

    test('judges expiry in server time, learned from iat', () async {
      await store(expiresIn: Duration.zero);
      // The device clock is five minutes behind the server.
      const skew = Duration(minutes: 5);
      onRefresh = (_) async => issueTokens(issuedAt: now.add(skew));
      final manager = createManager();
      await manager.validAccessToken();

      // 541 s after issue in server time, but only 241 s on the device.
      now = now.add(const Duration(seconds: 541));
      await manager.validAccessToken();

      expect(refreshCalls, hasLength(2));
    });

    group('a new manager uses the stored server clock offset', () {
      const skew = Duration(minutes: 10);

      test('a device clock ahead does not refresh a fresh token', () async {
        final serverNow = now;
        final stored = issueTokens(issuedAt: serverNow);
        await tokenStore.write(_accountId, stored);
        await clockOffsets.write(_accountId, -skew);
        now = now.add(skew);

        expect(await createManager().validAccessToken(), stored.accessToken);
        expect(refreshCalls, isEmpty);
      });

      test('a device clock behind refreshes before the server would reject '
          'the token', () async {
        // Expired 30 s ago in server time, 9.5 min left on the device clock.
        final serverNow = now;
        await tokenStore.write(
          _accountId,
          issueTokens(
            issuedAt: serverNow.subtract(
              const Duration(minutes: 10, seconds: 30),
            ),
          ),
        );
        await clockOffsets.write(_accountId, skew);
        now = now.subtract(skew);
        onRefresh = (_) async => issueTokens(issuedAt: serverNow);

        await createManager().validAccessToken();

        expect(refreshCalls, hasLength(1));
      });

      test('offline, a token valid in server time is still used', () async {
        final serverNow = now;
        final stored = issueTokens(
          issuedAt: serverNow.subtract(const Duration(minutes: 9, seconds: 30)),
        );
        await tokenStore.write(_accountId, stored);
        await clockOffsets.write(_accountId, -skew);
        now = now.add(skew);
        onRefresh = (_) async =>
            throw const NetworkFailure(NetworkProblem.unreachable);

        expect(await createManager().validAccessToken(), stored.accessToken);
        expect(refreshCalls, hasLength(1));
      });

      test(
        'a refresh stores the offset it learned, after the tokens',
        () async {
          await store(expiresIn: Duration.zero);
          onRefresh = (_) async => issueTokens(issuedAt: now.add(skew));
          secureStore.beforeWrite = (_) async {
            expect(preferences.values, isEmpty);
          };

          await createManager().validAccessToken();

          expect(await clockOffsets.read(_accountId), skew);
        },
      );
    });
  });

  group('refreshAfterRejection', () {
    test('refreshes when the current token was rejected', () async {
      final stored = await store(expiresIn: const Duration(minutes: 5));
      final fresh = issueTokens(issuedAt: now);
      onRefresh = (_) async => fresh;

      final token = await createManager().refreshAfterRejection(
        stored.accessToken,
      );

      expect(token, fresh.accessToken);
      expect(refreshCalls, [stored.refreshToken]);
    });

    test('returns the newer token when the rejected one is outdated', () async {
      final stored = await store(expiresIn: const Duration(minutes: 5));

      final token = await createManager().refreshAfterRejection('older');

      expect(token, stored.accessToken);
      expect(refreshCalls, isEmpty);
    });
  });

  group('other isolates', () {
    test(
      'adopts tokens another isolate stored instead of refreshing',
      () async {
        await store(expiresIn: const Duration(minutes: 5));
        final manager = createManager();
        await manager.validAccessToken();

        now = now.add(const Duration(minutes: 4, seconds: 30));
        final sibling = issueTokens(issuedAt: now);
        await tokenStore.write(_accountId, sibling);

        expect(await manager.validAccessToken(), sibling.accessToken);
        expect(refreshCalls, isEmpty);
      },
    );

    test('refreshes with the newer refresh token when the stored access token '
        'is stale too', () async {
      await store(expiresIn: const Duration(minutes: 5));
      final manager = createManager();
      await manager.validAccessToken();

      now = now.add(const Duration(minutes: 5));
      final sibling = issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 9, seconds: 30)),
      );
      await tokenStore.write(_accountId, sibling);

      await manager.validAccessToken();

      expect(refreshCalls, [sibling.refreshToken]);
    });

    for (final (name, failure) in [
      ('16004', _raceLost as VikunjaFailure),
      (
        '16002',
        const SessionEnded(SessionEndReason.invalidRefreshToken, code: 16002),
      ),
    ]) {
      test('after $name, adopts the tokens the winner stores', () async {
        await store(expiresIn: Duration.zero);
        onRefresh = (_) async => throw failure;
        final winner = issueTokens(issuedAt: now);
        duringSleep = (index) async {
          if (index == 2) await tokenStore.write(_accountId, winner);
        };

        expect(await createManager().validAccessToken(), winner.accessToken);
        expect(sleeps, SessionManager.raceRecheckDelays.take(2));
        expect(ended, isEmpty);
      });
    }

    test('a session-end answer for a session a sibling has replaced adopts '
        'the new tokens', () async {
      await store(expiresIn: Duration.zero);
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final pending = manager.validAccessToken();
      await pumpEventQueue();
      final signIn = issueTokens(issuedAt: now, sessionId: 'session-2');
      await tokenStore.write(_accountId, signIn);
      response.completeError(
        const SessionEnded(SessionEndReason.expired, code: 16003),
      );

      expect(await pending, signIn.accessToken);
      expect(ended, isEmpty);
      expect(await manager.validAccessToken(), signIn.accessToken);
    });

    test(
      'a session-end answer with unchanged storage ends the session',
      () async {
        final stored = await store(expiresIn: Duration.zero);
        final response = Completer<TokenSet>();
        onRefresh = (_) => response.future;

        final pending = createManager().validAccessToken();
        await pumpEventQueue();
        response.completeError(
          const SessionEnded(SessionEndReason.expired, code: 16003),
        );

        await expectLater(pending, throwsA(isA<SessionEnded>()));
        expect(ended, hasLength(1));
        expect(await storedRefreshToken(), stored.refreshToken);
      },
    );

    test(
      'losing again inside the recovery keeps looking for the winner',
      () async {
        final first = await store(expiresIn: Duration.zero);
        // What a torn read between the two token writes looks like: the new
        // refresh token next to an old access token.
        final torn = issueTokens(
          issuedAt: now.subtract(const Duration(minutes: 9, seconds: 30)),
        );
        final third = issueTokens(issuedAt: now);
        onRefresh = (refreshToken) async {
          if (refreshToken == first.refreshToken) {
            await tokenStore.write(_accountId, torn);
            throw _raceLost;
          }
          throw const ServerFailure(500);
        };
        duringSleep = (index) async {
          if (sleeps.last == SessionManager.serverErrorRetryDelay) {
            await tokenStore.write(_accountId, third);
          }
        };

        expect(await createManager().validAccessToken(), third.accessToken);
        expect(refreshCalls, [first.refreshToken, torn.refreshToken]);
        expect(ended, isEmpty);
      },
    );

    test('ends the session when no newer tokens show up', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _raceLost;
      final manager = createManager();

      await expectLater(
        manager.validAccessToken(),
        throwsA(
          isA<SessionEnded>()
              .having(
                (f) => f.reason,
                'reason',
                SessionEndReason.invalidRefreshToken,
              )
              .having((f) => f.code, 'code', 16004),
        ),
      );
      expect(sleeps, SessionManager.raceRecheckDelays);
      expect(ended, hasLength(1));

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(refreshCalls, hasLength(1));
    });
  });

  group('failures', () {
    for (final reason in [
      SessionEndReason.expired,
      SessionEndReason.accountDisabled,
      SessionEndReason.accountLocked,
    ]) {
      test(
        '${reason.name} ends the session at once and keeps the tokens',
        () async {
          final stored = await store(expiresIn: Duration.zero);
          final failure = SessionEnded(reason);
          onRefresh = (_) async => throw failure;

          await expectLater(
            createManager().validAccessToken(),
            throwsA(same(failure)),
          );
          expect(ended, [same(failure)]);
          expect(sleeps, isEmpty);
          expect(await storedRefreshToken(), stored.refreshToken);
        },
      );
    }

    test('a network failure keeps a token that has not expired yet', () async {
      final stored = await store(expiresIn: const Duration(seconds: 30));
      onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final manager = createManager();

      expect(await manager.validAccessToken(), stored.accessToken);
      expect(await manager.validAccessToken(), stored.accessToken);
      expect(refreshCalls, hasLength(2));
      expect(await storedRefreshToken(), stored.refreshToken);
      expect(ended, isEmpty);
    });

    test('a network failure with an expired token is thrown', () async {
      final stored = await store(expiresIn: const Duration(seconds: -1));
      onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.timeout);

      await expectLater(
        createManager().validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await storedRefreshToken(), stored.refreshToken);
      expect(ended, isEmpty);
    });

    test('a server error is retried once', () async {
      await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      var calls = 0;
      onRefresh = (_) async =>
          ++calls == 1 ? throw const ServerFailure(502) : fresh;

      expect(await createManager().validAccessToken(), fresh.accessToken);
      expect(sleeps, [SessionManager.serverErrorRetryDelay]);
      expect(refreshCalls, hasLength(2));
    });

    test('a server error after a sibling rotated adopts its tokens instead '
        'of retrying', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw const ServerFailure(500);
      final winner = issueTokens(issuedAt: now);
      duringSleep = (_) => tokenStore.write(_accountId, winner);

      expect(await createManager().validAccessToken(), winner.accessToken);
      expect(refreshCalls, hasLength(1));
      expect(ended, isEmpty);
    });

    test('a second server error is thrown', () async {
      await store(expiresIn: const Duration(seconds: -1));
      onRefresh = (_) async => throw const ServerFailure(503);

      await expectLater(
        createManager().validAccessToken(),
        throwsA(isA<ServerFailure>()),
      );
      expect(refreshCalls, hasLength(2));
      expect(ended, isEmpty);
    });

    test(
      '429 pauses refreshing for Retry-After, at most ten minutes',
      () async {
        await store(expiresIn: const Duration(minutes: -1));
        onRefresh = (_) async =>
            throw const RateLimited(retryAfter: Duration(minutes: 30));
        final manager = createManager();

        await expectLater(
          manager.validAccessToken(),
          throwsA(isA<RateLimited>()),
        );
        now = now.add(const Duration(minutes: 9, seconds: 59));
        await expectLater(
          manager.validAccessToken(),
          throwsA(
            isA<RateLimited>().having(
              (f) => f.retryAfter,
              'retryAfter',
              const Duration(seconds: 1),
            ),
          ),
        );
        expect(refreshCalls, hasLength(1));

        now = now.add(const Duration(seconds: 1));
        onRefresh = (_) async => issueTokens(issuedAt: now);
        await manager.validAccessToken();
        expect(refreshCalls, hasLength(2));
      },
    );

    test('a failed token write keeps the rotated tokens in memory and '
        'stores them before the next refresh', () async {
      final old = await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      final next = issueTokens(issuedAt: now.add(const Duration(minutes: 10)));
      final rotations = [fresh, next];
      onRefresh = (_) async => rotations.removeAt(0);
      var failWrite = true;
      secureStore.beforeWrite = (_) async {
        if (failWrite) {
          failWrite = false;
          throw StateError('keystore');
        }
      };
      final manager = createManager();

      expect(await manager.validAccessToken(), fresh.accessToken);
      expect(await storedRefreshToken(), old.refreshToken);

      now = now.add(const Duration(minutes: 10));
      expect(await manager.validAccessToken(), next.accessToken);
      expect(refreshCalls, [old.refreshToken, fresh.refreshToken]);
      expect(await storedRefreshToken(), next.refreshToken);
      expect(ended, isEmpty);
    });

    test(
      'a write that keeps failing still rotates with the token in memory',
      () async {
        final old = await store(expiresIn: Duration.zero);
        final fresh = issueTokens(issuedAt: now);
        onRefresh = (_) async => fresh;
        secureStore.beforeWrite = (_) async => throw StateError('keystore');
        final manager = createManager();
        await manager.validAccessToken();

        now = now.add(const Duration(minutes: 10));
        onRefresh = (_) async => issueTokens(issuedAt: now);
        await manager.validAccessToken();

        expect(refreshCalls, [old.refreshToken, fresh.refreshToken]);
        expect(ended, isEmpty);
      },
    );

    test('tokens another isolate stores replace unpersisted ones', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => issueTokens(issuedAt: now);
      var failWrite = true;
      secureStore.beforeWrite = (_) async {
        if (failWrite) {
          failWrite = false;
          throw StateError('keystore');
        }
      };
      final manager = createManager();
      await manager.validAccessToken();

      now = now.add(const Duration(minutes: 10));
      final sibling = issueTokens(issuedAt: now, sessionId: 'session-2');
      await tokenStore.write(_accountId, sibling);

      expect(await manager.validAccessToken(), sibling.accessToken);
      expect(refreshCalls, hasLength(1));
    });

    test('no stored tokens means the session ended', () async {
      await expectLater(
        createManager().validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(ended, hasLength(1));
    });
  });

  group('retire', () {
    test('does not wait for a refresh on the network and discards its '
        'result', () async {
      final stored = await store(expiresIn: Duration.zero);
      secureStore.operations.clear();
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final pending = expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await pumpEventQueue();
      await manager.retire();

      response.complete(issueTokens(issuedAt: now));
      await pending;
      expect(await storedRefreshToken(), stored.refreshToken);
      expect(secureStore.operations, isNot(contains(startsWith('write'))));
      expect(ended, isEmpty);
    });

    test('waits for a token write that has already started', () async {
      await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      onRefresh = (_) async => fresh;
      final writing = Completer<void>();
      final gate = Completer<void>();
      secureStore.beforeWrite = (_) {
        if (!writing.isCompleted) writing.complete();
        return gate.future;
      };
      final manager = createManager();
      unawaited(manager.validAccessToken().then((_) {}, onError: (_) {}));
      await writing.future;

      var retired = false;
      final retiring = manager.retire().then((_) => retired = true);
      await pumpEventQueue();
      expect(retired, isFalse);

      gate.complete();
      await retiring;
      expect(await storedRefreshToken(), fresh.refreshToken);
    });

    test('a retired manager hands out nothing', () async {
      final stored = await store(expiresIn: const Duration(minutes: 5));
      final manager = createManager();
      await manager.retire();

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(await manager.refreshAfterRejection(stored.accessToken), isNull);
      expect(refreshCalls, isEmpty);
      expect(ended, isEmpty);
    });

    test('a new sign-in during a refresh keeps its own tokens', () async {
      await store(expiresIn: Duration.zero);
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final pending = manager.validAccessToken();
      await pumpEventQueue();
      final signIn = issueTokens(issuedAt: now, sessionId: 'session-2');
      await tokenStore.write(_accountId, signIn);
      response.complete(issueTokens(issuedAt: now));

      expect(await pending, signIn.accessToken);
      expect(await storedRefreshToken(), signIn.refreshToken);
    });
  });

  group('SessionManagers', () {
    late FakeTokenGateway gateway;
    late List<String> flagged;
    late SessionManagers managers;

    setUp(() {
      gateway = FakeTokenGateway();
      flagged = [];
      managers = SessionManagers(
        tokenStore: tokenStore,
        clockOffsets: clockOffsets,
        tokenGateway: gateway,
        connectionFor: (accountId) async =>
            accountId == _accountId ? fullServer270() : null,
        markNeedsReauth: (accountId) async => flagged.add(accountId),
        clock: () => now,
        sleep: (_) async {},
      );
    });

    test('keeps one manager per account', () {
      expect(
        managers.forAccount(_accountId),
        same(managers.forAccount(_accountId)),
      );
    });

    test('a retired account hands out nothing and writes nothing until it '
        'signs in again', () async {
      final stored = await store(expiresIn: Duration.zero);
      gateway.onRefresh = (_) async => issueTokens(issuedAt: now);
      await managers.retire(_accountId);

      final late = managers.forAccount(_accountId);
      expect(await late.refreshAfterRejection(stored.accessToken), isNull);
      await expectLater(late.validAccessToken(), throwsA(isA<SessionEnded>()));
      expect(gateway.refreshedTokens, isEmpty);
      expect(await storedRefreshToken(), stored.refreshToken);

      final signIn = issueTokens(issuedAt: now, sessionId: 'session-2');
      await tokenStore.write(_accountId, signIn);
      final fresh = await managers.signedIn(
        _accountId,
        signIn,
        receivedAt: now,
      );

      expect(managers.forAccount(_accountId), same(fresh));
      expect(await fresh.validAccessToken(), signIn.accessToken);
      expect(flagged, isEmpty);
    });

    test('signing in again retires the previous manager', () async {
      await store(expiresIn: const Duration(minutes: 5));
      final previous = managers.forAccount(_accountId);
      final signIn = issueTokens(issuedAt: now, sessionId: 'session-2');

      await managers.signedIn(_accountId, signIn, receivedAt: now);

      await expectLater(
        previous.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
    });

    test('refreshes through the gateway and flags ended sessions', () async {
      final stored = await store(expiresIn: Duration.zero);
      gateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired);

      await expectLater(
        managers.forAccount(_accountId).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(gateway.refreshedTokens, [stored.refreshToken]);
      expect(flagged, [_accountId]);
    });
  });
}
