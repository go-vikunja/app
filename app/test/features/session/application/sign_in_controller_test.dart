import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _bob = User(id: 8, username: 'bob', name: 'Bob');

void main() {
  late AuthFakes auth;
  late ProviderContainer container;
  late ProviderSubscription<SignInState> signIn;

  setUp(() {
    auth = AuthFakes();
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        serverConnectorProvider.overrideWithValue(
          FakeServerConnector.succeeding(fullServer270()),
        ),
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

    await controller().signIn(fullServer270());

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

    await controller().signIn(fullServer270());

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

    await controller().signIn(fullServer270());

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

    await controller().signInAgain(alice);

    final succeeded = signIn.read() as SignInSucceeded;
    expect(succeeded.account.id, alice.id);
    expect(succeeded.isNewAccount, isFalse);
  });

  test('a closed browser is no sign-in at all', () async {
    auth.webAuthenticator.handler = (_, _) async => null;

    await controller().signIn(fullServer270());

    expect(signIn.read(), isA<SignInIdle>());
  });
}
