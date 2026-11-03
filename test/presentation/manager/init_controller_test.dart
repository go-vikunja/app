import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/manager/init_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;
  late TestRepositories repos;

  setUp(() {
    final harness = controllerHarness();
    container = harness.container;
    repos = harness.repos;
  });

  Future<InitOutcome> run() => container.read(initControllerProvider.future);

  group('no stored server', () {
    test('goes to login without touching the network', () async {
      repos.settings.server = null;

      final outcome = await run();

      expect(outcome, isA<InitGoLogin>());
      expect((outcome as InitGoLogin).loginExpired, isFalse);
      expect(outcome.serverVersion, isNull);
      expect(repos.server.getInfoCount, 0);
    });
  });

  group('stored server', () {
    test('publishes the address so the client can be built', () async {
      repos.settings.server = 'https://vikunja.example.com';

      await run();

      expect(
        container.read(authDataProvider)!.address,
        'https://vikunja.example.com',
      );
    });

    test('reads the server version from /info', () async {
      repos.server.onGetInfo = () => ok(buildServer(version: 'v0.24.1'));

      final outcome = await run();

      expect((outcome as InitGoHome).serverVersion, Version(0, 24, 1));
    });

    test('leaves the version unset when /info fails', () async {
      repos.server.onGetInfo = () => err<Server>();

      final outcome = await run();

      expect((outcome as InitGoHome).serverVersion, isNull);
    });

    test('goes to login when there is no stored token', () async {
      repos.settings.userToken = null;
      repos.server.onGetInfo = () => ok(buildServer(version: 'v0.24.1'));

      final outcome = await run();

      expect(outcome, isA<InitGoLogin>());
      expect((outcome as InitGoLogin).loginExpired, isFalse);
      expect(outcome.serverVersion, Version(0, 24, 1));
    });

    test('goes home and publishes the user when the token is good', () async {
      repos.user.onGetCurrentUser = () => ok(buildUser(username: 'demo'));

      final outcome = await run();

      expect(outcome, isA<InitGoHome>());
      expect(container.read(currentUserProvider)!.username, 'demo');
    });

    test('clears the tokens and reports an expired login on 401', () async {
      repos.user.onGetCurrentUser = () => err<User>(status: 401);

      final outcome = await run();

      expect(outcome, isA<InitGoLogin>());
      expect((outcome as InitGoLogin).loginExpired, isTrue);
      expect(repos.settings.userToken, isNull);
      expect(repos.settings.refreshToken, isNull);
    });

    test('raises the api message for any other user-request failure', () async {
      repos.user.onGetCurrentUser = () =>
          err<User>(status: 500, error: {'message': 'server exploded'});

      await expectLater(run(), throwsA('server exploded'));
    });

    test('raises the raw error when the api sends no message', () async {
      repos.user.onGetCurrentUser = () =>
          err<User>(status: 500, error: const {});

      await expectLater(run(), throwsA(isA<Map<String, dynamic>>()));
    });

    test(
      'raises the underlying exception when the user request throws',
      () async {
        repos.user.onGetCurrentUser = () => boom<User>(StateError('offline'));

        await expectLater(run(), throwsA(isA<StateError>()));
      },
    );
  });
}
