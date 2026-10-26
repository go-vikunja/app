import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/auth/link_share_session.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/server_connections.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 12);
  final server = fullServer270();
  late AuthFakes auth;
  late FakeLinkShareGateway gateway;
  late LinkShareSessions sessions;
  late FakeServerConnector connector;
  late GuestLandings landings;
  late List<int> titleReads;
  late Future<String?> Function() projectTitle;
  late GuestSignIn guestSignIn;

  ParsedLinkShareUrl link({int? viewId = 4}) => ParsedLinkShareUrl(
    base: Uri.parse('https://tasks.example.org/vikunja/'),
    hash: fakeShareHash,
    viewId: viewId,
  );

  setUp(() {
    auth = AuthFakes();
    gateway = auth.linkShareGateway;
    sessions = LinkShareSessions(
      store: auth.linkShareStore,
      gateway: gateway,
      connectionFor: (id) async => (await auth.registry.find(id))?.connection,
      markNeedsReauth: auth.registry.markNeedsReauth,
      clock: () => now,
    );
    connector = FakeServerConnector.succeeding(server);
    landings = GuestLandings();
    titleReads = [];
    projectTitle = () async => 'Garden';
    guestSignIn = GuestSignIn(
      gateway: gateway,
      store: auth.linkShareStore,
      sessions: sessions,
      registry: auth.registry,
      connector: connector,
      landing: landings,
      projectTitle: (connection, tokens, projectId) async {
        titleReads.add(projectId);
        await tokens.validAccessToken();
        return await projectTitle();
      },
      clock: () => now,
    );
  });

  final guestId = linkShareAccountIdFor(server.rootUri, 84);

  group('signIn', () {
    test('stores the secrets and the guest, makes it active and remembers '
        'where it lands', () async {
      final token = issueLinkShareToken(issuedAt: now);
      gateway.serve(token, name: 'Helper');

      final result = await guestSignIn.signIn(server, link());

      final signedIn = result as GuestSignedIn;
      expect(signedIn.isNewAccount, isTrue);
      final account = signedIn.account.account;
      expect(account.id, guestId);
      expect(account.isLinkShare, isTrue);
      expect(account.linkShareId, 84);
      expect(account.projectId, 1378);
      expect(account.shareName, 'Helper');
      expect(account.displayName, 'Helper');
      expect(account.addedAt, now);
      final registry = await auth.registry.load();
      expect(registry.activeAccountId, guestId);
      expect(registry.find(guestId)?.connection.rootUri, server.rootUri);
      final stored = await auth.linkShareStore.read(guestId);
      expect(stored?.hash, fakeShareHash);
      expect(stored?.token, token.jwt);
      expect(
        landings.take(guestId),
        const GuestLanding(projectId: 1378, viewId: 4),
      );
      expect(landings.take(guestId), isNull);
      expect(gateway.authentications, [(fakeShareHash, null)]);
      expect(await sessions.forAccount(guestId).validAccessToken(), token.jwt);
      expect(gateway.authentications, hasLength(1));
    });

    test("an unnamed share takes the project's title", () async {
      gateway.serve(issueLinkShareToken(issuedAt: now));

      final titled = await guestSignIn.signIn(server, link());

      expect((titled as GuestSignedIn).account.account.displayName, 'Garden');
      expect(titled.account.account.shareName, isNull);
      expect(titleReads, [1378]);
    });

    test('falls back to the pseudo user name without a title', () async {
      gateway.serve(issueLinkShareToken(issuedAt: now));
      projectTitle = () async => throw const ServerFailure(500);

      final result = await guestSignIn.signIn(server, link());

      expect(
        (result as GuestSignedIn).account.account.displayName,
        'link-share-84',
      );
    });

    test('asks for the password, says when it was wrong, and never stores '
        'it', () async {
      final token = issueLinkShareToken(issuedAt: now);
      gateway.serve(token, password: 'p4ss-word');

      final without = await guestSignIn.signIn(server, link());
      final wrong = await guestSignIn.signIn(server, link(), password: 'guess');
      final right = await guestSignIn.signIn(
        server,
        link(),
        password: 'p4ss-word',
      );

      expect(without, isA<GuestPasswordRequired>());
      expect((without as GuestPasswordRequired).wrongPassword, isFalse);
      expect((wrong as GuestPasswordRequired).wrongPassword, isTrue);
      expect(right, isA<GuestSignedIn>());
      expect(gateway.authentications.last, (fakeShareHash, 'p4ss-word'));
      expect([
        ...auth.secureStore.values.values,
        ...auth.preferences.values.values,
      ], everyElement(isNot(contains('p4ss-word'))));
      expect((await auth.registry.load()).accounts, hasLength(1));
    });

    test('a share that is gone, or link sharing off, stores nothing', () async {
      gateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone(code: 3006);
      final gone = await guestSignIn.signIn(server, link());
      gateway.onAuthenticate = (_, _) async => throw const LinkShareGone();
      final routesAbsent = await guestSignIn.signIn(server, link());

      expect((gone as GuestLinkGone).sharingOff, isFalse);
      expect((routesAbsent as GuestLinkGone).sharingOff, isTrue);
      expect(auth.secureStore.values, isEmpty);
      expect((await auth.registry.load()).accounts, isEmpty);
    });

    test('a server without link sharing is not asked', () async {
      final info = ServerInfo(version: ServerVersion.tryParse('v2.7.0'));
      final off = ServerConnection(
        rootUri: server.rootUri,
        apiVersions: server.apiVersions,
        info: info,
        capabilities: ServerCapabilities.derive(
          info: info,
          apiVersions: server.apiVersions,
        ),
      );

      final result = await guestSignIn.signIn(off, link());

      expect((result as GuestLinkGone).sharingOff, isTrue);
      expect(gateway.authentications, isEmpty);
    });

    test("a stored account's server is asked even when its snapshot has "
        'link sharing off', () async {
      final info = ServerInfo(version: ServerVersion.tryParse('v2.7.0'));
      final snapshot = ServerConnection(
        rootUri: server.rootUri,
        apiVersions: server.apiVersions,
        info: info,
        capabilities: ServerCapabilities.derive(
          info: info,
          apiVersions: server.apiVersions,
        ),
      );
      await auth.seedAccount(snapshot, tokens: issueTokens(issuedAt: now));
      gateway.serve(issueLinkShareToken(issuedAt: now));

      final result = await guestSignIn.signIn(snapshot, link());

      expect(result, isA<GuestSignedIn>());
      expect(gateway.authentications, hasLength(1));
    });

    test('the sign-in limit fails with its wait', () async {
      gateway.onAuthenticate = (_, _) async =>
          throw const RateLimited(retryAfter: Duration(seconds: 15));

      final result = await guestSignIn.signIn(server, link());

      expect(
        (result as GuestSignInFailed).failure,
        isA<RateLimited>().having(
          (failure) => failure.retryAfter,
          'retryAfter',
          const Duration(seconds: 15),
        ),
      );
    });

    test(
      'the same share again replaces the session of the same guest',
      () async {
        await auth.seedGuest(
          server,
          token: issueLinkShareToken(issuedAt: now),
          needsReauth: true,
        );
        final ended = sessions.forAccount(guestId)
          ..noteGone(const LinkShareGone());
        final fresh = issueLinkShareToken(issuedAt: now);
        gateway.serve(fresh, name: 'Helper');
        final activatedExisting = <String>[];

        final result = await guestSignIn.signIn(
          server,
          link(),
          beforeActivatingExisting: (id) async => activatedExisting.add(id),
        );

        final signedIn = result as GuestSignedIn;
        expect(signedIn.isNewAccount, isFalse);
        expect(signedIn.account.account.needsReauth, isFalse);
        expect(signedIn.account.account.addedAt, DateTime.utc(2026, 10, 26));
        expect(activatedExisting, [guestId]);
        expect((await auth.registry.load()).accounts, hasLength(1));
        expect(
          await sessions.forAccount(guestId).validAccessToken(),
          fresh.jwt,
        );
        expect(sessions.forAccount(guestId), isNot(same(ended)));
      },
    );
  });

  group('the same share opened again', () {
    late LinkShareToken old;

    setUp(() async {
      old = issueLinkShareToken(issuedAt: now);
      await auth.seedGuest(server, token: old);
      gateway.serve(issueLinkShareToken(issuedAt: now));
    });

    test('keeps the old session answering until the new one is in '
        'place', () async {
      expect(await sessions.forAccount(guestId).validAccessToken(), old.jwt);
      final handedOut = <String>[];
      auth.secureStore.beforeWrite = (key) async {
        if (key != LinkShareStore.hashKey(guestId)) return;
        handedOut.add(await sessions.forAccount(guestId).validAccessToken());
      };

      expect(await guestSignIn.signIn(server, link()), isA<GuestSignedIn>());

      expect(handedOut, [old.jwt]);
    });

    test('keeps the old session when its secrets cannot be stored', () async {
      auth.secureStore.beforeWrite = (_) async =>
          throw StateError('the keystore is locked');

      await expectLater(
        guestSignIn.signIn(server, link()),
        throwsA(isA<StateError>()),
      );

      auth.secureStore.beforeWrite = null;
      expect(await sessions.forAccount(guestId).validAccessToken(), old.jwt);
      expect((await auth.registry.find(guestId))?.account.needsReauth, isFalse);
    });
  });

  group('connect', () {
    test("takes a stored account's server whose web frontend the link is "
        'under, without probing', () async {
      await auth.seedAccount(server, tokens: issueTokens(issuedAt: now));

      final connection = await guestSignIn.connect(link());

      expect(connection.rootUri, server.rootUri);
      expect(connector.inputs, isEmpty);
    });

    test("probes the link's base, or the address the user gave", () async {
      await guestSignIn.connect(link());
      await guestSignIn.connect(link(), serverAddress: 'api.example.org');

      expect(connector.inputs, [
        'https://tasks.example.org/vikunja/',
        'api.example.org',
      ]);
    });

    test(
      'a link to a web frontend without an API there fails to connect',
      () async {
        connector.handler = (_) async =>
            throw ServerUnreachable(Uri.parse('https://web.example.org/'));

        await expectLater(
          guestSignIn.connect(link()),
          throwsA(isA<ServerConnectionFailure>()),
        );
      },
    );
  });

  group('the stored link', () {
    test('opens again with the stored hash and server', () async {
      await auth.seedGuest(
        server,
        token: issueLinkShareToken(issuedAt: now),
        needsReauth: true,
      );
      gateway.serve(issueLinkShareToken(issuedAt: now), password: 'pw');

      final stored = await guestSignIn.storedLink(guestId);
      final asked = await guestSignIn.reopen(guestId);
      final opened = await guestSignIn.reopen(guestId, password: 'pw');

      expect(stored?.base, Uri.parse('https://tasks.example.org/vikunja/'));
      expect(stored?.hash, fakeShareHash);
      expect(asked, isA<GuestPasswordRequired>());
      expect(opened, isA<GuestSignedIn>());
      expect((await auth.registry.find(guestId))?.account.needsReauth, isFalse);
      expect(connector.inputs, isEmpty);
      expect(landings.take(guestId), isNull);
    });

    test('is gone with its hash', () async {
      final guest = await auth.seedGuest(
        server,
        token: issueLinkShareToken(issuedAt: now),
      );
      auth.secureStore.values.remove(LinkShareStore.hashKey(guest.id));

      expect(await guestSignIn.storedLink(guest.id), isNull);
      expect(await guestSignIn.reopen(guest.id), isA<GuestLinkGone>());
      expect(gateway.authentications, isEmpty);
    });
  });
}
