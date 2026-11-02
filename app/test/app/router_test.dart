import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).routerDelegate.currentConfiguration.uri.toString();

  test('a tab is matched on a path segment, so the pages over the shell '
      'are not tabs', () {
    for (final location in [
      AppRoutes.overview,
      AppRoutes.upcoming,
      AppRoutes.projects,
      AppRoutes.project(1),
      AppRoutes.project(1, viewId: 12),
      AppRoutes.account,
    ]) {
      expect(AppRoutes.isTab(location), isTrue, reason: location);
    }
    for (final location in [
      AppRoutes.home,
      AppRoutes.taskEdit(7),
      AppRoutes.taskDescription(7),
      AppRoutes.projectEdit(1),
      AppRoutes.projectDescription(1),
      AppRoutes.projectViews(1),
      AppRoutes.inbox,
      AppRoutes.search,
      AppRoutes.labelTasks(5),
      AppRoutes.savedFilterNew,
      AppRoutes.savedFilterEdit(-2),
      AppRoutes.addAccount,
      AppRoutes.addAccountServer,
      AppRoutes.connect,
    ]) {
      expect(AppRoutes.isTab(location), isFalse, reason: location);
    }
  });

  test("a project's route names a view only when given one", () {
    expect(AppRoutes.project(1), '/home/projects/1');
    expect(AppRoutes.project(1, viewId: 12), '/home/projects/1?view=12');
  });

  testWidgets('starts on the connect screen', (tester) async {
    await pumpVikunjaApp(tester);

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ConnectServerScreen), findsOneWidget);
  });

  testWidgets('redirects the overview to connect when no server is held', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);

    routerOf(tester).go(AppRoutes.serverOverview);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });

  testWidgets('opens the overview when a server is held', (tester) async {
    await pumpVikunjaApp(tester);
    containerOf(tester)
        .read(currentServerProvider.notifier)
        .select(oauthServer230());

    routerOf(tester).go(AppRoutes.serverOverview);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.serverOverview);
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets('leaves the overview when the server is cleared', (tester) async {
    await pumpServerOverview(tester, oauthServer230());

    containerOf(tester).read(currentServerProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(ServerOverviewScreen), findsNothing);
  });

  group('cold start', () {
    testWidgets('routes to home without waiting for the network', (
      tester,
    ) async {
      final auth = AuthFakes();
      final tokens = issueTokens(issuedAt: DateTime.now().toUtc());
      await auth.seedAccount(fullServer270(), tokens: tokens);
      final connector = FakeServerConnector();
      await pumpVikunjaApp(tester, auth: auth, connector: connector);

      expect(location(tester), AppRoutes.overview);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(connector.inputs, isEmpty);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      // The session check after the first frame.
      expect(auth.accountGateway.currentUserTokens, [tokens.accessToken]);
    });

    testWidgets('an account that never synced opens the first-sync screen', (
      tester,
    ) async {
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      final sync = SyncFakes(status: const SyncNeverRun());
      sync.engine.onEnsureInitialSync = () => Completer<void>().future;
      await pumpVikunjaApp(tester, auth: auth, sync: sync, settle: false);
      await pumpUntil(tester, find.byType(FirstSyncScreen));

      expect(location(tester), AppRoutes.firstSync);
    });

    testWidgets('with an account whose session ended still opens home', (
      tester,
    ) async {
      final auth = AuthFakes();
      await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      await pumpVikunjaApp(tester, auth: auth);

      expect(location(tester), AppRoutes.overview);
    });

    testWidgets('an account without tokens opens home asking to sign in', (
      tester,
    ) async {
      final auth = AuthFakes();
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      await auth.tokenStore.delete(entry.id);
      await pumpVikunjaApp(tester, auth: auth);

      expect(location(tester), AppRoutes.overview);
      await openTab(tester, en.tabAccount);
      expect(find.byType(ReauthBanner), findsOneWidget);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect((await auth.registry.find(entry.id))!.account.needsReauth, isTrue);
    });

    testWidgets('without accounts opens the connect screen', (tester) async {
      await pumpVikunjaApp(tester, auth: AuthFakes());

      expect(location(tester), AppRoutes.connect);
    });

    for (final (name, signedIn, screen) in [
      ('home', true, HomeShell),
      ('the connect screen', false, ConnectServerScreen),
    ]) {
      testWidgets(
        'with the accounts loaded before the first frame, $name '
        'appears without a transition',
        (tester) async {
          final auth = AuthFakes();
          if (signedIn) {
            await auth.seedAccount(
              fullServer270(),
              tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
            );
          }
          // What bootstrap does before runApp.
          final container = ProviderContainer(
            overrides: appOverrides(auth: auth),
          );
          final accounts = await container.read(accountsProvider.future);
          if (accounts.activeAccount case final entry?) {
            await firstSyncStatus(container, entry.id);
            await container.read(notificationsOnboardingProvider.future);
          }

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const VikunjaApp(),
            ),
          );

          final route = ModalRoute.of(tester.element(find.byType(screen)))!;
          expect(route.animation?.status, AnimationStatus.completed);
          await tester.pumpAndSettle();

          // Bootstrap's container outlives the tree; the test's must not,
          // or the kept-alive providers' timers outlive the test.
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
        }),
      );
    }

    testWidgets('an unreadable registry opens the connect screen', (
      tester,
    ) async {
      final auth = AuthFakes();
      auth.preferences.values['auth.account_registry'] = '[';
      await pumpVikunjaApp(tester, auth: auth);

      expect(location(tester), AppRoutes.connect);
    });
  });

  testWidgets('home redirects to connect without an account', (tester) async {
    await pumpVikunjaApp(tester);

    routerOf(tester).go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('the inbox redirects to connect without an account', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);

    routerOf(tester).go(AppRoutes.inbox);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
  });

  testWidgets(
    'the notification setup redirects to connect without an account',
    (tester) async {
      await pumpVikunjaApp(tester);

      routerOf(tester).go(AppRoutes.notificationsSetup);
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.connect);
    },
  );

  testWidgets('signed in, the connect screen stays reachable', (tester) async {
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(tester, auth: auth);

    routerOf(tester).go(AppRoutes.connect);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.connect);
  });
}
