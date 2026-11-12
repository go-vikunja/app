import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_hosts.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _bob = User(id: 8, username: 'bob', name: 'Bob');

Future<bool> _yes(BrowserLeg _) async => true;

final Uri _auth = Uri.parse('https://auth.example.org/');
final Uri _login = Uri.parse('https://login.example.net/');

/// On tasks.example.org, with its sign-in page at [frontendUrl].
ServerConnection _server(Uri frontendUrl) =>
    accountPagesServer270(frontendUrl: frontendUrl);

void main() {
  late AuthFakes auth;
  late ProviderContainer container;
  late ProviderSubscription<SignInState> signIn;

  late FakeServerConnector connector;

  setUp(() {
    auth = AuthFakes();
    connector = FakeServerConnector.succeeding(fullServer270());
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        serverConnectorProvider.overrideWithValue(connector),
      ],
    );
    addTearDown(container.dispose);
    signIn = container.listen(signInControllerProvider, (_, _) {});
  });

  SignInController controller() =>
      container.read(signInControllerProvider.notifier);

  test('an account that was not on this device is new', () async {
    await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc(), userId: _bob.id),
    );
    auth.serveUser(_alice, now: DateTime.now().toUtc());

    await controller().signIn(fullServer270(), confirm: _yes);

    final succeeded = signIn.read() as SignInSucceeded;
    expect(succeeded.account.account.userId, _alice.id);
    expect(succeeded.isNewAccount, isTrue);
    expect(succeeded.wasActive, isFalse);
  });

  test('signing in to an account that is already here is not new and '
      'switches to it', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc(), userId: _bob.id),
    );
    auth.serveUser(_alice, now: DateTime.now().toUtc());

    await controller().signIn(fullServer270(), confirm: _yes);

    final succeeded = signIn.read() as SignInSucceeded;
    expect(succeeded.account.id, alice.id);
    expect(succeeded.isNewAccount, isFalse);
    expect(succeeded.wasActive, isFalse);
    expect((await auth.registry.load()).activeAccountId, alice.id);
  });

  test('signing in to the active account again says it was active', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    auth.serveUser(_alice, now: DateTime.now().toUtc());

    await controller().signIn(fullServer270(), confirm: _yes);

    final succeeded = signIn.read() as SignInSucceeded;
    expect(succeeded.account.id, alice.id);
    expect(succeeded.isNewAccount, isFalse);
    expect(succeeded.wasActive, isTrue);
  });

  test('signing in again is never new', () async {
    final alice = await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      needsReauth: true,
    );
    auth.serveUser(_alice, now: DateTime.now().toUtc());

    await controller().signInAgain(alice, confirm: _yes);

    final succeeded = signIn.read() as SignInSucceeded;
    expect(succeeded.account.id, alice.id);
    expect(succeeded.isNewAccount, isFalse);
  });

  test('a closed browser is no sign-in at all', () async {
    auth.webAuthenticator.handler = (_, _) async => null;

    await controller().signIn(fullServer270(), confirm: _yes);

    expect(signIn.read(), isA<SignInIdle>());
  });

  test(
    'a sign-in nobody waits for after the question opens no browser',
    () async {
      await controller().signIn(
        fullServer270(),
        confirm: (_) async {
          signIn.close();
          await pumpEventQueue();
          return true;
        },
      );

      expect(auth.webAuthenticator.urls, isEmpty);
    },
  );

  group('a sign-in page on another host', () {
    late List<BrowserLeg> legs;
    late bool answer;

    setUp(() {
      legs = [];
      answer = true;
      auth.serveUser(_alice, now: DateTime.now().toUtc());
    });

    Future<bool> ask(BrowserLeg leg) async {
      legs.add(leg);
      return answer;
    }

    String? askedAbout() => legs.removeAt(0).otherHost?.signInPage;

    test("is no question on the server's own origin", () async {
      await controller().signIn(
        _server(Uri.parse('https://tasks.example.org/')),
        confirm: ask,
      );

      expect(askedAbout(), isNull);
      expect(auth.webAuthenticator.urls, hasLength(1));
    });

    test('is asked about with both hosts, and Cancel opens no browser and '
        'remembers nothing', () async {
      answer = false;
      final server = _server(_auth);

      await controller().signIn(server, confirm: ask);

      final leg = legs.single;
      expect(leg.connection, same(server));
      expect(leg.otherHost?.server, 'tasks.example.org');
      expect(leg.otherHost?.signInPage, 'auth.example.org');
      expect(auth.webAuthenticator.urls, isEmpty);
      expect(signIn.read(), isA<SignInIdle>());

      legs.clear();
      await controller().signIn(server, confirm: ask);
      expect(askedAbout(), 'auth.example.org');
    });

    test('once confirmed, the browser opens there; a closed browser '
        'remembers nothing, so the next attempt asks again', () async {
      auth.webAuthenticator.handler = (_, _) async => null;

      await controller().signIn(_server(_auth), confirm: ask);
      expect(askedAbout(), 'auth.example.org');
      expect(auth.webAuthenticator.urls.single.host, 'auth.example.org');

      await controller().signIn(_server(_auth), confirm: ask);
      expect(askedAbout(), 'auth.example.org');
      expect(auth.preferences.values, isNot(contains(confirmedSignInHostsKey)));
    });

    test('the confirmation passes to the account: signing in again asks '
        'nothing, the next account added on the server is asked', () async {
      connector.handler = (_) async => _server(_auth);

      await controller().signIn(_server(_auth), confirm: ask);
      final alice = (signIn.read() as SignInSucceeded).account;
      expect(askedAbout(), 'auth.example.org');

      await controller().signInAgain(alice, confirm: ask);
      expect(signIn.read(), isA<SignInSucceeded>());
      expect(askedAbout(), isNull);

      auth.serveUser(_bob, now: DateTime.now().toUtc());
      await controller().signIn(_server(_auth), confirm: ask);
      expect(askedAbout(), 'auth.example.org');
    });

    test('signing in again asks about the page the new negotiation gives, '
        'not the stored one', () async {
      final alice = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      final fresh = _server(_auth);
      connector.handler = (_) async => fresh;
      answer = false;

      await controller().signInAgain(alice, confirm: ask);

      final leg = legs.single;
      expect(leg.connection, same(fresh));
      expect(leg.otherHost?.signInPage, 'auth.example.org');
      expect(auth.webAuthenticator.urls, isEmpty);
      expect(signIn.read(), isA<SignInIdle>());
    });

    test('an account from before asks once when signing in again, then only '
        'when the host changes', () async {
      final alice = await auth.seedAccount(
        _server(_auth),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      connector.handler = (_) async => _server(_auth);

      await controller().signInAgain(alice, confirm: ask);
      expect(askedAbout(), 'auth.example.org');
      expect(auth.webAuthenticator.urls.single.host, 'auth.example.org');

      await controller().signInAgain(alice, confirm: ask);
      expect(askedAbout(), isNull);

      connector.handler = (_) async => _server(_login);
      await controller().signInAgain(alice, confirm: ask);
      expect(askedAbout(), 'login.example.net');
    });

    test('signing in again that ends in a closed browser asks again next '
        'time', () async {
      final alice = await auth.seedAccount(
        _server(_auth),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      connector.handler = (_) async => _server(_auth);
      auth.webAuthenticator.handler = (_, _) async => null;

      await controller().signInAgain(alice, confirm: ask);
      expect(askedAbout(), 'auth.example.org');

      await controller().signInAgain(alice, confirm: ask);
      expect(askedAbout(), 'auth.example.org');
    });

    test('stores no more than the origin under the account id', () async {
      await controller().signIn(_server(_auth), confirm: ask);
      final alice = (signIn.read() as SignInSucceeded).account;

      expect(
        auth.preferences.values[confirmedSignInHostsKey],
        '{"${alice.id}":"https://auth.example.org:443"}',
      );
    });
  });
}
