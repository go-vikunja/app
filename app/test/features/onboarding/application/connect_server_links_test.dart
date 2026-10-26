import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/auth/link_share_account_id.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/guest_entry_fakes.dart';
import '../../../helpers/guest_fakes.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

void main() {
  const base = 'https://tasks.example.org/vikunja/';
  late FakeServerConnector connector;
  late AuthFakes auth;
  late FakeInviteLinksPort invites;
  late ProviderContainer container;
  late List<ConnectServerState> states;
  late List<LogRecord> logs;
  final server = fullServer270();
  final accountId = linkShareAccountIdFor(server.rootUri, 84);

  setUp(() {
    connector = FakeServerConnector.succeeding(server);
    auth = AuthFakes();
    invites = FakeInviteLinksPort();
    container = ProviderContainer.test(
      overrides: [
        ...auth.overrides,
        ...SyncFakes().overrides,
        serverConnectorProvider.overrideWithValue(connector),
        ...guestEntryOverrides(invites: invites),
      ],
    );
    states = [];
    container.listen(
      connectServerControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    logs = [];
    final subscription = Logger.root.onRecord.listen(logs.add);
    addTearDown(subscription.cancel);
  });

  ConnectServerController controller() =>
      container.read(connectServerControllerProvider.notifier);
  ConnectServerState state() => container.read(connectServerControllerProvider);

  void expectNoSecretsLogged({String? password}) {
    for (final record in logs) {
      final text = '${record.message} ${record.error ?? ''}';
      expect(text, isNot(contains(fakeShareHash)));
      expect(text, isNot(contains(fakeInviteToken)));
      if (password != null) expect(text, isNot(contains(password)));
    }
  }

  test('shows what it opens without the secret of a link', () async {
    auth.linkShareGateway.serve(issueLinkShareToken(issuedAt: DateTime.now()));
    invites.onCheck = (_) async => InvitePreview(name: 'Autumn team');

    await controller().connect(shareLink());
    await controller().connect(inviteLink());

    expect(
      states.whereType<ConnectServerConnecting>().map(
        (s) => (s.input, s.target),
      ),
      [
        ('${base}share/xxxx…/auth', ConnectTarget.sharedLink),
        (base, ConnectTarget.invite),
      ],
    );
  });

  group('an invite', () {
    test('is checked on the server its link names', () async {
      invites.onCheck = (_) async => InvitePreview(
        name: 'Autumn team',
        teams: const [InviteTeam(id: 3, name: 'Design')],
        skipsEmailConfirmation: true,
      );

      await controller().connect('  ${inviteLink()}  ');

      expect(connector.inputs, [base]);
      expect(invites.checkedTokens, [fakeInviteToken]);
      expect(
        state(),
        isA<ConnectServerInviteFound>()
            .having((s) => s.check, 'check', InviteCheck.passed)
            .having((s) => s.preview?.name, 'name', 'Autumn team')
            .having((s) => s.connection, 'connection', same(server)),
      );
      expect(container.read(currentServerProvider), isNull);
      expectNoSecretsLogged();
    });

    test('refused with 2005 says so', () async {
      invites.onCheck = (_) async => throw const NotFound(code: 2005);

      await controller().connect(inviteLink());

      expect(
        state(),
        isA<ConnectServerLinkFailed>()
            .having((s) => s.error, 'error', const NotFound(code: 2005))
            .having((s) => s.serverRoot, 'serverRoot', server.rootUri),
      );
    });

    test('on a server without the check can only be opened', () async {
      invites.onCheck = (_) async => throw const NotFound();

      await controller().connect(inviteLink());

      expect(
        state(),
        isA<ConnectServerInviteFound>()
            .having((s) => s.check, 'check', InviteCheck.unavailable)
            .having((s) => s.preview, 'preview', isNull),
      );
    });

    test('that could not be checked can still be opened', () async {
      invites.onCheck = (_) async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await controller().connect(inviteLink());

      expect(
        state(),
        isA<ConnectServerInviteFound>().having(
          (s) => s.check,
          'check',
          InviteCheck.failed,
        ),
      );
    });

    test('on a plain http server goes there only after consent', () async {
      connector.handler = (_) async => insecureServer();
      invites.onCheck = (_) async => InvitePreview(name: 'Lab');

      await controller().connect(inviteLink(base: 'http://192.168.1.20:3456/'));
      expect(state(), isA<ConnectServerAwaitingInsecureConsent>());
      expect(invites.checkedTokens, isEmpty);

      await controller().acceptInsecureConnection();

      expect(invites.checkedTokens, [fakeInviteToken]);
      expect(state(), isA<ConnectServerInviteFound>());
    });

    test('declined on http is never checked', () async {
      connector.handler = (_) async => insecureServer();

      await controller().connect(inviteLink(base: 'http://192.168.1.20:3456/'));
      controller().declineInsecureConnection();
      await controller().connect('vikunja.example.com');

      expect(invites.checkedTokens, isEmpty);
    });

    test('continues to the server for the sign-in', () async {
      invites.onCheck = (_) async => InvitePreview(name: '');
      await controller().connect(inviteLink());

      controller().continueToSignIn();

      expect(state(), isA<ConnectServerConnected>());
      expect(container.read(currentServerProvider), same(server));
    });

    test('whose server cannot be reached names only the server', () async {
      connector.handler = (_) async => throw ServerUnreachable(Uri.parse(base));

      await controller().connect(inviteLink());

      expect(
        state(),
        isA<ConnectServerFailed>().having((s) => s.input, 'input', base),
      );
    });

    test('is opened in the browser at its own address', () {
      final link = Uri.parse(inviteLink());

      expect(inviteUrl(parseInviteLink(inviteLink())!), link);
    });
  });

  group('a shared link', () {
    late LinkShareToken token;

    setUp(() {
      token = issueLinkShareToken(issuedAt: DateTime.now().toUtc());
    });

    test("opens as a guest that becomes active and lands on the link's "
        'view', () async {
      auth.linkShareGateway.serve(token, name: 'Helper');

      await controller().connect(shareLink(viewId: 12));

      expect(connector.inputs, [base]);
      expect(auth.linkShareGateway.authentications, [(fakeShareHash, null)]);
      expect(
        state(),
        isA<ConnectServerGuestSignedIn>()
            .having((s) => s.account.id, 'account', accountId)
            .having((s) => s.isNewAccount, 'isNewAccount', isTrue),
      );
      final registry = await auth.registry.load();
      expect(registry.activeAccountId, accountId);
      expect(registry.find(accountId)?.account.isLinkShare, isTrue);
      expect(
        await LinkShareStore(auth.secureStore).read(accountId),
        isA<StoredLinkShare>().having((s) => s.hash, 'hash', fakeShareHash),
      );
      expect(
        container.read(guestLandingsProvider).take(accountId),
        const GuestLanding(projectId: 1378, viewId: 12),
      );
      expectNoSecretsLogged();
    });

    test('found in a longer text opens too', () async {
      auth.linkShareGateway.serve(token);

      await controller().connect('Our garden plan: ${shareLink()} – enjoy');

      expect(state(), isA<ConnectServerGuestSignedIn>());
    });

    test('with a password asks for it, keeps a wrong one in the sheet and '
        'opens with the right one', () async {
      auth.linkShareGateway.serve(token, password: 'tomato');

      await controller().connect(shareLink());
      expect(
        state(),
        isA<ConnectServerSharePasswordNeeded>().having(
          (s) => s.serverRoot,
          'serverRoot',
          server.rootUri,
        ),
      );

      expect(
        await controller().submitSharePassword('potato'),
        SharePasswordOutcome.wrong,
      );
      expect(state(), isA<ConnectServerSharePasswordNeeded>());

      expect(
        await controller().submitSharePassword('tomato'),
        SharePasswordOutcome.accepted,
      );
      expect(state(), isA<ConnectServerGuestSignedIn>());
      expect(auth.linkShareGateway.authentications, [
        (fakeShareHash, null),
        (fakeShareHash, 'potato'),
        (fakeShareHash, 'tomato'),
      ]);
      // The password went into the requests only.
      for (final value in auth.secureStore.values.values) {
        expect(value, isNot(contains('tomato')));
      }
      for (final value in auth.preferences.values.values) {
        expect(value, isNot(contains('tomato')));
      }
      expectNoSecretsLogged(password: 'tomato');
    });

    test('a password the server then fails on ends in the failure', () async {
      auth.linkShareGateway.serve(token, password: 'tomato');
      await controller().connect(shareLink());
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const RateLimited(retryAfter: Duration(seconds: 20));

      expect(
        await controller().submitSharePassword('tomato'),
        SharePasswordOutcome.failed,
      );
      expect(
        state(),
        isA<ConnectServerLinkFailed>().having(
          (s) => s.error,
          'error',
          isA<RateLimited>(),
        ),
      );
      expect(
        await controller().submitSharePassword('tomato'),
        SharePasswordOutcome.failed,
      );
      expect(auth.linkShareGateway.authentications, hasLength(2));
    });

    test('that is gone says so', () async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone(code: 3006);

      await controller().connect(shareLink());

      expect(
        state(),
        isA<ConnectServerLinkFailed>().having(
          (s) => s.error,
          'error',
          isA<GuestLinkGone>().having(
            (gone) => gone.sharingOff,
            'sharingOff',
            isFalse,
          ),
        ),
      );
      expect((await auth.registry.load()).accounts, isEmpty);
    });

    test('on a server without link sharing says so', () async {
      auth.linkShareGateway.onAuthenticate = (_, _) async =>
          throw const LinkShareGone();

      await controller().connect(shareLink());

      expect(
        state(),
        isA<ConnectServerLinkFailed>().having(
          (s) => s.error,
          'error',
          isA<GuestLinkGone>().having(
            (gone) => gone.sharingOff,
            'sharingOff',
            isTrue,
          ),
        ),
      );
    });

    test('whose address is only the web asks for the server', () async {
      final apiServer = fullServer270(root: 'https://api.example.org');
      connector.handler = (input) async => input == 'api.example.org'
          ? apiServer
          : throw NotAVikunjaServer(Uri.parse(base), statusCode: 200);
      auth.linkShareGateway.serve(token);

      await controller().connect(shareLink());
      expect(
        state(),
        isA<ConnectServerShareNeedsServer>().having(
          (s) => s.linkBase,
          'linkBase',
          Uri.parse(base),
        ),
      );
      expect(auth.linkShareGateway.authentications, isEmpty);

      await controller().connect('api.example.org', forPendingShare: true);

      expect(connector.inputs, [base, 'api.example.org']);
      expect(auth.linkShareGateway.connections.single, same(apiServer));
      expect(
        state(),
        isA<ConnectServerGuestSignedIn>().having(
          (s) => s.account.connection,
          'connection',
          same(apiServer),
        ),
      );
    });

    test('waiting for its server goes to no server the user did not give '
        'for it', () async {
      connector.handler = (input) async => input == base
          ? throw NotAVikunjaServer(Uri.parse(base), statusCode: 200)
          : oauthServer230();
      auth.linkShareGateway.serve(token);
      await controller().connect(shareLink());

      await controller().connect('https://try.vikunja.io');

      expect(state(), isA<ConnectServerConnected>());
      expect(auth.linkShareGateway.authentications, isEmpty);
    });

    test('waiting for its server is forgotten on reset', () async {
      connector.handler = (input) async =>
          throw NotAVikunjaServer(Uri.parse(base), statusCode: 200);
      await controller().connect(shareLink());

      controller().reset();
      connector.handler = (_) async => oauthServer230();
      await controller().connect('vikunja.example.com');

      expect(state(), isA<ConnectServerConnected>());
      expect(auth.linkShareGateway.authentications, isEmpty);
    });

    test('whose server cannot be reached names only the server', () async {
      connector.handler = (_) async => throw ServerTimeout(Uri.parse(base));

      await controller().connect(shareLink());

      expect(
        state(),
        isA<ConnectServerFailed>()
            .having((s) => s.input, 'input', base)
            .having((s) => s.failure, 'failure', isA<ServerTimeout>()),
      );
    });

    test('on a plain http server authenticates only after consent', () async {
      connector.handler = (_) async => insecureServer();
      auth.linkShareGateway.serve(token);

      await controller().connect(shareLink(base: 'http://192.168.1.20:3456/'));
      expect(state(), isA<ConnectServerAwaitingInsecureConsent>());
      expect(auth.linkShareGateway.authentications, isEmpty);

      await controller().acceptInsecureConnection();

      expect(auth.linkShareGateway.authentications, hasLength(1));
      expect(state(), isA<ConnectServerGuestSignedIn>());
    });

    test('cancelled while its server is probed stores nothing', () async {
      final pending = Completer<ServerConnection>();
      connector.handler = (_) => pending.future;

      final connecting = controller().connect(shareLink());
      controller().cancel();
      pending.complete(server);
      await connecting;

      expect(state(), isA<ConnectServerIdle>());
      expect(auth.linkShareGateway.authentications, isEmpty);
      expect((await auth.registry.load()).accounts, isEmpty);
    });

    test('opened again replaces the guest and says it was there', () async {
      auth.linkShareGateway.serve(token);
      await controller().connect(shareLink());
      controller().reset();

      await controller().connect(shareLink());

      expect(
        state(),
        isA<ConnectServerGuestSignedIn>().having(
          (s) => s.isNewAccount,
          'isNewAccount',
          isFalse,
        ),
      );
      expect((await auth.registry.load()).accounts, hasLength(1));
    });
  });

  test('a password without a link waiting for it fails', () async {
    expect(
      await controller().submitSharePassword('tomato'),
      SharePasswordOutcome.failed,
    );
    expect(auth.linkShareGateway.authentications, isEmpty);
  });
}
