import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/server_clock_offsets.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/secure_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/server_connections.dart';

const _accountId = 'a1';
const _raceLost = RefreshRaceLost(message: 'already used');
const _refused = SessionEnded(
  SessionEndReason.invalidRefreshToken,
  code: 16002,
);

typedef _Call = Future<Object?> Function(SessionManager manager);

final class _FlakySecureStore implements SecureStore {
  new(this._store);

  final SecureStore _store;
  bool failNextRead = false;

  @override
  Future<String?> read(String key) async {
    if (failNextRead) {
      failNextRead = false;
      throw PlatformException(code: '-25308');
    }
    return await _store.read(key);
  }

  @override
  Future<void> write(String key, String value, {bool recoverLostKey = false}) =>
      _store.write(key, value, recoverLostKey: recoverLostKey);

  @override
  Future<void> delete(String key) => _store.delete(key);

  @override
  Future<void> deleteAll() => _store.deleteAll();

  @override
  Future<void> flush() => _store.flush();
}

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

  SessionManager createManager({
    SessionDiagnostics? diagnostics,
    AppPart part = AppPart.app,
    RefreshGate? mayStartRefresh,
  }) => SessionManager(
    accountId: _accountId,
    tokenStore: tokenStore,
    clockOffsets: clockOffsets,
    diagnostics: diagnostics,
    part: part,
    mayStartRefresh: mayStartRefresh,
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

    test('a race the replacing session then loses looks for the tokens that '
        'replace those, without sending them again', () async {
      final first = await store(expiresIn: Duration.zero);
      final signIn = issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 9, seconds: 30)),
        sessionId: 'session-2',
      );
      final winner = issueTokens(issuedAt: now, sessionId: 'session-2');
      onRefresh = (refreshToken) async {
        if (refreshToken == first.refreshToken) {
          await tokenStore.write(_accountId, signIn);
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
        }
        throw _raceLost;
      };
      duringSleep = (index) async {
        if (index == 2) await tokenStore.write(_accountId, winner);
      };

      expect(await createManager().validAccessToken(), winner.accessToken);
      expect(refreshCalls, [first.refreshToken, signIn.refreshToken]);
      expect(sleeps, SessionManager.raceRecheckDelays.take(2));
      expect(ended, isEmpty);
    });

    test('so does one the recovery from a lost race meets', () async {
      const stale = Duration(minutes: 9, seconds: 30);
      final first = await store(expiresIn: Duration.zero);
      final second = issueTokens(
        issuedAt: now.subtract(stale),
        sessionId: 'session-2',
      );
      final third = issueTokens(
        issuedAt: now.subtract(stale),
        sessionId: 'session-3',
      );
      final winner = issueTokens(issuedAt: now, sessionId: 'session-3');
      onRefresh = (refreshToken) async {
        if (refreshToken == second.refreshToken) {
          await tokenStore.write(_accountId, third);
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
        }
        throw _raceLost;
      };
      duringSleep = (index) async {
        if (index == 1) await tokenStore.write(_accountId, second);
        if (index == 3) await tokenStore.write(_accountId, winner);
      };

      expect(await createManager().validAccessToken(), winner.accessToken);
      expect(refreshCalls, [
        first.refreshToken,
        second.refreshToken,
        third.refreshToken,
      ]);
      expect(sleeps, SessionManager.raceRecheckDelays.take(3));
      expect(ended, isEmpty);
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

    test('a lost race whose winner never stores its tokens fails for now '
        'and keeps the session: the winner holds a live one', () async {
      final stored = await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _raceLost;
      final manager = createManager();

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(sleeps, SessionManager.raceRecheckDelays);
      expect(ended, isEmpty);
      expect(await storedRefreshToken(), stored.refreshToken);

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(refreshCalls, hasLength(2));
    });

    test('a refusal without any sign of a race ends the session after the '
        'recheck', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _refused;
      final manager = createManager();

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>().having((f) => f.code, 'code', 16002)),
      );
      expect(sleeps, SessionManager.raceRecheckDelays);
      expect(ended, hasLength(1));

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(refreshCalls, hasLength(1));
    });

    for (final (name, call) in <(String, _Call)>[
      ('the next call', (manager) => manager.validAccessToken()),
      (
        'a rejection of an older token',
        (manager) => manager.refreshAfterRejection('older-access-token'),
      ),
      ('settling', (manager) => manager.settle()),
    ]) {
      test('tokens kept after a failed read are stored at $name, so a '
          'sibling that refreshes from storage keeps the session', () async {
        final flaky = _FlakySecureStore(secureStore);
        tokenStore = TokenStore(flaky);
        final old = await store(expiresIn: Duration.zero);
        // Like Vikunja: a refresh token works once.
        var valid = old.refreshToken;
        Future<TokenSet> server(String refreshToken) async {
          if (refreshToken != valid) {
            throw const SessionEnded(
              SessionEndReason.invalidRefreshToken,
              code: 16002,
            );
          }
          final fresh = issueTokens(issuedAt: now);
          valid = fresh.refreshToken;
          return fresh;
        }

        onRefresh = (refreshToken) async {
          final fresh = await server(refreshToken);
          flaky.failNextRead = true;
          return fresh;
        };
        final manager = createManager();
        await manager.validAccessToken();
        expect(await storedRefreshToken(), old.refreshToken);

        await call(manager);

        expect(await storedRefreshToken(), valid);
        now = now.add(const Duration(minutes: 10));
        final sibling = SessionManager(
          accountId: _accountId,
          tokenStore: TokenStore(secureStore),
          refresh: server,
          onSessionEnded: (failure) async => ended.add(failure),
          clock: () => now,
          sleep: (_) async {},
        );
        await sibling.validAccessToken();
        expect(ended, isEmpty);
      });
    }

    test('a refresh waits for a write of kept tokens that has started, so '
        'the older tokens do not land last', () async {
      final flaky = _FlakySecureStore(secureStore);
      tokenStore = TokenStore(flaky);
      final old = await store(expiresIn: Duration.zero);
      final t1 = issueTokens(issuedAt: now);
      final t2 = issueTokens(issuedAt: now);
      final rotations = [t1, t2];
      onRefresh = (_) async {
        flaky.failNextRead = refreshCalls.length == 1;
        return rotations.removeAt(0);
      };
      final manager = createManager();
      await manager.validAccessToken();
      final gate = Completer<void>();
      var held = false;
      secureStore.beforeWrite = (_) {
        if (held) return Future.value();
        held = true;
        return gate.future;
      };

      final call = manager.validAccessToken();
      await pumpEventQueue();
      final refresh = manager.refreshNow();
      await pumpEventQueue();
      expect(refreshCalls, [old.refreshToken]);

      gate.complete();
      expect(await call, t1.accessToken);
      await refresh;
      expect(refreshCalls, [old.refreshToken, t1.refreshToken]);
      expect(await storedRefreshToken(), t2.refreshToken);
    });

    test('a refusal right after a server error is a race, not an end: the '
        'error may have rotated the token', () async {
      await store(expiresIn: Duration.zero);
      var calls = 0;
      onRefresh = (_) async =>
          throw ++calls == 1 ? const ServerFailure(500) : _refused;

      await expectLater(
        createManager().validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(ended, isEmpty);
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

    test('a failed read before storing the rotated tokens keeps them in '
        'memory and stores them before the next refresh', () async {
      final flaky = _FlakySecureStore(secureStore);
      tokenStore = TokenStore(flaky);
      final old = await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      final next = issueTokens(issuedAt: now.add(const Duration(minutes: 10)));
      final rotations = [fresh, next];
      final storedAtRefresh = <String?>[];
      onRefresh = (_) async {
        storedAtRefresh.add(await storedRefreshToken());
        flaky.failNextRead = refreshCalls.length == 1;
        return rotations.removeAt(0);
      };
      final manager = createManager();

      expect(await manager.validAccessToken(), fresh.accessToken);
      expect(await storedRefreshToken(), old.refreshToken);

      now = now.add(const Duration(minutes: 10));
      expect(await manager.validAccessToken(), next.accessToken);
      expect(refreshCalls, [old.refreshToken, fresh.refreshToken]);
      expect(storedAtRefresh, [old.refreshToken, fresh.refreshToken]);
      expect(await storedRefreshToken(), next.refreshToken);
      expect(ended, isEmpty);
    });

    test('after a failed read, the rotated tokens do not replace a newer '
        'sign-in', () async {
      final flaky = _FlakySecureStore(secureStore);
      tokenStore = TokenStore(flaky);
      await store(expiresIn: Duration.zero);
      final signIn = issueTokens(
        issuedAt: now.add(const Duration(minutes: 5)),
        sessionId: 'session-2',
      );
      onRefresh = (_) async {
        // A sign-in in another isolate while the refresh is on the network.
        await tokenStore.write(_accountId, signIn);
        flaky.failNextRead = true;
        return issueTokens(issuedAt: now);
      };
      final manager = createManager();
      await manager.validAccessToken();
      expect(await storedRefreshToken(), signIn.refreshToken);

      now = now.add(const Duration(minutes: 10));
      expect(await manager.validAccessToken(), signIn.accessToken);
      expect(await storedRefreshToken(), signIn.refreshToken);
      expect(refreshCalls, hasLength(1));
      expect(ended, isEmpty);
    });

    test('a failed read after a write that failed twice keeps the tokens '
        'tied to the refresh token storage still holds', () async {
      final flaky = _FlakySecureStore(secureStore);
      tokenStore = TokenStore(flaky);
      final old = await store(expiresIn: Duration.zero);
      final t1 = issueTokens(issuedAt: now);
      final t2 = issueTokens(issuedAt: now.add(const Duration(minutes: 10)));
      final t3 = issueTokens(issuedAt: now.add(const Duration(minutes: 20)));
      final rotations = [t1, t2, t3];
      var failWrites = true;
      secureStore.beforeWrite = (_) async {
        if (failWrites) throw StateError('keystore');
      };
      onRefresh = (_) async {
        flaky.failNextRead = refreshCalls.length == 2;
        return rotations.removeAt(0);
      };
      final manager = createManager();
      expect(await manager.validAccessToken(), t1.accessToken);

      now = now.add(const Duration(minutes: 10));
      expect(await manager.validAccessToken(), t2.accessToken);
      expect(await storedRefreshToken(), old.refreshToken);

      failWrites = false;
      now = now.add(const Duration(minutes: 10));
      expect(await manager.validAccessToken(), t3.accessToken);
      expect(refreshCalls, [
        old.refreshToken,
        t1.refreshToken,
        t2.refreshToken,
      ]);
      expect(await storedRefreshToken(), t3.refreshToken);
      expect(ended, isEmpty);
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

    test('discards a late refresh result even when storage cannot be '
        'read', () async {
      final flaky = _FlakySecureStore(secureStore);
      tokenStore = TokenStore(flaky);
      final stored = await store(expiresIn: Duration.zero);
      final response = Completer<TokenSet>();
      onRefresh = (_) => response.future;
      final manager = createManager();

      final pending = expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await pumpEventQueue();
      await manager.retire();

      flaky.failNextRead = true;
      response.complete(issueTokens(issuedAt: now));
      await pending;
      expect(await storedRefreshToken(), stored.refreshToken);
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

    for (final (what, connectionFor)
        in <(String, Future<ServerConnection?> Function(String))>[
          ('without a stored connection', (_) async => null),
          (
            'whose registry cannot be read',
            (_) async => throw StateError('registry'),
          ),
        ]) {
      test('an account $what fails for now and stays signed in, with no send '
          'noted and no re-reads', () async {
        await store(expiresIn: Duration.zero);
        final diagnostics = SessionDiagnostics(preferences);
        final elsewhere = SessionManagers(
          tokenStore: tokenStore,
          clockOffsets: clockOffsets,
          tokenGateway: gateway,
          connectionFor: connectionFor,
          markNeedsReauth: (accountId) async => flagged.add(accountId),
          diagnostics: diagnostics,
          clock: () => now,
          sleep: (duration) async => sleeps.add(duration),
        );

        await expectLater(
          elsewhere.forAccount(_accountId).validAccessToken(),
          throwsA(isA<UnexpectedResponse>()),
        );
        expect(flagged, isEmpty);
        expect(gateway.refreshedTokens, isEmpty);
        expect(await diagnostics.refreshMarker(_accountId), isNull);
        expect(sleeps, isEmpty);
      });
    }

    group('tryRestore', () {
      late SessionDiagnostics diagnostics;
      late List<String> cleared;
      late SessionManagers restoring;

      setUp(() {
        diagnostics = SessionDiagnostics(preferences);
        cleared = [];
        restoring = SessionManagers(
          tokenStore: tokenStore,
          clockOffsets: clockOffsets,
          tokenGateway: gateway,
          connectionFor: (accountId) async =>
              accountId == _accountId ? fullServer270() : null,
          markNeedsReauth: (accountId) async => flagged.add(accountId),
          clearNeedsReauth: (accountId) async => cleared.add(accountId),
          diagnostics: diagnostics,
          clock: () => now,
          sleep: (_) async {},
        );
      });

      Future<void> ended(
        SessionEndCause cause, {
        String? failedToken,
        SessionEndResolution? resolution,
      }) => diagnostics.recordEnd(
        _accountId,
        SessionEndDiagnosis(
          at: now,
          cause: cause,
          part: AppPart.backgroundRun,
          failedToken: failedToken,
          resolution: resolution,
        ),
      );

      test('clears the mark when storage holds newer tokens the server '
          'takes', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
        );
        final stored = await store(expiresIn: const Duration(minutes: 5));
        final fresh = issueTokens(issuedAt: now);
        gateway.onRefresh = (_) async => fresh;

        expect(await restoring.tryRestore(_accountId), isTrue);

        expect(gateway.refreshedTokens, [stored.refreshToken]);
        expect(cleared, [_accountId]);
        expect(await storedRefreshToken(), fresh.refreshToken);
        expect(
          await restoring.forAccount(_accountId).validAccessToken(),
          fresh.accessToken,
        );
      });

      test('leaves the mark when storage still holds the token that '
          'failed', () async {
        final stored = await store(expiresIn: Duration.zero);
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint(stored.refreshToken),
        );

        expect(await restoring.tryRestore(_accountId), isFalse);
        expect(gateway.refreshedTokens, isEmpty);
        expect(cleared, isEmpty);
      });

      test('leaves the mark and the record when storage still holds the '
          'token a refresh in another isolate rotated away, as it could not '
          'store the rotated tokens', () async {
        final stored = await store(expiresIn: Duration.zero);
        final rotated = issueTokens(issuedAt: now);
        // Like Vikunja: a refresh token works once.
        var valid = stored.refreshToken;
        gateway.onRefresh = (refreshToken) async {
          if (refreshToken != valid) throw _refused;
          valid = '';
          return rotated;
        };
        secureStore.beforeWrite = (_) async => throw StateError('keystore');
        final app = SessionManagers(
          tokenStore: tokenStore,
          clockOffsets: clockOffsets,
          tokenGateway: gateway,
          connectionFor: (_) async => fullServer270(),
          markNeedsReauth: (accountId) async => flagged.add(accountId),
          diagnostics: diagnostics,
          clock: () => now,
          sleep: (_) async {},
        ).forAccount(_accountId);
        expect(await app.validAccessToken(), rotated.accessToken);
        now = now.add(const Duration(minutes: 10));
        await expectLater(app.validAccessToken(), throwsA(isA<SessionEnded>()));
        secureStore.beforeWrite = null;
        expect(await storedRefreshToken(), stored.refreshToken);
        final ended = (await diagnostics.lastEnd(_accountId))!;
        expect(ended.failedToken, tokenFingerprint(rotated.refreshToken));
        expect(ended.rotatedAwayToken, tokenFingerprint(stored.refreshToken));
        gateway.refreshedTokens.clear();

        expect(await restoring.tryRestore(_accountId), isFalse);

        expect(gateway.refreshedTokens, isEmpty);
        expect(cleared, isEmpty);
        expect(
          (await diagnostics.lastEnd(_accountId))!.failedToken,
          tokenFingerprint(rotated.refreshToken),
        );
      });

      test('leaves the mark and records the new refusal when the newer '
          'tokens fail too', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
        );
        final stored = await store(expiresIn: Duration.zero);
        gateway.onRefresh = (_) async => throw _refused;

        expect(await restoring.tryRestore(_accountId), isFalse);

        expect(cleared, isEmpty);
        expect(
          (await diagnostics.lastEnd(_accountId))!.failedToken,
          tokenFingerprint(stored.refreshToken),
        );
        expect(await restoring.tryRestore(_accountId), isFalse);
        expect(gateway.refreshedTokens, hasLength(1));
      });

      test('a restore resolves the ended session and ends a run of '
          'unreadable reads', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
        );
        await store(expiresIn: const Duration(minutes: 5));
        gateway.onRefresh = (_) async => issueTokens(issuedAt: now);
        // The manager read storage fine before the failures were noted.
        await restoring.forAccount(_accountId).validAccessToken();
        await diagnostics.noteUnreadable(_accountId, now);

        expect(await restoring.tryRestore(_accountId), isTrue);

        expect(
          (await diagnostics.lastEnd(_accountId))!.resolution,
          SessionEndResolution.restored,
        );
        expect(
          preferences.values,
          isNot(contains(SessionDiagnostics.unreadableSinceKey(_accountId))),
        );
      });

      test(
        'a session another isolate restored is only unmarked here',
        () async {
          await ended(
            SessionEndCause.refreshRejected,
            failedToken: tokenFingerprint('refresh-that-failed'),
            resolution: SessionEndResolution.restored,
          );
          await store(expiresIn: Duration.zero);

          expect(await restoring.tryRestore(_accountId), isTrue);

          expect(cleared, [_accountId]);
          expect(gateway.refreshedTokens, isEmpty);
        },
      );

      test('a session ended again while the registry could not be read is '
          'not taken for the one another isolate restored', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
          resolution: SessionEndResolution.restored,
        );
        await store(expiresIn: Duration.zero);
        gateway.onRefresh = (_) async =>
            throw const SessionEnded(SessionEndReason.expired, code: 16003);
        final app = SessionManagers(
          tokenStore: tokenStore,
          clockOffsets: clockOffsets,
          tokenGateway: gateway,
          connectionFor: (_) async => fullServer270(),
          markNeedsReauth: (accountId) async => flagged.add(accountId),
          diagnostics: SessionDiagnostics(
            preferences,
            accountExists: (_) async => throw StateError('registry'),
          ),
          clock: () => now,
          sleep: (_) async {},
        ).forAccount(_accountId);
        await expectLater(app.validAccessToken(), throwsA(isA<SessionEnded>()));
        expect(flagged, [_accountId]);

        expect(await restoring.tryRestore(_accountId), isFalse);

        expect(cleared, isEmpty);
        final record = (await diagnostics.lastEnd(_accountId))!;
        expect(record.cause, SessionEndCause.sessionExpired);
        expect(record.resolution, isNull);
      });

      test('keeps a live manager whose refresh is on its way, so its answer '
          'is stored, not dropped', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
        );
        final stored = await store(expiresIn: Duration.zero);
        // Like Vikunja: a refresh token works once, rotated on receipt.
        var valid = stored.refreshToken;
        final answer = Completer<void>();
        final rotated = issueTokens(issuedAt: now);
        gateway.onRefresh = (refreshToken) async {
          if (refreshToken != valid) throw _refused;
          valid = rotated.refreshToken;
          await answer.future;
          return rotated;
        };

        final live = restoring.forAccount(_accountId).validAccessToken();
        await pumpEventQueue();
        final restore = restoring.tryRestore(_accountId);
        await pumpEventQueue();
        answer.complete();

        expect(await live, rotated.accessToken);
        expect(await restore, isTrue);
        expect(gateway.refreshedTokens, [stored.refreshToken]);
        expect(await storedRefreshToken(), rotated.refreshToken);
        expect(flagged, isEmpty);
      });

      test('tries storage again that could not be read before', () async {
        await ended(SessionEndCause.storageUnreadable);
        await store(expiresIn: Duration.zero);
        gateway.onRefresh = (_) async => issueTokens(issuedAt: now);

        expect(await restoring.tryRestore(_accountId), isTrue);
        expect(cleared, [_accountId]);
      });

      for (final (what, record) in [
        ('no record', null),
        (
          'an end a sign-in resolved',
          (SessionEndCause.refreshRejected, SessionEndResolution.goneOnServer),
        ),
        ('an expired session', (SessionEndCause.sessionExpired, null)),
        ('missing tokens', (SessionEndCause.missingTokens, null)),
      ]) {
        test('does nothing for $what', () async {
          if (record case (final cause, final resolution)) {
            await ended(
              cause,
              failedToken: tokenFingerprint('other'),
              resolution: resolution,
            );
          }
          await store(expiresIn: Duration.zero);

          expect(await restoring.tryRestore(_accountId), isFalse);
          expect(gateway.refreshedTokens, isEmpty);
        });
      }

      test('does nothing without the means to clear the mark', () async {
        await ended(
          SessionEndCause.refreshRejected,
          failedToken: tokenFingerprint('refresh-that-failed'),
        );
        await store(expiresIn: Duration.zero);

        expect(await managers.tryRestore(_accountId), isFalse);
        expect(gateway.refreshedTokens, isEmpty);
      });
    });

    test('an ended manager takes the tokens another isolate stored later, '
        'and only those', () async {
      final refused = await store(expiresIn: Duration.zero);
      gateway.onRefresh = (_) async => throw _refused;
      final manager = managers.forAccount(_accountId);
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(gateway.refreshedTokens, [refused.refreshToken]);

      // A background run restored the session meanwhile.
      final restored = issueTokens(issuedAt: now);
      await tokenStore.write(_accountId, restored);

      expect(
        await managers.forAccount(_accountId).validAccessToken(),
        restored.accessToken,
      );
      expect(gateway.refreshedTokens, [refused.refreshToken]);
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

    test('hands an ended session on with its reason, once the account is '
        'flagged', () async {
      await store(expiresIn: Duration.zero);
      gateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired, code: 16003);
      final events = <String>[];
      final handed = <(String, SessionEnded)>[];
      final reporting = SessionManagers(
        tokenStore: tokenStore,
        clockOffsets: clockOffsets,
        tokenGateway: gateway,
        connectionFor: (accountId) async => fullServer270(),
        markNeedsReauth: (accountId) async => events.add('flagged $accountId'),
        onSessionEnded: (accountId, failure) async {
          events.add('handed on $accountId');
          handed.add((accountId, failure));
        },
        clock: () => now,
        sleep: (_) async {},
      );

      await expectLater(
        reporting.forAccount(_accountId).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(events, ['flagged $_accountId', 'handed on $_accountId']);
      final (accountId, failure) = handed.single;
      expect(accountId, _accountId);
      expect(failure.reason, SessionEndReason.expired);
    });
  });

  group('diagnostics (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;

    setUp(() => diagnostics = SessionDiagnostics(preferences));

    Future<void> refreshFails(
      VikunjaFailure failure, {
      AppPart part = AppPart.app,
    }) async {
      onRefresh = (_) async => throw failure;
      await expectLater(
        createManager(diagnostics: diagnostics, part: part).validAccessToken(),
        throwsA(isA<VikunjaFailure>()),
      );
    }

    test('a refusal records why, where and with which token', () async {
      final stored = await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _refused;

      await expectLater(
        createManager(
          diagnostics: diagnostics,
          part: AppPart.backgroundRun,
        ).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.cause, SessionEndCause.refreshRejected);
      expect(record.code, 16002);
      expect(record.part, AppPart.backgroundRun);
      expect(record.at, now);
      expect(record.failedToken, tokenFingerprint(stored.refreshToken));
      expect(record.lostRefreshAt, isNull);
      expect(await diagnostics.refreshMarker(_accountId), isNull);
    });

    test('a refusal of a token whose earlier refresh never got its answer '
        'stored names that refresh as the lost one', () async {
      final stored = await store(expiresIn: Duration.zero);
      final lostAt = now;
      // The server rotates, but the answer never arrives.
      await refreshFails(
        const NetworkFailure(NetworkProblem.timeout),
        part: AppPart.backgroundRun,
      );
      expect(
        (await diagnostics.refreshMarker(_accountId))!.token,
        tokenFingerprint(stored.refreshToken),
      );

      now = now.add(const Duration(minutes: 30));
      await refreshFails(_refused);

      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.part, AppPart.app);
      expect(record.lostRefreshAt, lostAt);
      expect(record.lostRefreshPart, AppPart.backgroundRun);
    });

    test('the earliest unanswered send is named, not a later one', () async {
      await store(expiresIn: Duration.zero);
      final lostAt = now;
      await refreshFails(
        const NetworkFailure(NetworkProblem.timeout),
        part: AppPart.backgroundRun,
      );
      now = now.add(const Duration(minutes: 15));
      await refreshFails(const NetworkFailure(NetworkProblem.timeout));
      now = now.add(const Duration(minutes: 15));
      await refreshFails(_refused);

      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.lostRefreshAt, lostAt);
      expect(record.lostRefreshPart, AppPart.backgroundRun);
    });

    for (final (what, failure) in [
      ('a rate limit', const RateLimited(retryAfter: Duration(seconds: 30))),
      ('a 401 from something in front of 2.7.0', const UnexpectedResponse(401)),
      ('a 403 from a proxy', const UnexpectedResponse(403)),
      ('a TLS failure', const NetworkFailure(NetworkProblem.tls)),
      (
        'no connection at all',
        const NetworkFailure(
          NetworkProblem.unreachable,
          cause: SocketException('Failed host lookup: tasks.example.com'),
        ),
      ),
    ]) {
      test('a send answered by $what never rotated the token, so a later '
          'refusal names no lost answer', () async {
        await store(expiresIn: Duration.zero);
        await refreshFails(failure);
        expect(await diagnostics.refreshMarker(_accountId), isNull);

        now = now.add(const Duration(hours: 3));
        await refreshFails(_refused);

        expect((await diagnostics.lastEnd(_accountId))!.lostRefreshAt, isNull);
      });
    }

    test('a send that never reached the server keeps an earlier lost one '
        'named', () async {
      await store(expiresIn: Duration.zero);
      final lostAt = now;
      await refreshFails(const NetworkFailure(NetworkProblem.timeout));
      now = now.add(const Duration(minutes: 10));
      await refreshFails(const RateLimited(retryAfter: Duration(seconds: 1)));
      now = now.add(const Duration(minutes: 10));
      await refreshFails(_refused);

      expect((await diagnostics.lastEnd(_accountId))!.lostRefreshAt, lostAt);
    });

    test('a retry after a server error that never reached the server keeps '
        'the first send named', () async {
      await store(expiresIn: Duration.zero);
      final lostAt = now;
      onRefresh = (_) async {
        if (refreshCalls.length == 1) throw const ServerFailure(502);
        throw const NetworkFailure(
          NetworkProblem.unreachable,
          cause: SocketException('Connection refused'),
        );
      };
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(refreshCalls, hasLength(2));

      now = now.add(const Duration(minutes: 30));
      await refreshFails(_refused);

      expect((await diagnostics.lastEnd(_accountId))!.lostRefreshAt, lostAt);
    });

    test('a refresh in flight while the account is signed out leaves no '
        'notes behind', () async {
      await store(expiresIn: Duration.zero);
      var registered = true;
      final guarded = SessionDiagnostics(
        preferences,
        accountExists: (_) async => registered,
      );
      onRefresh = (_) async {
        // The app signs the account out meanwhile, and its wiper forgets
        // the account's notes.
        registered = false;
        await guarded.forget(_accountId);
        throw _refused;
      };

      await expectLater(
        createManager(diagnostics: guarded).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(
        preferences.values.keys.where((key) => key.startsWith('session.')),
        isEmpty,
      );
    });

    test('an isolate that finds no tokens of a signed-out account notes no '
        'end', () async {
      final guarded = SessionDiagnostics(
        preferences,
        accountExists: (_) async => false,
      );

      await expectLater(
        createManager(diagnostics: guarded).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(await guarded.lastEnd(_accountId), isNull);
    });

    test('a refusal is noted before the re-reads, so a run the OS ends '
        'during them leaves no unanswered send', () async {
      await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _raceLost;
      duringSleep = (_) async => throw StateError('the run ended');
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<StateError>()),
      );
      expect(await diagnostics.lastEnd(_accountId), isNull);
      expect((await diagnostics.refreshMarker(_accountId))!.sentAt, isNull);

      duringSleep = null;
      now = now.add(const Duration(minutes: 15));
      await refreshFails(_refused);

      expect((await diagnostics.lastEnd(_accountId))!.lostRefreshAt, isNull);
    });

    test('a refresh whose tokens are stored clears its mark', () async {
      await store(expiresIn: Duration.zero);

      await createManager(diagnostics: diagnostics).validAccessToken();

      expect(await diagnostics.refreshMarker(_accountId), isNull);
      expect(await diagnostics.lastEnd(_accountId), isNull);
    });

    test('missing tokens are recorded as such', () async {
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.cause, SessionEndCause.missingTokens);
      expect(record.failedToken, isNull);
      expect(refreshCalls, isEmpty);
    });

    test('a good read ends a run of unreadable reads', () async {
      await store(expiresIn: const Duration(minutes: 5));
      await diagnostics.noteUnreadable(_accountId, now);

      await createManager(diagnostics: diagnostics).validAccessToken();

      expect(
        preferences.values,
        isNot(contains(SessionDiagnostics.unreadableSinceKey(_accountId))),
      );
    });
  });

  group('an ended session (decision log: Sessions)', () {
    test('stays ended when storage still holds a refresh token rotated away '
        'here, whose successor could not be stored', () async {
      final diagnostics = SessionDiagnostics(preferences);
      final t1 = await store(expiresIn: Duration.zero);
      final t2 = issueTokens(issuedAt: now);
      // The server then deletes the session, with T1 already rotated away.
      onRefresh = (_) async => refreshCalls.length == 1 ? t2 : throw _refused;
      secureStore.beforeWrite = (_) async => throw StateError('keystore');
      final manager = createManager(diagnostics: diagnostics);
      expect(await manager.validAccessToken(), t2.accessToken);

      now = now.add(const Duration(minutes: 10));
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(refreshCalls, [t1.refreshToken, t2.refreshToken]);
      expect(ended, hasLength(1));
      expect(
        (await diagnostics.lastEnd(_accountId))!.failedToken,
        tokenFingerprint(t2.refreshToken),
      );
    });

    test('hands out no access token that came with a refresh token rotated '
        'away here', () async {
      final t1 = await store(expiresIn: const Duration(minutes: 8));
      final t2 = issueTokens(issuedAt: now);
      onRefresh = (_) async => refreshCalls.length == 1 ? t2 : throw _refused;
      secureStore.beforeWrite = (_) async => throw StateError('keystore');
      final manager = createManager();
      await manager.refreshNow();
      await expectLater(manager.refreshNow(), throwsA(isA<SessionEnded>()));

      await expectLater(
        manager.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(refreshCalls, [t1.refreshToken, t2.refreshToken]);
      expect(ended, hasLength(1));
    });

    test('ends once, as missing tokens, when the tokens are gone by the time '
        'a refresh answer is to be stored', () async {
      final diagnostics = SessionDiagnostics(preferences);
      final stored = await store(expiresIn: Duration.zero);
      onRefresh = (_) async {
        await tokenStore.delete(_accountId);
        return issueTokens(issuedAt: now);
      };

      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(refreshCalls, [stored.refreshToken]);
      expect(sleeps, isEmpty);
      expect(ended, hasLength(1));
      expect(
        (await diagnostics.lastEnd(_accountId))!.cause,
        SessionEndCause.missingTokens,
      );
      expect(await storedRefreshToken(), isNull);
    });

    test('ends once, as missing tokens, when the tokens are gone after a '
        'server error, without noting a refusal or reading on', () async {
      final diagnostics = SessionDiagnostics(preferences);
      final stored = await store(expiresIn: const Duration(seconds: 30));
      onRefresh = (_) async => throw const ServerFailure(503);
      var readsAfterDelete = 0;
      duringSleep = (_) async {
        await tokenStore.delete(_accountId);
        secureStore.beforeRead = (_) async {
          if (++readsAfterDelete > 1) {
            throw PlatformException(code: 'keystore');
          }
        };
      };

      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(refreshCalls, [stored.refreshToken]);
      expect(sleeps, hasLength(1));
      expect(readsAfterDelete, 1);
      expect(ended, hasLength(1));
      expect(
        (await diagnostics.lastEnd(_accountId))!.cause,
        SessionEndCause.missingTokens,
      );
      expect((await diagnostics.refreshMarker(_accountId))?.refusedAt, isNull);
    });

    test('ended while looking for the tokens of a race winner, throws the '
        'end at once instead of looking on', () async {
      final first = await store(expiresIn: Duration.zero);
      final second = issueTokens(
        issuedAt: now.subtract(const Duration(minutes: 9, seconds: 30)),
        sessionId: 'session-2',
      );
      onRefresh = (refreshToken) async {
        if (refreshToken == first.refreshToken) throw _raceLost;
        await tokenStore.delete(_accountId);
        return issueTokens(issuedAt: now, sessionId: 'session-2');
      };
      duringSleep = (index) async {
        if (index == 1) await tokenStore.write(_accountId, second);
      };

      await expectLater(
        createManager().validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(refreshCalls, [first.refreshToken, second.refreshToken]);
      expect(sleeps, SessionManager.raceRecheckDelays.take(1));
      expect(ended, hasLength(1));
    });
  });

  group('races across runs (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;

    setUp(() => diagnostics = SessionDiagnostics(preferences));

    test('a refusal after a server error is a race once; the same refusal '
        'after the window ends the session and names the first send, whose '
        'server error may have come after the rotation', () async {
      await store(expiresIn: Duration.zero);
      final firstSentAt = now;
      var calls = 0;
      onRefresh = (_) async {
        if ((calls++).isEven) throw const ServerFailure(503);
        throw _refused;
      };

      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.cause,
            'cause',
            RefreshDeferred.race,
          ),
        ),
      );
      expect(ended, isEmpty);

      now = now.add(const Duration(minutes: 30));
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(ended, hasLength(1));
      final record = (await diagnostics.lastEnd(_accountId))!;
      expect(record.lostRefreshAt, firstSentAt);
      expect(record.lostRefreshPart, AppPart.app);
    });

    test('a race lost to a sibling that stores its tokens later is no '
        'end', () async {
      final stored = await store(expiresIn: Duration.zero);
      onRefresh = (_) async => throw _raceLost;
      await expectLater(
        createManager(diagnostics: diagnostics).validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );

      now = now.add(const Duration(minutes: 30));
      final winner = issueTokens(issuedAt: now);
      await tokenStore.write(_accountId, winner);
      expect(
        await createManager(diagnostics: diagnostics).validAccessToken(),
        winner.accessToken,
      );
      expect(refreshCalls, [stored.refreshToken]);
      expect(ended, isEmpty);
    });
  });

  group('storage that refuses to read (decision log: Sessions)', () {
    test('fails a call as a network failure that names the storage', () async {
      await store(expiresIn: const Duration(minutes: 5));
      secureStore.beforeRead = (_) async =>
          throw PlatformException(code: 'keystore');

      await expectLater(
        createManager().validAccessToken(),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.cause,
            'cause',
            isA<SecureStorageUnreadable>(),
          ),
        ),
      );
      expect(ended, isEmpty);
    });

    test('reaches a request through the transport unchanged, without its '
        'retries and without a request', () async {
      await store(expiresIn: const Duration(minutes: 5));
      var reads = 0;
      secureStore.beforeRead = (_) async {
        reads++;
        throw PlatformException(code: 'keystore');
      };
      final adapter = _CountingAdapter();

      await expectLater(
        ApiAccountGateway(
          Dio()..httpClientAdapter = adapter,
          logRequests: false,
        ).currentUser(fullServer270(), createManager()),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.cause,
            'cause',
            isA<SecureStorageUnreadable>(),
          ),
        ),
      );
      expect(adapter.requests, 0);
      expect(reads, 1);
    });
  });

  group('the refresh gate (decision log: Sessions)', () {
    test('a closed gate defers a refresh before it is sent', () async {
      final stored = await store(expiresIn: Duration.zero);

      await expectLater(
        createManager(mayStartRefresh: () => false).validAccessToken(),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.cause,
            'cause',
            RefreshDeferred.cutoff,
          ),
        ),
      );
      expect(refreshCalls, isEmpty);
      expect(ended, isEmpty);
      expect(await storedRefreshToken(), stored.refreshToken);
    });

    for (final (what, close) in <(String, void Function(RefreshCutoff))>[
      ('the OS stops the run', (cutoff) => cutoff.closeNow()),
      (
        'its answer could no longer arrive in time',
        (_) => now = now.add(const Duration(seconds: 25)),
      ),
    ]) {
      test('a server error is not retried once $what, and the send stays '
          'noted', () async {
        final stored = await store(expiresIn: Duration.zero);
        final diagnostics = SessionDiagnostics(preferences);
        final cutoff = RefreshCutoff(
          clock: () => now,
          minimumTokenTimeout: const Duration(seconds: 8),
        )..answerWithin(const Duration(seconds: 30));
        final sentAt = now;
        onRefresh = (_) async {
          close(cutoff);
          throw const ServerFailure(502);
        };

        await expectLater(
          createManager(
            diagnostics: diagnostics,
            mayStartRefresh: () => cutoff.allowsRefresh,
          ).validAccessToken(),
          throwsA(
            isA<NetworkFailure>().having(
              (f) => f.cause,
              'cause',
              RefreshDeferred.cutoff,
            ),
          ),
        );
        expect(refreshCalls, [stored.refreshToken]);
        expect(ended, isEmpty);
        final marker = (await diagnostics.refreshMarker(_accountId))!;
        expect(marker.token, tokenFingerprint(stored.refreshToken));
        expect(marker.sentAt, sentAt);
      });
    }

    test('a valid token is still handed out with the gate closed', () async {
      final stored = await store(expiresIn: const Duration(minutes: 5));

      expect(
        await createManager(mayStartRefresh: () => false).validAccessToken(),
        stored.accessToken,
      );
    });

    test('RefreshCutoff counts the connect time in every answer and lets '
        'no refresh start with too little time left', () {
      final cutoff = RefreshCutoff(
        clock: () => now,
        connectTimeout: const Duration(seconds: 5),
        minimumTokenTimeout: const Duration(seconds: 8),
      );
      final start = now;
      expect(cutoff.allowsRefresh, isTrue);
      expect(cutoff.tokenTimeout, const Duration(seconds: 60));

      cutoff.answerWithin(const Duration(seconds: 28));
      expect(cutoff.tokenTimeout, const Duration(seconds: 23));
      now = start.add(const Duration(seconds: 15));
      expect(cutoff.tokenTimeout, const Duration(seconds: 8));
      expect(cutoff.allowsRefresh, isTrue);
      now = start.add(const Duration(seconds: 15, milliseconds: 500));
      expect(cutoff.allowsRefresh, isFalse);
    });

    test('RefreshCutoff closes at once when the OS stops the run', () {
      final cutoff = RefreshCutoff(clock: () => now)..closeNow();

      expect(cutoff.allowsRefresh, isFalse);
    });
  });

  group('settle (decision log: Sessions)', () {
    test('writes rotated tokens again that storage refused at first, a few '
        'times', () async {
      await store(expiresIn: Duration.zero);
      final fresh = issueTokens(issuedAt: now);
      onRefresh = (_) async => fresh;
      var refusals = 2;
      secureStore.beforeWrite = (_) async {
        if (refusals-- > 0) throw StateError('storage busy');
      };
      final manager = createManager();

      expect(await manager.validAccessToken(), fresh.accessToken);
      expect(await storedRefreshToken(), isNot(fresh.refreshToken));

      await manager.settle();

      expect(await storedRefreshToken(), fresh.refreshToken);
      expect(sleeps, [SessionManager.settleWriteRetryDelay]);
    });
  });
}

final class _CountingAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
