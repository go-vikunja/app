import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../../helpers/auth_fakes.dart';
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
}
