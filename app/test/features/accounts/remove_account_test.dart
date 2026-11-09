import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/accounts/presentation/accounts_section.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
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

  Finder inSection(Finder finder) =>
      find.descendant(of: find.byType(AccountsSection), matching: finder);

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRemoveDialog(WidgetTester tester, String name) async {
    await tester.tap(find.byTooltip(en.accountMoreActions(name)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.accountRemove));
    await tester.pumpAndSettle();
  }

  testWidgets('the Accounts section lists the other accounts, most recently '
      'active first, and switches with a tap', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    final names = [
      for (final tile in tester.widgetList<AccountTile>(
        inSection(find.byType(AccountTile)),
      ))
        tile.entry.account.displayName,
    ];
    expect(names, ['Carol', 'Bob']);
    expect(inSection(find.text(en.accountsHeading)), findsOneWidget);
    expect(inSection(find.text(en.accountAdd)), findsOneWidget);
    expect(find.text(en.homeSignOutOfThisAccount), findsNothing);
    await scrollTo(tester, find.text(en.homeSignOutOfThisAccount));
    expect(find.text(en.homeSignOutOfThisAccount), findsOneWidget);

    await tester.scrollUntilVisible(
      inSection(find.text('Bob')),
      -100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(inSection(find.text('Bob')));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.bob.id,
    );
    expect(find.text(en.accountSwitchedTo('Bob')), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  testWidgets('removing another account from its menu leaves the active one '
      'and its screen alone', (tester) async {
    await accounts.seed(withCarol: false);
    accounts.bobData.tasks.pendingChanges = 2;
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);
    expect(inSection(find.text(en.accountBadgeUnsent(2))), findsOneWidget);

    await openRemoveDialog(tester, 'Bob');

    expect(find.text(en.removeAccountDialogTitle), findsOneWidget);
    final body = en.signOutDialogBody(
      en.signOutDialogAccount('Bob', 'bob'),
      'vikunja.example.com',
    );
    expect(
      find.text('$body ${en.removeAccountDialogPendingChanges(2)}'),
      findsOneWidget,
    );
    await tester.tap(
      find.widgetWithText(TextButton, en.removeAccountDialogConfirm),
    );
    await tester.pumpAndSettle();

    final registry = containerOf(tester).read(accountsProvider).value!;
    expect(registry.accounts.map((entry) => entry.id), [accounts.alice.id]);
    expect(registry.activeAccountId, accounts.alice.id);
    expect(location(tester), AppRoutes.account);
    expect(find.byType(AccountTab), findsOneWidget);
    expect(find.text(en.accountSignedOutOf('Bob')), findsOneWidget);
    expect(inSection(find.byType(AccountTile)), findsNothing);
    expect(accounts.aliceData.engine.disposed, isFalse);
    expect(accounts.data.files.deleted, [accounts.bob.id]);
    await scrollTo(tester, find.text(en.homeSignOut));
    expect(find.text(en.homeSignOut), findsOneWidget);
  });

  testWidgets('removing an account whose session ended says it needs a new '
      'sign-in before its changes can be sent', (tester) async {
    await accounts.seed(withCarol: false, bobNeedsReauth: true);
    accounts.bobData.tasks.pendingChanges = 2;
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    await openRemoveDialog(tester, 'Bob');

    final body = en.signOutDialogBody(
      en.signOutDialogAccount('Bob', 'bob'),
      'vikunja.example.com',
    );
    expect(
      find.text('$body ${en.removeAccountDialogPendingChangesSignInFirst(2)}'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the removal keeps the account', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    await openRemoveDialog(tester, 'Bob');
    await tester.tap(find.text(en.signOutDialogCancel));
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(accountsProvider).value!.accounts,
      hasLength(2),
    );
    expect(accounts.data.files.deleted, isEmpty);
  });

  testWidgets('signing out of the active account switches to the most '
      'recently active other one', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    await scrollTo(tester, find.text(en.homeSignOutOfThisAccount));
    await tester.tap(find.text(en.homeSignOutOfThisAccount));
    await tester.pumpAndSettle();

    expect(find.text(en.signOutDialogTitle), findsOneWidget);
    final body = en.signOutDialogBody(
      en.signOutDialogAccount('Alice Example', 'alice'),
      'tasks.example.org',
    );
    expect(
      find.text('$body ${en.signOutDialogSwitchesTo('Carol')}'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    final registry = containerOf(tester).read(accountsProvider).value!;
    expect(registry.activeAccountId, accounts.carol.id);
    expect(registry.accounts, hasLength(2));
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(location(tester), AppRoutes.overview);
    expect(find.text(en.accountSignedOutOf('Alice Example')), findsOneWidget);
    expect(accounts.aliceData.engine.disposed, isTrue);
    expect(accounts.carolData.engine.disposed, isFalse);
  });

  testWidgets('signing out of the last account returns to the connect '
      'screen', (tester) async {
    await seedUser(
      accounts.auth,
      fullServer270(),
      userId: 7,
      username: 'alice',
      displayName: 'alice',
    );
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);
    expect(inSection(find.byType(AccountTile)), findsNothing);

    await scrollTo(tester, find.text(en.homeSignOut));
    await tester.tap(find.text(en.homeSignOut));
    await tester.pumpAndSettle();
    expect(
      find.text(en.signOutDialogBody('alice', 'tasks.example.org')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('signing out of the last account takes along the snackbars '
      'still up or queued, like the Undo of a delete', (tester) async {
    await seedUser(
      accounts.auth,
      fullServer280(),
      userId: 7,
      username: 'alice',
      displayName: 'alice',
    );
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);
    await scrollTo(tester, find.text(en.homeSignOut));
    await tester.tap(find.text(en.homeSignOut));
    await tester.pumpAndSettle();
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      ..showSnackBar(
        SnackBar(
          content: Text(en.taskMovedToTrash),
          persist: true,
          action: SnackBarAction(label: en.undo, onPressed: () {}),
        ),
      )
      ..showSnackBar(SnackBar(content: Text(en.taskRestored)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the removal dialog is a Cupertino alert on iOS', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openTab(tester, en.tabAccount);

    await openRemoveDialog(tester, 'Bob');

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, en.removeAccountDialogConfirm),
    );
    expect(confirm.isDestructiveAction, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    await openTab(tester, de.tabAccount);

    expect(inSection(find.text(de.accountsHeading)), findsOneWidget);
    await tester.tap(find.byTooltip(de.accountMoreActions('Bob')));
    await tester.pumpAndSettle();
    expect(find.text(de.accountRemove), findsOneWidget);
    await tester.tap(find.text(de.accountRemove));
    await tester.pumpAndSettle();
    expect(find.text(de.removeAccountDialogTitle), findsOneWidget);
    expect(find.text(de.removeAccountDialogConfirm), findsOneWidget);
  });
}
