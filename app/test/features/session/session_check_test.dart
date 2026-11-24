import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');

void main() {
  late DateTime now;
  late AuthFakes auth;
  late SessionCheck check;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    auth = AuthFakes()..serveUser(_alice, now: now);
    final sessions = SessionManagers(
      tokenStore: auth.tokenStore,
      clockOffsets: auth.clockOffsets,
      tokenGateway: auth.tokenGateway,
      connectionFor: (id) async => (await auth.registry.find(id))?.connection,
      markNeedsReauth: auth.registry.markNeedsReauth,
      clock: () => now,
      sleep: (_) async {},
    );
    check = SessionCheck(
      sessions: sessions,
      linkShares: LinkShareSessions(
        store: auth.linkShareStore,
        gateway: auth.linkShareGateway,
        connectionFor: (id) async => (await auth.registry.find(id))?.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        clock: () => now,
      ),
      accountGateway: auth.accountGateway,
      clock: () => now,
    );
  });

  Future<RegisteredAccount> seed({
    Duration age = Duration.zero,
    bool needsReauth = false,
  }) => auth.seedAccount(
    fullServer270(),
    tokens: issueTokens(issuedAt: now.subtract(age)),
    needsReauth: needsReauth,
  );

  test('asks the server with the account session', () async {
    final entry = await seed();

    await check.check(entry);

    expect(auth.accountGateway.currentUserTokens, hasLength(1));
  });

  test(
    'refreshes an expired access token, keeping the session alive',
    () async {
      final entry = await seed(age: const Duration(hours: 5));
      final fresh = issueTokens(issuedAt: now);
      auth.tokenGateway.onRefresh = (_) async => fresh;

      await check.check(entry);

      expect(auth.accountGateway.currentUserTokens, [fresh.accessToken]);
      expect(
        (await auth.tokenStore.read(entry.id))?.refreshToken,
        fresh.refreshToken,
      );
    },
  );

  test('a session the server ended marks the account', () async {
    final entry = await seed(age: const Duration(days: 3));
    auth.tokenGateway.onRefresh = (_) async =>
        throw const SessionEnded(SessionEndReason.expired, code: 16003);

    await check.check(entry);

    expect((await auth.registry.find(entry.id))!.account.needsReauth, isTrue);
  });

  test('swallows other failures', () async {
    final entry = await seed();
    auth.accountGateway.onCurrentUser = (_) async =>
        throw const NetworkFailure(NetworkProblem.timeout);

    await check.check(entry);

    expect((await auth.registry.find(entry.id))!.account.needsReauth, isFalse);
  });

  test('skips an account that already needs a new sign-in', () async {
    final entry = await seed(needsReauth: true);

    await check.check(entry);

    expect(auth.accountGateway.currentUserTokens, isEmpty);
  });

  test('runs one check per account at a time', () async {
    final entry = await seed();
    final response = Completer<User>();
    auth.accountGateway.onCurrentUser = (_) => response.future;

    final first = check.check(entry);
    final second = check.check(entry);
    await pumpEventQueue();
    response.complete(_alice);
    await Future.wait([first, second]);

    expect(auth.accountGateway.currentUserTokens, hasLength(1));
  });

  test('waits a minute before checking the same account again', () async {
    final entry = await seed();
    await check.check(entry);

    now = now.add(const Duration(seconds: 59));
    await check.check(entry);
    expect(auth.accountGateway.currentUserTokens, hasLength(1));

    now = now.add(const Duration(seconds: 1));
    await check.check(entry);
    expect(auth.accountGateway.currentUserTokens, hasLength(2));
  });

  test('a session just confirmed by a sign-in is not checked again', () async {
    final entry = await seed();

    check.noteVerified(entry.id);
    await check.check(entry);

    expect(auth.accountGateway.currentUserTokens, isEmpty);
  });

  group("after the web's password page", () {
    test(
      'the next check rotates a valid token at once, and only that one',
      () async {
        final entry = await seed();
        await check.check(entry);
        final fresh = issueTokens(issuedAt: now);
        auth.tokenGateway.onRefresh = (_) async => fresh;

        check.refreshOnNextCheck(entry.id);
        now = now.add(const Duration(seconds: 5));
        await check.check(entry);
        now = now.add(const Duration(minutes: 2));
        await check.check(entry);

        expect(auth.tokenGateway.refreshedTokens, hasLength(1));
        expect(auth.accountGateway.currentUserTokens, [
          isNot(fresh.accessToken),
          fresh.accessToken,
          fresh.accessToken,
        ]);
      },
    );

    test(
      'a changed password, which ended the session, marks the account',
      () async {
        final entry = await seed();
        auth.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
          SessionEndReason.invalidRefreshToken,
          code: 16002,
        );

        check.refreshOnNextCheck(entry.id);
        await check.check(entry);

        expect(
          (await auth.registry.find(entry.id))!.account.needsReauth,
          isTrue,
        );
        expect(auth.accountGateway.currentUserTokens, isEmpty);
      },
    );

    test('a refresh that cannot reach the server is swallowed', () async {
      final entry = await seed();
      auth.tokenGateway.onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      check.refreshOnNextCheck(entry.id);
      await check.check(entry);

      expect(
        (await auth.registry.find(entry.id))!.account.needsReauth,
        isFalse,
      );
    });
  });

  group('a deleted account', () {
    test('asks for a new sign-in at once, while its access token still '
        'works', () async {
      final entry = await seed();
      auth.accountGateway.onCurrentUser = (_) async =>
          throw const NotFound(code: 1005);
      auth.tokenGateway.onRefresh = (_) async => throw const SessionEnded(
        SessionEndReason.invalidRefreshToken,
        code: 16002,
      );

      await check.check(entry);

      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      expect((await auth.registry.find(entry.id))!.account.needsReauth, isTrue);
      now = now.add(const Duration(minutes: 5));
      await check.check((await auth.registry.find(entry.id))!);
      expect(auth.accountGateway.currentUserTokens, hasLength(1));
    });

    test('another missing thing does not refresh', () async {
      final entry = await seed();
      auth.accountGateway.onCurrentUser = (_) async => throw const NotFound();

      await check.check(entry);

      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(
        (await auth.registry.find(entry.id))!.account.needsReauth,
        isFalse,
      );
    });
  });

  group('a guest', () {
    const pseudoUser = User(
      id: -84,
      username: 'link-share-84',
      name: 'Link Share',
    );

    Future<bool> needsReauth(String accountId) async =>
        (await auth.registry.find(accountId))!.account.needsReauth;

    test('renews its token when due and reads its pseudo user, never through '
        'a session manager', () async {
      final old = issueLinkShareToken(
        issuedAt: now.subtract(const Duration(hours: 40)),
      );
      final guest = await auth.seedGuest(fullServer270(), token: old);
      final fresh = issueLinkShareToken(issuedAt: now);
      auth.linkShareGateway.onRenew = (_) async => fresh;
      auth.accountGateway.onCurrentUser = (_) async => pseudoUser;

      await check.check(guest);

      expect(auth.linkShareGateway.renewedTokens, [old.jwt]);
      expect(auth.accountGateway.currentUserTokens, [fresh.jwt]);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(await needsReauth(guest.id), isFalse);
    });

    for (final (version, failure) in [
      ('v1', const LinkShareGone(code: 13003) as VikunjaFailure),
      ('v2', const LinkShareGone()),
    ]) {
      test('whose share is gone ($version) needs the link again', () async {
        final guest = await auth.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now),
        );
        auth.accountGateway.onCurrentUser = (_) async => throw failure;

        await check.check(guest);
        await pumpEventQueue();

        expect(await needsReauth(guest.id), isTrue);
      });
    }

    for (final (what, renewal, ends) in [
      ('is gone', const LinkShareGone(code: 3006) as VikunjaFailure?, true),
      ('is still there', null, false),
    ]) {
      test('on 2.3, whose share $what, answers its pseudo user with a 500, '
          'and a renewal tells whether the share is gone', () async {
        final token = issueLinkShareToken(issuedAt: now);
        final guest = await auth.seedGuest(oauthServer230(), token: token);
        auth.accountGateway.onCurrentUser = (_) async =>
            throw const ServerFailure(500);
        auth.linkShareGateway.onRenew = (_) async => switch (renewal) {
          final failure? => throw failure,
          null => issueLinkShareToken(issuedAt: now),
        };

        await check.check(guest);
        await pumpEventQueue();

        expect(auth.linkShareGateway.renewedTokens, [token.jwt]);
        expect(await needsReauth(guest.id), ends);
      });
    }

    test('from 2.7 a 500 to its pseudo user asks nothing more', () async {
      final guest = await auth.seedGuest(
        v1OnlyServer270(),
        token: issueLinkShareToken(issuedAt: now),
      );
      auth.accountGateway.onCurrentUser = (_) async =>
          throw const ServerFailure(500);

      await check.check(guest);
      await pumpEventQueue();

      expect(auth.linkShareGateway.renewedTokens, isEmpty);
      expect(await needsReauth(guest.id), isFalse);
    });

    test(
      'is not ended by a refusal that is about the guest being no user',
      () async {
        final guest = await auth.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now),
        );
        auth.accountGateway.onCurrentUser = (_) async =>
            throw const DomainError(401, code: 1027);

        await check.check(guest);
        await pumpEventQueue();

        expect(await needsReauth(guest.id), isFalse);
      },
    );

    test(
      'is not ended by a 401 from something in front of the server',
      () async {
        final guest = await auth.seedGuest(
          fullServer270(),
          token: issueLinkShareToken(issuedAt: now),
        );
        auth.accountGateway.onCurrentUser = (_) async =>
            throw const UnexpectedResponse(401);

        await check.check(guest);
        await pumpEventQueue();

        expect(await needsReauth(guest.id), isFalse);
        expect(auth.linkShareGateway.renewedTokens, isEmpty);
      },
    );
  });

  group('an account waiting for a sign-in (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;
    late SessionCheck restoring;

    setUp(() {
      diagnostics = SessionDiagnostics(auth.preferences);
      final sessions = SessionManagers(
        tokenStore: auth.tokenStore,
        clockOffsets: auth.clockOffsets,
        tokenGateway: auth.tokenGateway,
        connectionFor: (id) async => (await auth.registry.find(id))?.connection,
        markNeedsReauth: auth.registry.markNeedsReauth,
        clearNeedsReauth: auth.registry.clearNeedsReauth,
        diagnostics: diagnostics,
        clock: () => now,
        sleep: (_) async {},
      );
      restoring = SessionCheck(
        sessions: sessions,
        linkShares: LinkShareSessions(
          store: auth.linkShareStore,
          gateway: auth.linkShareGateway,
          connectionFor: (id) async =>
              (await auth.registry.find(id))?.connection,
          markNeedsReauth: auth.registry.markNeedsReauth,
          clearNeedsReauth: auth.registry.clearNeedsReauth,
          diagnostics: diagnostics,
          clock: () => now,
        ),
        accountGateway: auth.accountGateway,
        clock: () => now,
      );
    });

    Future<RegisteredAccount> waiting() async {
      final entry = await seed(needsReauth: true);
      await SessionDiagnostics(auth.preferences).recordEnd(
        entry.id,
        SessionEndDiagnosis(
          at: now,
          cause: SessionEndCause.refreshRejected,
          part: AppPart.backgroundRun,
          failedToken: tokenFingerprint('rotated-away'),
        ),
      );
      return entry;
    }

    test(
      'works again when storage holds newer tokens the server takes',
      () async {
        final entry = await waiting();
        auth.tokenGateway.onRefresh = (_) async => issueTokens(issuedAt: now);

        await restoring.check(entry);

        expect(
          (await auth.registry.find(entry.id))!.account.needsReauth,
          isFalse,
        );
        expect(auth.accountGateway.currentUserTokens, isEmpty);
      },
    );

    test('tries at most once a minute', () async {
      final entry = await waiting();
      auth.tokenGateway.onRefresh = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await restoring.check(entry);
      await restoring.check(entry);
      now = now.add(const Duration(minutes: 1));
      await restoring.check(entry);

      expect(auth.tokenGateway.refreshedTokens, hasLength(2));
      expect((await auth.registry.find(entry.id))!.account.needsReauth, isTrue);
    });

    test('a guest waiting for its link is left alone', () async {
      final guest = await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: now),
      );
      await auth.registry.markNeedsReauth(guest.id);

      await restoring.check((await auth.registry.find(guest.id))!);

      expect(auth.linkShareGateway.renewedTokens, isEmpty);
      expect(auth.accountGateway.currentUserTokens, isEmpty);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
    });

    Future<RegisteredAccount> guestEnded(
      SessionEndCause cause, {
      SessionEndResolution? resolution,
    }) async {
      final guest = await auth.seedGuest(
        fullServer270(),
        token: issueLinkShareToken(issuedAt: now),
        needsReauth: true,
      );
      await diagnostics.recordEnd(
        guest.id,
        SessionEndDiagnosis(
          at: now,
          cause: cause,
          part: AppPart.app,
          resolution: resolution,
        ),
      );
      return guest;
    }

    test('a guest marked only because its storage could not be read works '
        'again once its link reads', () async {
      final guest = await guestEnded(SessionEndCause.storageUnreadable);
      await diagnostics.noteUnreadable(guest.id, now);

      await restoring.check(guest);

      expect(
        (await auth.registry.find(guest.id))!.account.needsReauth,
        isFalse,
      );
      expect(
        (await diagnostics.lastEnd(guest.id))!.resolution,
        SessionEndResolution.restored,
      );
      expect(
        auth.preferences.values,
        isNot(contains(SessionDiagnostics.unreadableSinceKey(guest.id))),
      );
      expect(auth.linkShareGateway.renewedTokens, isEmpty);
      expect(auth.linkShareGateway.authentications, isEmpty);
    });

    for (final (what, cause, resolution) in [
      (
        'was restored before',
        SessionEndCause.storageUnreadable,
        SessionEndResolution.restored,
      ),
      (
        'opened its link again since',
        SessionEndCause.storageUnreadable,
        SessionEndResolution.unknown,
      ),
      ('lost its link', SessionEndCause.missingTokens, null),
      ('lost its share on the server', SessionEndCause.shareGone, null),
      ('was asked for a password', SessionEndCause.sharePasswordNeeded, null),
    ]) {
      test('a guest that $what waits for its link', () async {
        final guest = await guestEnded(cause, resolution: resolution);

        await restoring.check(guest);

        expect(
          (await auth.registry.find(guest.id))!.account.needsReauth,
          isTrue,
        );
      });
    }
  });
}
