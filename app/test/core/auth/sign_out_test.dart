import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/sign_out.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late DateTime now;
  late AuthFakes fakes;
  late SessionDiagnostics diagnostics;
  late SessionManagers sessions;
  late LinkShareSessions linkShares;
  late AccountDeletions deletions;
  late SignOut signOut;
  late List<String> wiped;
  late Future<void> Function(String accountId) wipeAccountData;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    fakes = AuthFakes();
    wiped = [];
    wipeAccountData = (accountId) async => wiped.add(accountId);
    diagnostics = SessionDiagnostics(
      fakes.preferences,
      accountExists: (id) async => await fakes.registry.find(id) != null,
    );
    sessions = SessionManagers(
      tokenStore: fakes.tokenStore,
      clockOffsets: fakes.clockOffsets,
      tokenGateway: fakes.tokenGateway,
      connectionFor: (id) async => (await fakes.registry.find(id))?.connection,
      markNeedsReauth: fakes.registry.markNeedsReauth,
      clearNeedsReauth: fakes.registry.clearNeedsReauth,
      diagnostics: diagnostics,
      clock: () => now,
      sleep: (_) async {},
    );
    linkShares = LinkShareSessions(
      store: fakes.linkShareStore,
      gateway: fakes.linkShareGateway,
      connectionFor: (id) async => (await fakes.registry.find(id))?.connection,
      markNeedsReauth: fakes.registry.markNeedsReauth,
      clearNeedsReauth: fakes.registry.clearNeedsReauth,
      diagnostics: diagnostics,
      clock: () => now,
    );
    deletions = AccountDeletions(
      registry: fakes.registry,
      wipe: (accountId) => wipeAccountData(accountId),
    );
    signOut = SignOut(
      registry: fakes.registry,
      tokenStore: fakes.tokenStore,
      linkShareStore: fakes.linkShareStore,
      clockOffsets: fakes.clockOffsets,
      sessions: sessions,
      linkShares: linkShares,
      accountGateway: fakes.accountGateway,
      deletions: deletions,
      logoutTimeout: const Duration(milliseconds: 50),
      diagnostics: diagnostics,
      clock: () => now,
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
    expect(wiped, [alice.id]);
  });

  test(
    'deletes the local data once the registry has forgotten the account',
    () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      late bool registeredAtWipe;
      wipeAccountData = (accountId) async {
        registeredAtWipe = (await fakes.registry.find(accountId)) != null;
      };

      await signOut(alice.id);

      expect(registeredAtWipe, isFalse);
    },
  );

  test('a wipe that fails does not fail the sign-out, and leaves the '
      'account to delete for the next start', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );
    wipeAccountData = (_) async => throw StateError('disk');

    await signOut(alice.id);

    expect(fakes.secureStore.values, isEmpty);
    expect((await fakes.registry.load()).accounts, isEmpty);
    expect(await fakes.registry.accountsToDelete(), [alice.id]);

    wipeAccountData = (accountId) async => wiped.add(accountId);
    expect(await deletions.finishAll(), isTrue);

    expect(wiped, [alice.id]);
    expect(await fakes.registry.accountsToDelete(), isEmpty);
  });

  test('a wiped account is no longer listed to delete', () async {
    final alice = await fakes.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
    );

    await signOut(alice.id);

    expect(wiped, [alice.id]);
    expect(await fakes.registry.accountsToDelete(), isEmpty);
  });

  group('the next start', () {
    test('deletes the data of an account whose sign-out stopped after the '
        'registry forgot it', () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final bob = await fakes.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      // The app died right after this write.
      await fakes.registry.remove(alice.id);

      expect(await deletions.finishAll(), isTrue);

      expect(wiped, [alice.id]);
      expect(await fakes.registry.accountsToDelete(), isEmpty);
      expect((await fakes.registry.load()).accounts.map((e) => e.id), [bob.id]);
    });

    test('keeps an account listed while its wipe keeps failing, and tries '
        'the others', () async {
      for (final id in ['a1', 'b2']) {
        await fakes.registry.remove(id);
      }
      wipeAccountData = (accountId) async {
        if (accountId == 'a1') throw StateError('disk');
        wiped.add(accountId);
      };

      expect(await deletions.finishAll(), isFalse);

      expect(wiped, ['b2']);
      expect(await fakes.registry.accountsToDelete(), ['a1']);
    });

    group('leaves alone an account signed in again since the start read '
        "the list: its files and notifications are the new session's", () {
      late RegisteredAccount alice;
      late List<String> cancelled;
      late Future<void> Function(String accountId) onCancel;

      setUp(() async {
        alice = await fakes.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: now),
        );
        cancelled = [];
        onCancel = (_) async {};
        deletions = AccountDeletions(
          registry: fakes.registry,
          wipe: (accountId) => wipeAccountData(accountId),
          cancelScheduled: (accountId) async {
            cancelled.add(accountId);
            await onCancel(accountId);
          },
        );
      });

      test('while its notifications were cancelled', () async {
        await fakes.registry.remove(alice.id);
        onCancel = (_) => fakes.registry.upsert(alice);

        expect(await deletions.finishAll(), isTrue);

        expect(wiped, isEmpty);
        expect(await fakes.registry.find(alice.id), isNotNull);
      });

      test('while another account was wiped', () async {
        await fakes.registry.remove('a1');
        await fakes.registry.remove(alice.id);
        wipeAccountData = (accountId) async {
          wiped.add(accountId);
          await fakes.registry.upsert(alice);
        };

        expect(await deletions.finishAll(), isTrue);

        expect(cancelled, ['a1']);
        expect(wiped, ['a1']);
        expect(await fakes.registry.accountsToDelete(), isEmpty);
      });
    });

    test('runs one wipe per account at a time', () async {
      await fakes.registry.remove('a1');
      final wiping = Completer<void>();
      var wipes = 0;
      wipeAccountData = (_) async {
        wipes++;
        await wiping.future;
      };

      final first = deletions.finish('a1');
      final second = deletions.finish('a1');
      await pumpEventQueue();
      wiping.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(wipes, 1);
    });

    group('a sign-in of the account waits before it registers it', () {
      late FakeAccountDatabaseFiles files;
      late Map<String, Completer<void>> held;

      setUp(() {
        addTearDown(forgetSignOutLeftovers);
        files = FakeAccountDatabaseFiles();
        held = {};
        wipeAccountData = (accountId) async {
          wiped.add(accountId);
          await (held[accountId] ??= Completer<void>()).future;
        };
      });

      Future<bool> settledSoon(String accountId) =>
          settleSignedOutDatabases(files, accountId: accountId)
              .then((_) => true)
              .timeout(
                const Duration(milliseconds: 50),
                onTimeout: () => false,
              );

      test('for the wipe under way', () async {
        await fakes.registry.remove('a1');
        final finishing = deletions.finish('a1');
        final settling = settleSignedOutDatabases(files, accountId: 'a1');
        await pumpEventQueue();

        expect(await settledSoon('a1'), isFalse);
        expect(await settledSoon('b2'), isTrue);

        held['a1']!.complete();
        await settling;
        expect(await finishing, isTrue);
        expect(await settledSoon('a1'), isTrue);
      });

      test("for its turn at the start, while another account's wipe is "
          'under way', () async {
        for (final id in ['a1', 'b2']) {
          await fakes.registry.remove(id);
        }
        final finishing = deletions.finishAll();
        await pumpEventQueue();
        expect(wiped, ['a1']);

        expect(await settledSoon('b2'), isFalse);

        held['a1']!.complete();
        await pumpEventQueue();
        expect(wiped, ['a1', 'b2']);
        expect(await settledSoon('b2'), isFalse);

        held['b2']!.complete();
        expect(await finishing, isTrue);
        expect(await settledSoon('b2'), isTrue);
      });
    });
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

  for (final retry in [false, true]) {
    test(
      'sign-out cannot interleave with a sibling refresh '
      '${retry ? 'retrying a kept write' : 'committing new tokens'}',
      () async {
        final alice = await fakes.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: now, lifetime: Duration.zero),
          needsReauth: true,
        );
        final fresh = issueTokens(issuedAt: now);
        final sibling = SessionManager(
          accountId: alice.id,
          tokenStore: TokenStore(fakes.secureStore),
          refresh: (_) async => fresh,
          onSessionEnded: (_) async {},
          clockOffsets: fakes.clockOffsets,
          clock: () => now,
        );
        if (retry) {
          fakes.secureStore.beforeWrite = (_) async =>
              throw StateError('temporarily locked');
          expect(await sibling.validAccessToken(), fresh.accessToken);
        }
        final writing = Completer<void>();
        final release = Completer<void>();
        fakes.secureStore.beforeWrite = (key) async {
          if (key != TokenStore.refreshTokenKey(alice.id)) return;
          writing.complete();
          await release.future;
        };
        final request = sibling.validAccessToken();
        await writing.future;

        final signingOut = signOut(alice.id);
        await pumpEventQueue();
        final stillRegistered = await fakes.registry.find(alice.id);
        release.complete();
        await signingOut;

        expect(stillRegistered, isNotNull);
        expect(await request, fresh.accessToken);
        expect(await fakes.registry.find(alice.id), isNull);
        expect(fakes.secureStore.values, isEmpty);
        expect(await fakes.clockOffsets.read(alice.id), isNull);
      },
    );
  }

  test('sign-out does not wait for a sibling on the network or let its '
      'response replace a subsequent sign-in', () async {
    final connection = fullServer270();
    final alice = await fakes.seedAccount(
      connection,
      tokens: issueTokens(issuedAt: now, lifetime: Duration.zero),
      needsReauth: true,
    );
    final sent = Completer<void>();
    final response = Completer<TokenSet>();
    final sibling = SessionManager(
      accountId: alice.id,
      tokenStore: TokenStore(fakes.secureStore),
      refresh: (_) {
        sent.complete();
        return response.future;
      },
      onSessionEnded: (_) async {},
      clock: () => now,
    );
    final request = sibling.validAccessToken();
    await sent.future;
    await signOut(alice.id);
    final signedIn = issueTokens(issuedAt: now, sessionId: 'new-sign-in');
    await fakes.seedAccount(connection, tokens: signedIn);
    response.complete(issueTokens(issuedAt: now));

    expect(await request, signedIn.accessToken);
    expect(
      (await fakes.tokenStore.read(alice.id))?.refreshToken,
      signedIn.refreshToken,
    );
  });

  group('a sign-out that fails after the session was retired', () {
    test('keeps the account, marked to sign in again', () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      fakes.secureStore.beforeDelete = (_) async =>
          throw StateError('Keychain locked');

      await expectLater(signOut(alice.id), throwsA(isA<StateError>()));

      final kept = (await fakes.registry.find(alice.id))!;
      expect(kept.account.needsReauth, isTrue);
      expect(wiped, isEmpty);
    });

    test('records the end on this device before the mark, for the banner '
        '(decision log: Several accounts)', () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      fakes.secureStore.beforeDelete = (_) async =>
          throw StateError('Keychain locked');
      bool? recordedAtMark;
      final changes = fakes.registry.changes.listen((state) {
        if (state.find(alice.id)?.account.needsReauth ?? false) {
          recordedAtMark ??= fakes.preferences.values.containsKey(
            SessionDiagnostics.endKey(alice.id),
          );
        }
      });
      addTearDown(changes.cancel);

      await expectLater(signOut(alice.id), throwsA(isA<StateError>()));
      await pumpEventQueue();

      expect(recordedAtMark, isTrue);
      final ended = (await diagnostics.lastEnd(alice.id))!;
      expect(ended.cause, SessionEndCause.signOutFailed);
      expect(ended.part, AppPart.app);
      expect(ended.at, now);
      expect(ended.resolution, isNull);
      expect(await diagnostics.endedOnDevice(alice.id), isTrue);
    });

    test('keeps the account marked through a session check after an earlier '
        'restore', () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      await diagnostics.recordEnd(
        alice.id,
        SessionEndDiagnosis(
          at: now.subtract(const Duration(days: 1)),
          cause: SessionEndCause.refreshRejected,
          part: AppPart.app,
          failedToken: tokenFingerprint('refresh-that-failed'),
          resolution: SessionEndResolution.restored,
        ),
      );
      fakes.secureStore.beforeDelete = (_) async =>
          throw StateError('Keychain locked');
      await expectLater(signOut(alice.id), throwsA(isA<StateError>()));

      expect(await sessions.tryRestore(alice.id), isFalse);

      final kept = (await fakes.registry.find(alice.id))!;
      expect(kept.account.needsReauth, isTrue);
      await expectLater(
        sessions.forAccount(alice.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(fakes.tokenGateway.refreshedTokens, isEmpty);
    });

    test('keeps a guest marked when its link reads again after storage had '
        'refused it', () async {
      final guest = await fakes.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: now),
        needsReauth: true,
      );
      await diagnostics.recordEnd(
        guest.id,
        SessionEndDiagnosis(
          at: now.subtract(const Duration(days: 1)),
          cause: SessionEndCause.storageUnreadable,
          part: AppPart.app,
        ),
      );
      var deletes = 0;
      fakes.secureStore.beforeDelete = (_) async {
        if (++deletes == 1) throw StateError('Keychain locked');
      };
      await expectLater(signOut(guest.id), throwsA(isA<StateError>()));

      expect(await linkShares.tryRestore(guest.id), isFalse);

      final kept = (await fakes.registry.find(guest.id))!;
      expect(kept.account.needsReauth, isTrue);
      expect(await fakes.linkShareStore.read(guest.id), isNotNull);
    });

    test('passes its own failure on when the mark cannot be stored '
        'either', () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now),
      );
      final preferences = _FailingWrites(fakes.preferences);
      final failingRegistry = AccountRegistry(preferences);
      final failing = SignOut(
        registry: failingRegistry,
        tokenStore: fakes.tokenStore,
        linkShareStore: fakes.linkShareStore,
        clockOffsets: fakes.clockOffsets,
        sessions: sessions,
        linkShares: linkShares,
        accountGateway: fakes.accountGateway,
        deletions: deletions,
        logoutTimeout: const Duration(milliseconds: 50),
      );
      preferences.failing = true;

      await expectLater(
        failing(alice.id),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'write 1'),
        ),
      );

      expect(preferences.failures, 2);
      expect(await fakes.registry.find(alice.id), isNotNull);
    });
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

  group('guests', () {
    test(
      'skip the server and delete their hash and token, nothing else',
      () async {
        final alice = await fakes.seedAccount(
          fullServer270(),
          tokens: issueTokens(issuedAt: now),
        );
        final guest = await fakes.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now),
        );

        await signOut(guest.id);

        expect(fakes.accountGateway.logoutTokens, isEmpty);
        expect(await fakes.linkShareStore.read(guest.id), isNull);
        expect(await fakes.tokenStore.read(alice.id), isNotNull);
        expect(
          fakes.secureStore.values.keys,
          everyElement(startsWith('account.${alice.id}.')),
        );
        expect((await fakes.registry.load()).accounts.map((e) => e.id), [
          alice.id,
        ]);
        expect(wiped, [guest.id]);
      },
    );

    test('a renewal in flight writes no token back', () async {
      final old = issueLinkShareToken(
        issuedAt: now.subtract(const Duration(hours: 40)),
      );
      final guest = await fakes.seedGuest(fullServer270(), token: old);
      final renewal = Completer<LinkShareToken>();
      fakes.linkShareGateway.onRenew = (_) => renewal.future;
      final request = linkShares.forAccount(guest.id).validAccessToken();
      await pumpEventQueue();

      await signOut(guest.id);
      renewal.complete(issueLinkShareToken(issuedAt: now));
      await expectLater(request, throwsA(isA<SessionEnded>()));
      await pumpEventQueue();

      expect(fakes.linkShareGateway.renewedTokens, [old.jwt]);
      expect(fakes.secureStore.values, isEmpty);
    });
  });
  test(
    'a sibling refresh finishing during deletion finds no old token',
    () async {
      final alice = await fakes.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, lifetime: Duration.zero),
        needsReauth: true,
      );
      final response = Completer<TokenSet>();
      final sent = Completer<void>();
      final sibling = SessionManager(
        accountId: alice.id,
        tokenStore: TokenStore(fakes.secureStore),
        refresh: (_) {
          sent.complete();
          return response.future;
        },
        onSessionEnded: (_) async {},
        clock: () => now,
      );
      final request = expectLater(
        sibling.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await sent.future;
      final deleting = Completer<void>();
      final release = Completer<void>();
      fakes.secureStore.beforeDelete = (key) async {
        if (key != TokenStore.refreshTokenKey(alice.id)) return;
        deleting.complete();
        await release.future;
      };
      fakes.secureStore.operations.clear();
      final signingOut = signOut(alice.id);
      await deleting.future;
      response.complete(issueTokens(issuedAt: now));
      await pumpEventQueue();
      release.complete();
      await signingOut;
      await request;

      expect(fakes.secureStore.values, isEmpty);
      expect(
        fakes.secureStore.operations,
        isNot(contains(startsWith('write'))),
      );
    },
  );
}

/// Writes fail while [failing] is set, each with its number.
final class _FailingWrites implements PreferencesStore {
  new(this._inner);

  final PreferencesStore _inner;
  bool failing = false;
  int failures = 0;

  @override
  Future<String?> getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    if (failing) throw StateError('write ${++failures}');
    await _inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _inner.remove(key);
}
