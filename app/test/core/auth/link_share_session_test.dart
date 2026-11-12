import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  late DateTime now;
  late AuthFakes fakes;
  late FakeLinkShareGateway gateway;

  setUp(() {
    now = DateTime.utc(2026, 10, 26, 12);
    fakes = AuthFakes();
    gateway = fakes.linkShareGateway;
  });

  LinkShareSessions sessions({int? maxAuthentications}) => LinkShareSessions(
    store: fakes.linkShareStore,
    gateway: gateway,
    connectionFor: (id) async => (await fakes.registry.find(id))?.connection,
    markNeedsReauth: fakes.registry.markNeedsReauth,
    clock: () => now,
    maxAuthentications: maxAuthentications,
  );

  LinkShareToken issuedAgo(Duration age, {int shareId = 84}) =>
      issueLinkShareToken(issuedAt: now.subtract(age), shareId: shareId);

  Future<RegisteredAccount> seed(LinkShareToken? token) =>
      fakes.seedGuest(fullServer270(), token: token);

  Future<String?> storedToken(String accountId) async =>
      (await fakes.linkShareStore.read(accountId))?.token;

  Future<bool> needsReauth(String accountId) async =>
      (await fakes.registry.find(accountId))!.account.needsReauth;

  group('a valid token', () {
    test('is handed out without a request until half its lifetime has '
        'passed', () async {
      final token = issuedAgo(const Duration(hours: 35));
      final guest = await seed(token);

      final handedOut = await sessions()
          .forAccount(guest.id)
          .validAccessToken();

      expect(handedOut, token.jwt);
      expect(gateway.renewedTokens, isEmpty);
      expect(gateway.authentications, isEmpty);
    });

    test('is renewed past half its lifetime, and the new one stored', () async {
      final old = issuedAgo(const Duration(hours: 37));
      final guest = await seed(old);
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.onRenew = (_) async => fresh;

      final handedOut = await sessions()
          .forAccount(guest.id)
          .validAccessToken();

      expect(handedOut, fresh.jwt);
      expect(gateway.renewedTokens, [old.jwt]);
      expect(await storedToken(guest.id), fresh.jwt);
      expect(gateway.connections.single.rootUri, fullServer270().rootUri);
    });

    test('is renewed once for calls at the same time', () async {
      final old = issuedAgo(const Duration(hours: 40));
      final guest = await seed(old);
      final fresh = issueLinkShareToken(issuedAt: now);
      final answer = Completer<LinkShareToken>();
      gateway.onRenew = (_) => answer.future;
      final session = sessions().forAccount(guest.id);

      final calls = [for (var i = 0; i < 3; i++) session.validAccessToken()];
      await pumpEventQueue();
      answer.complete(fresh);

      expect(await Future.wait(calls), everyElement(fresh.jwt));
      expect(gateway.renewedTokens, hasLength(1));
    });

    test('stays in use while a renewal fails, which is tried again only '
        'after a pause', () async {
      final old = issuedAgo(const Duration(hours: 40));
      final guest = await seed(old);
      gateway.onRenew = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final session = sessions().forAccount(guest.id);

      expect(await session.validAccessToken(), old.jwt);
      expect(await session.validAccessToken(), old.jwt);
      expect(gateway.renewedTokens, hasLength(1));

      now = now.add(LinkShareSession.renewalBackoff);
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.onRenew = (_) async => fresh;

      expect(await session.validAccessToken(), fresh.jwt);
      expect(gateway.renewedTokens, hasLength(2));
      expect(await needsReauth(guest.id), isFalse);
    });

    test(
      'takes a fresher token another isolate stored instead of renewing',
      () async {
        final guest = await seed(issuedAgo(const Duration(hours: 35)));
        final session = sessions().forAccount(guest.id);
        await session.validAccessToken();
        now = now.add(const Duration(hours: 2));
        final elsewhere = issueLinkShareToken(issuedAt: now);
        // Renewed by the background run meanwhile.
        await fakes.linkShareStore.writeToken(guest.id, elsewhere.jwt);

        expect(await session.validAccessToken(), elsewhere.jwt);
        expect(gateway.renewedTokens, isEmpty);
      },
    );

    test('is not renewed again because the device clock runs ahead', () async {
      final guest = await seed(null);
      // The server's clock is 50 h behind this device's.
      gateway.serve(
        issueLinkShareToken(issuedAt: now.subtract(const Duration(hours: 50))),
      );
      final session = sessions().forAccount(guest.id);
      final first = await session.validAccessToken();

      now = now.add(const Duration(hours: 1));

      expect(await session.validAccessToken(), first);
      expect(gateway.renewedTokens, isEmpty);
      expect(gateway.authentications, hasLength(1));
    });
  });

  group('an expired token', () {
    test('is replaced by authenticating with the stored hash', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 73)));
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.serve(fresh);

      final handedOut = await sessions()
          .forAccount(guest.id)
          .validAccessToken();

      expect(handedOut, fresh.jwt);
      expect(gateway.authentications, [(fakeShareHash, null)]);
      expect(gateway.renewedTokens, isEmpty);
      expect(await storedToken(guest.id), fresh.jwt);
    });

    test('so is a missing one, with only the hash stored', () async {
      final guest = await seed(null);
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.serve(fresh);

      expect(
        await sessions().forAccount(guest.id).validAccessToken(),
        fresh.jwt,
      );
    });

    test('of a share with a password ends the session, without asking the '
        'server again', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      gateway.serve(issueLinkShareToken(issuedAt: now), password: 'secret');
      final session = sessions().forAccount(guest.id);

      await expectLater(
        session.validAccessToken(),
        throwsA(
          isA<SessionEnded>()
              .having((failure) => failure.code, 'code', 13001)
              .having((f) => f, 'not gone', isNot(isA<LinkShareGone>())),
        ),
      );
      expect(await needsReauth(guest.id), isTrue);

      await expectLater(
        session.validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect(gateway.authentications, hasLength(1));
    });

    test('of a share that is gone ends the session as gone', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      gateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone(code: 3006);

      await expectLater(
        sessions().forAccount(guest.id).validAccessToken(),
        throwsA(isA<LinkShareGone>()),
      );
      expect(await needsReauth(guest.id), isTrue);
    });

    test('waits out a 429 before authenticating again', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      gateway.onAuthenticate = (_, _) async =>
          throw const RateLimited(retryAfter: Duration(seconds: 15));
      final session = sessions().forAccount(guest.id);

      await expectLater(
        session.validAccessToken(),
        throwsA(isA<RateLimited>()),
      );
      await expectLater(
        session.validAccessToken(),
        throwsA(
          isA<RateLimited>().having(
            (failure) => failure.retryAfter,
            'retryAfter',
            const Duration(seconds: 15),
          ),
        ),
      );
      expect(gateway.authentications, hasLength(1));

      now = now.add(const Duration(seconds: 15));
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.serve(fresh);

      expect(await session.validAccessToken(), fresh.jwt);
      expect(await needsReauth(guest.id), isFalse);
    });

    test('is authenticated again at most once in a headless run', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      gateway.onAuthenticate = (_, _) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      final session = sessions(maxAuthentications: 1).forAccount(guest.id);

      await expectLater(
        session.validAccessToken(),
        throwsA(isA<NetworkFailure>()),
      );
      await expectLater(
        session.validAccessToken(),
        throwsA(isA<TokenRejected>()),
      );
      expect(gateway.authentications, hasLength(1));
      expect(await needsReauth(guest.id), isFalse);
    });

    test('takes a token another isolate authenticated meanwhile', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      final elsewhere = issueLinkShareToken(issuedAt: now);
      await fakes.linkShareStore.writeToken(guest.id, elsewhere.jwt);
      final session = LinkShareSessions(
        store: fakes.linkShareStore,
        gateway: gateway,
        connectionFor: (id) async =>
            (await fakes.registry.find(id))?.connection,
        markNeedsReauth: fakes.registry.markNeedsReauth,
        clock: () => now,
      ).forAccount(guest.id);

      expect(await session.validAccessToken(), elsewhere.jwt);
      expect(gateway.authentications, isEmpty);
    });
  });

  group('a rejected token (401 code 11)', () {
    test('is replaced by authenticating again, not by a renewal', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.serve(fresh);
      final session = sessions().forAccount(guest.id);
      await session.validAccessToken();

      expect(await session.refreshAfterRejection(token.jwt), fresh.jwt);
      expect(gateway.renewedTokens, isEmpty);
      expect(gateway.authentications, hasLength(1));
    });

    test('gives way to a newer token at hand', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      final session = sessions().forAccount(guest.id);
      await session.validAccessToken();
      final elsewhere = issueLinkShareToken(issuedAt: now);
      await fakes.linkShareStore.writeToken(guest.id, elsewhere.jwt);

      expect(await session.refreshAfterRejection(token.jwt), elsewhere.jwt);
      expect(await session.refreshAfterRejection('older'), elsewhere.jwt);
      expect(gateway.authentications, isEmpty);
    });
  });

  group('a share gone', () {
    test('on a renewal ends the session', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 40)));
      gateway.onRenew = (_) async => throw const LinkShareGone();

      await expectLater(
        sessions().forAccount(guest.id).validAccessToken(),
        throwsA(isA<LinkShareGone>()),
      );
      expect(await needsReauth(guest.id), isTrue);
      expect(await fakes.linkShareStore.read(guest.id), isNotNull);
    });

    test('on any request ends the session', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 1)));
      final session = sessions().forAccount(guest.id)
        ..noteGone(const LinkShareGone(code: 13003));
      await pumpEventQueue();

      expect(await needsReauth(guest.id), isTrue);
      await expectLater(
        session.validAccessToken(),
        throwsA(isA<LinkShareGone>()),
      );
      expect(gateway.authentications, isEmpty);
    });

    test('is handed on with its reason once the guest is flagged', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 40)));
      gateway.onRenew = (_) async => throw const LinkShareGone(code: 13003);
      final handed = <(String, SessionEnded, bool)>[];
      final reporting = LinkShareSessions(
        store: fakes.linkShareStore,
        gateway: gateway,
        connectionFor: (id) async =>
            (await fakes.registry.find(id))?.connection,
        markNeedsReauth: fakes.registry.markNeedsReauth,
        onSessionEnded: (accountId, failure) async =>
            handed.add((accountId, failure, await needsReauth(accountId))),
        clock: () => now,
      );

      await expectLater(
        reporting.forAccount(guest.id).validAccessToken(),
        throwsA(isA<LinkShareGone>()),
      );

      final (accountId, failure, flaggedFirst) = handed.single;
      expect(accountId, guest.id);
      expect(failure.reason, SessionEndReason.linkShareGone);
      expect(flaggedFirst, isTrue);
    });
  });

  test('lost secrets end the session', () async {
    final guest = await seed(issuedAgo(const Duration(hours: 1)));
    await fakes.linkShareStore.delete(guest.id);

    await expectLater(
      sessions().forAccount(guest.id).validAccessToken(),
      throwsA(isA<SessionEnded>()),
    );
    expect(await needsReauth(guest.id), isTrue);
  });

  test('a new sign-in replaces a session that ended', () async {
    final guest = await seed(issuedAgo(const Duration(hours: 1)));
    final all = sessions();
    all.forAccount(guest.id).noteGone(const LinkShareGone());
    await pumpEventQueue();
    final fresh = issueLinkShareToken(issuedAt: now);
    await fakes.linkShareStore.write(
      guest.id,
      hash: fakeShareHash,
      token: fresh.jwt,
    );

    final session = all.signedIn(guest.id, fresh, receivedAt: now);

    expect(all.forAccount(guest.id), same(session));
    expect(await session.validAccessToken(), fresh.jwt);
  });

  test('a token renewed while another isolate signs the guest out is taken '
      'back', () async {
    final guest = await seed(issuedAgo(const Duration(hours: 37)));
    final fresh = issueLinkShareToken(issuedAt: now);
    gateway.onRenew = (_) async => fresh;
    fakes.secureStore.beforeWrite = (key) async {
      // The sign-out lands between the check for the hash and the write.
      if (key == LinkShareStore.tokenKey(guest.id)) {
        await fakes.linkShareStore.delete(guest.id);
      }
    };

    final handedOut = await sessions().forAccount(guest.id).validAccessToken();

    expect(handedOut, fresh.jwt);
    expect(
      fakes.secureStore.values.keys,
      isNot(anyElement(contains(guest.id))),
    );
  });

  test('a retired session hands out nothing and writes nothing', () async {
    final guest = await seed(issuedAgo(const Duration(hours: 80)));
    fakes.secureStore.operations.clear();
    final answer = Completer<LinkShareAuth>();
    gateway.onAuthenticate = (_, _) => answer.future;
    final all = sessions();
    final request = all.forAccount(guest.id).validAccessToken();
    await pumpEventQueue();

    await all.retire(guest.id);
    answer.complete(linkShareAuthFor(issueLinkShareToken(issuedAt: now)));

    await expectLater(request, throwsA(isA<SessionEnded>()));
    expect(
      fakes.secureStore.operations,
      isNot(contains('write ${LinkShareStore.tokenKey(guest.id)}')),
    );
    await expectLater(
      all.forAccount(guest.id).validAccessToken(),
      throwsA(isA<SessionEnded>()),
    );
  });
}
