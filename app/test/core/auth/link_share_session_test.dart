import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_gateways.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

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

    test('of a share with a remembered password is replaced by '
        'authenticating with it', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      await fakes.linkShareStore.writePassword(guest.id, 'secret');
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.serve(fresh, password: 'secret');

      expect(
        await sessions().forAccount(guest.id).validAccessToken(),
        fresh.jwt,
      );
      expect(gateway.authentications, [(fakeShareHash, 'secret')]);
    });

    test('a remembered password the server refuses is forgotten and the '
        'session ends', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 80)));
      await fakes.linkShareStore.writePassword(guest.id, 'old');
      gateway.serve(issueLinkShareToken(issuedAt: now), password: 'new');

      await expectLater(
        sessions().forAccount(guest.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      expect((await fakes.linkShareStore.read(guest.id))?.password, isNull);
      expect(await needsReauth(guest.id), isTrue);
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

  group("a 500, v1's answer to a gone share's token before 2.7,", () {
    test('is confirmed as gone by a renewal of the token, which ends the '
        'session', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      gateway.onRenew = (_) async => throw const LinkShareGone(code: 3006);
      final session = sessions().forAccount(guest.id);

      final gone = await session.confirmGone(token.jwt);

      expect(gone?.code, 3006);
      expect(gateway.renewedTokens, [token.jwt]);
      expect(await needsReauth(guest.id), isTrue);
      await expectLater(
        session.validAccessToken(),
        throwsA(isA<LinkShareGone>()),
      );
      expect(await session.confirmGone(token.jwt), same(gone));
      expect(gateway.renewedTokens, hasLength(1));
    });

    test('ends nothing while the share is there, keeps the renewed token, '
        'and is asked about again only after a pause', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      final fresh = issueLinkShareToken(issuedAt: now);
      gateway.onRenew = (_) async => fresh;
      final session = sessions().forAccount(guest.id);

      expect(await session.confirmGone(token.jwt), isNull);
      expect(await session.validAccessToken(), fresh.jwt);
      expect(await storedToken(guest.id), fresh.jwt);
      expect(await session.confirmGone(fresh.jwt), isNull);
      expect(gateway.renewedTokens, [token.jwt]);

      now = now.add(LinkShareSession.goneCheckBackoff);
      gateway.onRenew = (_) async => throw const LinkShareGone(code: 3006);

      expect(await session.confirmGone(fresh.jwt), isA<LinkShareGone>());
      expect(await needsReauth(guest.id), isTrue);
    });

    test('is asked about once for requests at the same time', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      final answer = Completer<LinkShareToken>();
      gateway.onRenew = (_) => answer.future;
      final session = sessions().forAccount(guest.id);

      final checks = [
        for (var i = 0; i < 3; i++) session.confirmGone(token.jwt),
      ];
      await pumpEventQueue();
      answer.completeError(const LinkShareGone(code: 3006));

      expect(await Future.wait(checks), everyElement(isA<LinkShareGone>()));
      expect(gateway.renewedTokens, hasLength(1));
    });

    test('stays unconfirmed when the renewal fails otherwise', () async {
      final token = issuedAgo(const Duration(hours: 1));
      final guest = await seed(token);
      final session = sessions().forAccount(guest.id);

      for (final failure in [
        const ServerFailure(500),
        const NetworkFailure(NetworkProblem.unreachable),
      ]) {
        gateway.onRenew = (_) async => throw failure;
        expect(await session.confirmGone(token.jwt), isNull);
        now = now.add(LinkShareSession.goneCheckBackoff);
      }

      expect(gateway.renewedTokens, hasLength(2));
      expect(await needsReauth(guest.id), isFalse);
      expect(await session.validAccessToken(), token.jwt);
    });

    test('is asked about only on a server the app reads over v1 before '
        '2.7', () {
      expect(serverErrorMayMeanShareGone(oauthServer230()), isTrue);
      expect(
        serverErrorMayMeanShareGone(unknownVersionServer(version: 'v2.5.0')),
        isTrue,
      );
      expect(serverErrorMayMeanShareGone(unknownVersionServer()), isTrue);
      expect(serverErrorMayMeanShareGone(v1OnlyServer270()), isFalse);
      expect(serverErrorMayMeanShareGone(insecureServer()), isFalse);
      expect(serverErrorMayMeanShareGone(fullServer270()), isFalse);
    });

    for (final (name, connection, ends) in [
      ('2.3', oauthServer230(), true),
      ('2.7 without v2', v1OnlyServer270(), false),
    ]) {
      test(
        "through the guest's client on $name ${ends ? 'ends' : 'does not '
                  'end'} the session",
        () async {
          final token = issuedAgo(const Duration(hours: 1));
          final guest = await fakes.seedGuest(connection, token: token);
          gateway.onRenew = (_) async => throw const LinkShareGone(code: 3006);
          final all = sessions();
          final dio = createAuthenticatedDio(
            base: Dio()
              ..httpClientAdapter = _CountingAdapter(
                status: 500,
                body: '{"message":"Could not determine the current user."}',
              ),
            connection: connection,
            tokens: all.forAccount(guest.id),
            interceptors: [all.goneInterceptor(guest.id, connection)],
          );

          await expectLater(
            createReadClient(dio: dio, connection: connection).projects.list(),
            throwsA(ends ? isA<LinkShareGone>() : isA<ServerFailure>()),
          );
          expect(gateway.renewedTokens, ends ? [token.jwt] : isEmpty);
          expect(await needsReauth(guest.id), ends);
        },
      );
    }
  });

  group("every end of a guest's session is recorded before the guest is "
      'marked (decision log: Sessions)', () {
    late SessionDiagnostics diagnostics;
    late List<SessionEndDiagnosis?> recordedWhenMarked;

    setUp(() {
      diagnostics = SessionDiagnostics(fakes.preferences);
      recordedWhenMarked = [];
    });

    LinkShareSessions recording() => LinkShareSessions(
      store: fakes.linkShareStore,
      gateway: gateway,
      connectionFor: (id) async => (await fakes.registry.find(id))?.connection,
      markNeedsReauth: (accountId) async {
        recordedWhenMarked.add(await diagnostics.lastEnd(accountId));
        await fakes.registry.markNeedsReauth(accountId);
      },
      clearNeedsReauth: fakes.registry.clearNeedsReauth,
      diagnostics: diagnostics,
      part: AppPart.backgroundRun,
      clock: () => now,
    );

    for (final (what, failure, cause, code) in [
      (
        'a gone share',
        const LinkShareGone(code: 13003),
        SessionEndCause.shareGone,
        13003,
      ),
      (
        'a needed password',
        const DomainError(412, code: 13001),
        SessionEndCause.sharePasswordNeeded,
        13001,
      ),
    ]) {
      test('$what, which no restore takes back', () async {
        final guest = await seed(issuedAgo(const Duration(hours: 80)));
        gateway.onAuthenticate = (_, _) async => throw failure;
        final all = recording();

        await expectLater(
          all.forAccount(guest.id).validAccessToken(),
          throwsA(isA<SessionEnded>()),
        );

        final record = recordedWhenMarked.single!;
        expect(record.cause, cause);
        expect(record.code, code);
        expect(record.part, AppPart.backgroundRun);
        expect(record.at, now);
        expect(record.resolution, isNull);
        expect(await all.tryRestore(guest.id), isFalse);
        expect(await needsReauth(guest.id), isTrue);
      });
    }

    test('a lost link, as no link stored on this device', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 1)));
      await fakes.linkShareStore.delete(guest.id);

      await expectLater(
        recording().forAccount(guest.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );

      expect(recordedWhenMarked.single!.cause, SessionEndCause.missingTokens);
    });
  });

  group('a link that secure storage refuses to read '
      '(decision log: Sessions)', () {
    test('fails a request through the transport as a network failure that '
        'names the storage, without a request, and ends nothing', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 1)));
      fakes.secureStore.beforeRead = (_) async =>
          throw PlatformException(code: 'keystore');
      final adapter = _CountingAdapter();

      await expectLater(
        ApiAccountGateway(
          Dio()..httpClientAdapter = adapter,
          logRequests: false,
        ).currentUser(fullServer270(), sessions().forAccount(guest.id)),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.cause,
            'cause',
            isA<SecureStorageUnreadable>(),
          ),
        ),
      );
      expect(adapter.requests, 0);
      expect(gateway.authentications, isEmpty);
      expect(await needsReauth(guest.id), isFalse);
    });

    test('keeps a token in use while a renewal cannot read it', () async {
      final old = issuedAgo(const Duration(hours: 35));
      final guest = await seed(old);
      final session = sessions().forAccount(guest.id);
      expect(await session.validAccessToken(), old.jwt);
      now = now.add(const Duration(hours: 2));
      fakes.secureStore.beforeRead = (_) async =>
          throw PlatformException(code: 'keystore');

      expect(await session.validAccessToken(), old.jwt);
      expect(gateway.renewedTokens, isEmpty);
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

  group('a session retired while its new token is being written hands it '
      'out no more (decision log: Sessions)', () {
    late Completer<void> writing;

    void holdTokenWrite(String accountId) {
      writing = Completer<void>();
      fakes.secureStore.beforeWrite = (key) async {
        if (key == LinkShareStore.tokenKey(accountId)) await writing.future;
      };
    }

    test('a renewed one', () async {
      final guest = await seed(issuedAgo(const Duration(hours: 37)));
      gateway.onRenew = (_) async => issueLinkShareToken(issuedAt: now);
      holdTokenWrite(guest.id);
      final all = sessions();
      final request = expectLater(
        all.forAccount(guest.id).validAccessToken(),
        throwsA(isA<SessionEnded>()),
      );
      await pumpEventQueue();

      final retiring = all.retire(guest.id);
      writing.complete();
      await retiring;

      await request;
    });

    test('one authenticated after a rejection', () async {
      final old = issuedAgo(const Duration(hours: 1));
      final guest = await seed(old);
      gateway.serve(issueLinkShareToken(issuedAt: now));
      holdTokenWrite(guest.id);
      final all = sessions();
      final refresh = all.forAccount(guest.id).refreshAfterRejection(old.jwt);
      await pumpEventQueue();

      final retiring = all.retire(guest.id);
      writing.complete();
      await retiring;

      expect(await refresh, isNull);
    });
  });
}

final class _CountingAdapter implements HttpClientAdapter {
  new({this.status = 200, this.body = '{}'});

  final int status;
  final String body;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
