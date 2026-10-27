import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/presentation/accounts_section.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/known_servers.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';
import 'accounts_harness.dart';

void main() {
  late ThreeAccounts accounts;

  setUp(() => accounts = ThreeAccounts());

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> openAddAccount(WidgetTester tester) async {
    await openSwitcher(tester);
    await tester.tap(inSheet(find.text(en.accountAdd)));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ActionChip, label);

  testWidgets('"Add account" opens the connect screen over the shell, which '
      'closes back to it without signing in', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);

    await openAddAccount(tester);

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.text(en.accountAdd), findsOneWidget);
    expect(find.text(en.addAccountTagline), findsOneWidget);
    expect(location(tester), AppRoutes.overview);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsNothing);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(accounts.auth.webAuthenticator.urls, isEmpty);
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.alice.id,
    );
  });

  testWidgets('system back closes it too', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openAddAccount(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('the Accounts section opens it as well', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    await tester.tap(
      find.descendant(
        of: find.byType(AccountsSection),
        matching: find.text(en.accountAdd),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(location(tester), AppRoutes.account);
  });

  testWidgets('offers the servers of the accounts here, which connect with '
      'one tap', (tester) async {
    await accounts.seed();
    final connector = FakeServerConnector.succeeding(oauthServer230());
    await accounts.pump(tester, connector: connector);
    await openAddAccount(tester);

    expect(find.text(en.addAccountYourServers), findsOneWidget);
    expect(find.byType(ActionChip), findsNWidgets(3));
    expect(chip('tasks.example.org/vikunja'), findsOneWidget);
    expect(chip('vikunja.example.com'), findsOneWidget);
    expect(chip('tasks.example.net:8443'), findsOneWidget);

    await tester.ensureVisible(chip('vikunja.example.com'));
    await tester.pumpAndSettle();
    await tester.tap(chip('vikunja.example.com'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://vikunja.example.com',
    );
    expect(connector.inputs, ['https://vikunja.example.com']);
    await tester.pumpAndSettle();
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
  });

  testWidgets('one chip per server', (tester) async {
    await accounts.seed(withCarol: false);
    await seedUser(
      accounts.auth,
      fullServer270(),
      userId: 10,
      username: 'dave',
      displayName: 'Dave',
    );
    await accounts.pump(tester);
    await openAddAccount(tester);

    expect(find.byType(ActionChip), findsNWidgets(2));
  });

  testWidgets('the onboarding connect screen has no server chips', (
    tester,
  ) async {
    await pumpVikunjaApp(tester);

    expect(find.byType(KnownServers), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
    expect(find.text(en.connectTagline), findsOneWidget);
  });

  testWidgets("the server overview's back and \"Use a different server\" "
      'return to the connect screen', (tester) async {
    await accounts.seed(withCarol: false);
    final connector = FakeServerConnector.succeeding(fullServer270());
    await accounts.pump(tester, connector: connector);
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();
    expect(find.byType(ServerOverviewScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ServerOverviewScreen), findsNothing);
    expect(find.byType(ConnectServerScreen), findsOneWidget);

    final connect = find.widgetWithText(FilledButton, en.connectContinue);
    await tester.ensureVisible(connect);
    await tester.pumpAndSettle();
    await tester.tap(connect);
    await tester.pumpAndSettle();
    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    await tester.ensureVisible(find.text(en.useDifferentServer));
    await tester.tap(find.text(en.useDifferentServer));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectServerScreen), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(ConnectServerScreen), findsNothing);
  });

  testWidgets('a new account goes to its first sync', (tester) async {
    await accounts.seed(withCarol: false);
    final server = fullServer270();
    const dave = User(id: 10, username: 'dave', name: 'Dave');
    accounts.auth.serveUser(dave, now: DateTime.now().toUtc());
    final daveData = AccountDataFakes(
      now: accounts.now,
      status: const SyncNeverRun(),
    );
    daveData.engine.onEnsureInitialSync = () => Completer<void>().future;
    accounts.data.accounts[accountIdFor(server.rootUri, dave.id)] = daveData;
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(server),
    );
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await pumpUntil(tester, find.byType(FirstSyncScreen));
    await pumpFrames(tester, 5);

    expect(location(tester), AppRoutes.firstSync);
    final registry = containerOf(tester).read(accountsProvider).value!;
    expect(registry.accounts, hasLength(3));
    expect(registry.activeAccount!.account.username, 'dave');
    expect(find.text(en.addAccountAlreadyAdded), findsNothing);
    // The sign-in page asks for credentials, so another user can sign in.
    expect(accounts.auth.webAuthenticator.urls, hasLength(1));
  });

  testWidgets('a new account never shows its Overview before its engine has '
      'reported', (tester) async {
    await accounts.seed(withCarol: false);
    final server = fullServer270();
    const dave = User(id: 10, username: 'dave', name: 'Dave');
    accounts.auth.serveUser(dave, now: DateTime.now().toUtc());
    final daveId = accountIdFor(server.rootUri, dave.id);
    final daveData = AccountDataFakes(
      now: accounts.now,
      status: const SyncNeverRun(),
      restored: false,
    );
    daveData.engine.onEnsureInitialSync = () => Completer<void>().future;
    accounts.data.accounts[daveId] = daveData;
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(server),
    );
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();
    final container = containerOf(tester);

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (container.read(activeAccountIdProvider) == daveId) {
        expect(find.byType(OverviewScreen), findsNothing);
      }
    }

    expect(container.read(activeAccountIdProvider), daveId);
    expect(find.byType(FirstSyncScreen), findsOneWidget);
  });

  testWidgets('a new account whose first sync ends at once opens on its '
      'Overview', (tester) async {
    await accounts.seed(withCarol: false);
    final server = fullServer270();
    const dave = User(id: 10, username: 'dave', name: 'Dave');
    accounts.auth.serveUser(dave, now: DateTime.now().toUtc());
    accounts.data.accounts[accountIdFor(server.rootUri, dave.id)] =
        AccountDataFakes(now: accounts.now, status: const SyncNeverRun());
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(server),
    );
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccount!.id,
      accountIdFor(server.rootUri, dave.id),
    );
  });

  testWidgets('a failed sign-in is not shown on the Account tab once the '
      'flow is closed', (tester) async {
    await accounts.seed(withCarol: false);
    accounts.auth.webAuthenticator.handler = (_, _) async =>
        throw const WebAuthenticationFailed(WebAuthenticationProblem.noBrowser);
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(fullServer270()),
    );
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionErrorCard), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await openTab(tester, en.tabAccount);

    expect(find.byType(ConnectionErrorCard), findsNothing);
  });

  testWidgets('an account already here is switched to and says so', (
    tester,
  ) async {
    await accounts.seed(withCarol: false);
    accounts.auth.serveUser(
      const User(id: 8, username: 'bob', name: 'Bob'),
      now: DateTime.now().toUtc(),
    );
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(oauthServer230()),
    );
    await openAddAccount(tester);
    await tester.tap(chip('vikunja.example.com'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pumpAndSettle();

    expect(find.text(en.addAccountAlreadyAdded), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(ServerOverviewScreen), findsNothing);
    expect(find.byType(ConnectServerScreen), findsNothing);
    final registry = containerOf(tester).read(accountsProvider).value!;
    expect(registry.accounts, hasLength(2));
    expect(registry.activeAccountId, accounts.bob.id);
  });

  testWidgets('an account already here whose engine reports late is '
      'switched to without the first-sync screen, and says so', (tester) async {
    await accounts.seed(withCarol: false);
    final bobData = accounts.data.accounts[accounts.bob.id] = AccountDataFakes(
      now: accounts.now,
      restored: false,
    );
    accounts.auth.serveUser(
      const User(id: 8, username: 'bob', name: 'Bob'),
      now: DateTime.now().toUtc(),
    );
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(oauthServer230()),
    );
    await openAddAccount(tester);
    await tester.tap(chip('vikunja.example.com'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
    }
    bobData.engine.emit(SyncIdle(lastSyncedAt: accounts.now));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(FirstSyncScreen), findsNothing);
    }
    await tester.pumpAndSettle();

    expect(find.text(en.addAccountAlreadyAdded), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.bob.id,
    );
  });

  testWidgets('adding the account in use again says so, without claiming a '
      'switch', (tester) async {
    await accounts.seed(withCarol: false);
    accounts.auth.serveUser(
      const User(id: 7, username: 'alice', name: 'Alice Example'),
      now: DateTime.now().toUtc(),
    );
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(fullServer270()),
    );
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pumpAndSettle();

    expect(find.text(en.addAccountAlreadyActive), findsOneWidget);
    expect(find.text(en.addAccountAlreadyAdded), findsNothing);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.alice.id,
    );
  });

  testWidgets('a failed "Sign in again" of the account in use does not show '
      'on the server overview of an account being added', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.auth.registry.markNeedsReauth(accounts.alice.id);
    accounts.auth.webAuthenticator.handler = (_, _) async =>
        throw const WebAuthenticationFailed(WebAuthenticationProblem.noBrowser);
    await accounts.pump(
      tester,
      connector: FakeServerConnector.succeeding(fullServer270()),
    );
    await openTab(tester, en.tabAccount);
    await tester.tap(find.widgetWithText(FilledButton, en.reauthAction));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionErrorCard), findsOneWidget);

    await openTab(tester, en.tabOverview);
    await openAddAccount(tester);
    await tester.tap(chip('tasks.example.org/vikunja'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerOverviewScreen), findsOneWidget);
    expect(find.byType(ConnectionErrorCard), findsNothing);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openSwitcher(tester);
    await tester.tap(inSheet(find.text(de.accountAdd)));
    await tester.pumpAndSettle();

    expect(find.text(de.accountAdd), findsOneWidget);
    expect(find.text(de.addAccountTagline), findsOneWidget);
    expect(find.text(de.addAccountYourServers), findsOneWidget);
  });
}
