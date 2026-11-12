import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

// Where the router goes when an account is removed while others remain.
// Driven through the controllers, so the confirmation dialogs stay out.
void main() {
  late AuthFakes auth;
  late SyncFakes sync;

  setUp(() {
    auth = AuthFakes();
    sync = SyncFakes();
  });

  Future<RegisteredAccount> seed(ServerConnection connection, int userId) =>
      auth.seedAccount(
        connection,
        tokens: issueTokens(
          issuedAt: DateTime.now().toUtc(),
          userId: userId,
          username: 'user$userId',
        ),
        displayName: 'User $userId',
      );

  /// Every location the router shows from now on.
  List<String> recordLocations(WidgetTester tester) {
    final router = containerOf(tester).read(appRouterProvider);
    final locations = <String>[];
    void record() =>
        locations.add(router.routerDelegate.currentConfiguration.uri.path);
    router.routerDelegate.addListener(record);
    addTearDown(() => router.routerDelegate.removeListener(record));
    return locations;
  }

  testWidgets('removing the active account keeps the shell and shows the '
      'most recently active other account', (tester) async {
    usePhoneSurface(tester);
    // Stored as Bob, Carol, Alice, each made active when added.
    final bob = await seed(oauthServer230(), 8);
    final carol = await seed(insecureServer(), 9);
    final alice = await seed(fullServer270(), 7);
    for (final entry in [alice, bob, carol]) {
      sync.accounts[entry.id] = AccountDataFakes(now: DateTime.now());
    }
    await pumpVikunjaApp(tester, auth: auth, sync: sync);
    expect(find.byType(HomeShell), findsOneWidget);
    final container = containerOf(tester);
    final locations = recordLocations(tester);

    await container.read(signOutControllerProvider.notifier).signOut(alice.id);
    await tester.pumpAndSettle();

    expect(container.read(activeAccountIdProvider), carol.id);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(
      locations,
      everyElement(
        isNot(anyOf(AppRoutes.connect, AppRoutes.firstSync, AppRoutes.splash)),
      ),
    );
    expect(sync.files.deleted, [alice.id]);
  });

  testWidgets('removing the active account never shows the first-sync screen '
      "while the next account's engine has not reported", (tester) async {
    usePhoneSurface(tester);
    final bob = await seed(oauthServer230(), 8);
    final alice = await seed(fullServer270(), 7);
    sync.accounts[alice.id] = AccountDataFakes(now: DateTime.now());
    final bobData = sync.accounts[bob.id] = AccountDataFakes(
      now: DateTime.now(),
      restored: false,
    );
    await pumpVikunjaApp(tester, auth: auth, sync: sync);
    final container = containerOf(tester);

    unawaited(
      container.read(signOutControllerProvider.notifier).signOut(alice.id),
    );
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
    }
    bobData.engine.emit(SyncIdle(lastSyncedAt: DateTime.now()));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
    }

    await tester.pumpAndSettle();
    expect(container.read(activeAccountIdProvider), bob.id);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('cancelling the first sync of an added account returns to the '
      'shell of the account that was active before it', (tester) async {
    usePhoneSurface(tester);
    // Bob was added first; Alice is the one in use.
    final bob = await seed(oauthServer230(), 8);
    final alice = await seed(fullServer270(), 7);
    for (final entry in [alice, bob]) {
      sync.accounts[entry.id] = AccountDataFakes(now: DateTime.now());
    }
    await pumpVikunjaApp(tester, auth: auth, sync: sync);
    expect(find.byType(HomeShell), findsOneWidget);
    final container = containerOf(tester);

    // Carol on another server; her first sync is still running.
    const carolUser = User(id: 9, username: 'carol', name: 'Carol');
    final carolServer = insecureServer();
    final carolId = accountIdFor(carolServer.rootUri, carolUser.id);
    final carolData = AccountDataFakes(
      now: DateTime.now(),
      status: const SyncNeverRun(),
    );
    carolData.engine.onEnsureInitialSync = () => Completer<void>().future;
    sync.accounts[carolId] = carolData;
    auth.serveUser(carolUser, now: DateTime.now().toUtc());
    final signIns = <SignInState>[];
    final signIn = container.listen(
      signInControllerProvider,
      (_, next) => signIns.add(next),
    );
    addTearDown(signIn.close);
    await container
        .read(signInControllerProvider.notifier)
        .signIn(carolServer, confirm: (_) async => true);
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    expect(signIns.whereType<SignInSucceeded>().single.isNewAccount, isTrue);
    expect(carolData.engine.ensureInitialSyncCalls, greaterThan(0));
    // The shell's page has animated away, as it has by the time anyone
    // taps Cancel and confirms.
    await pumpFrames(tester, 10);
    final locations = recordLocations(tester);

    // What the first-sync screen's Cancel runs once confirmed.
    await container.read(signOutControllerProvider.notifier).signOut(carolId);
    await pumpUntil(tester, find.byType(HomeShell));
    await tester.pumpAndSettle();

    expect(container.read(activeAccountIdProvider), alice.id);
    expect(find.byType(FirstSyncScreen), findsNothing);
    expect(locations, isNot(contains(AppRoutes.connect)));
    expect(carolData.engine.disposed, isTrue);
    expect(sync.files.deleted, [carolId]);
  });
}
