import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_switcher_button.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_tile.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
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

  Finder tileOf(String accountId) => inSheet(find.byKey(ValueKey(accountId)));

  testWidgets('lists the active account first, then by when they were last '
      'active, each with its user and server', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);

    final names = [
      for (final tile in tester.widgetList<AccountTile>(
        inSheet(find.byType(AccountTile)),
      ))
        tile.entry.account.displayName,
    ];
    expect(names, ['Alice Example', 'Carol', 'Bob']);
    expect(inSheet(find.text(en.accountsHeading)), findsOneWidget);
    expect(
      inSheet(find.text(en.accountSubtitle('alice', 'tasks.example.org'))),
      findsOneWidget,
    );
    expect(
      inSheet(find.text(en.accountSubtitle('bob', 'vikunja.example.com'))),
      findsOneWidget,
    );
    // The port only when it is not the default one.
    expect(
      inSheet(find.text(en.accountSubtitle('carol', 'tasks.example.net:8443'))),
      findsOneWidget,
    );
    expect(inSheet(find.text('AE')), findsOneWidget);
    expect(inSheet(find.text(en.accountAdd)), findsOneWidget);
    expect(inSheet(find.text(en.accountManage)), findsOneWidget);
  });

  testWidgets('marks the active account, also for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);

    final alice = find.descendant(
      of: tileOf(accounts.alice.id),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(alice).selected, isTrue);
    expect(
      find.descendant(
        of: tileOf(accounts.alice.id),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tileOf(accounts.bob.id),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    final aliceNode = tester.getSemantics(alice);
    expect(aliceNode, isSemantics(isSelected: true));
    expect(aliceNode.label, contains('Alice Example'));
    expect(aliceNode.label, contains(en.accountCurrent));
    expect(
      tester.getSemantics(
        find.descendant(
          of: tileOf(accounts.bob.id),
          matching: find.byType(ListTile),
        ),
      ),
      isSemantics(isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('badges an account that needs a new sign-in and one with '
      'changes not sent yet', (tester) async {
    await accounts.seed(bobNeedsReauth: true);
    accounts.carolData.tasks.pendingChanges = 3;
    await accounts.pump(tester);

    await openSwitcher(tester);

    Finder inTile(String accountId, String text) =>
        find.descendant(of: tileOf(accountId), matching: find.text(text));
    expect(inTile(accounts.bob.id, en.accountBadgeSignInAgain), findsOneWidget);
    expect(inTile(accounts.bob.id, en.accountBadgeUnsent(3)), findsNothing);
    expect(inTile(accounts.carol.id, en.accountBadgeUnsent(3)), findsOneWidget);
    expect(inTile(accounts.carol.id, en.accountBadgeSignInAgain), findsNothing);
    expect(inSheet(find.text(en.accountBadgeSignInAgain)), findsOneWidget);

    accounts.carolData.tasks.pendingChanges = 0;
    await tester.pumpAndSettle();
    expect(inSheet(find.text(en.accountBadgeUnsent(3))), findsNothing);
  });

  testWidgets('a tap on another account switches to it, closes the sheet '
      'and says so', (tester) async {
    await accounts.seed();
    accounts.aliceData.tasks.all = [sampleTask(id: 1, title: 'Alice task')];
    accounts.bobData.tasks.all = [sampleTask(id: 1, title: 'Bob task')];
    await accounts.pump(tester);
    expect(find.text('Alice task'), findsOneWidget);

    await openSwitcher(tester);
    await tester.tap(inSheet(find.text('Bob')));
    await tester.pumpAndSettle();

    final registry = containerOf(tester).read(accountsProvider).value!;
    expect(registry.activeAccountId, accounts.bob.id);
    expect(switcherSheet, findsNothing);
    expect(find.text(en.accountSwitchedTo('Bob')), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.text('Bob task'), findsOneWidget);
    expect(find.text('Alice task'), findsNothing);

    // The most recent account comes right after the active one now.
    await openSwitcher(tester);
    final names = [
      for (final tile in tester.widgetList<AccountTile>(
        inSheet(find.byType(AccountTile)),
      ))
        tile.entry.account.displayName,
    ];
    expect(names, ['Bob', 'Alice Example', 'Carol']);
  });

  testWidgets('a tap on the active account does nothing', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);
    await tester.tap(inSheet(find.text('Alice Example')));
    await tester.pumpAndSettle();

    expect(switcherSheet, findsOneWidget);
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.alice.id,
    );
  });

  testWidgets('"Manage accounts" opens the Account tab', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);
    await tester.tap(inSheet(find.text(en.accountManage)));
    await tester.pumpAndSettle();

    expect(switcherSheet, findsNothing);
    expect(find.byType(AccountTab), findsOneWidget);
    expect(location(tester), AppRoutes.account);
  });

  testWidgets('the avatar buttons on the Overview and Projects say whose '
      'account is shown', (tester) async {
    final semantics = tester.ensureSemantics();
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);

    final label = en.accountSwitcherButton(
      'Alice Example',
      'tasks.example.org',
    );
    final matcher = isSemantics(
      label: label,
      isButton: true,
      hasTapAction: true,
    );
    expect(tester.getSemantics(find.byType(AccountSwitcherButton)), matcher);
    expect(find.bySemanticsLabel('AE'), findsNothing);
    expect(find.byTooltip(en.accountsHeading), findsOneWidget);

    await openTab(tester, en.tabProjects);
    expect(tester.getSemantics(find.byType(AccountSwitcherButton)), matcher);
    await openSwitcher(tester);
    expect(switcherSheet, findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the account button follows a switch', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    expect(
      find.descendant(
        of: find.byType(AccountSwitcherButton),
        matching: find.text('AE'),
      ),
      findsOneWidget,
    );

    await containerOf(tester)
        .read(accountRegistryProvider)
        .setActive(accounts.bob.id);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AccountSwitcherButton),
        matching: find.text('B'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('is a Cupertino sheet on iOS', (tester) async {
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);

    final route = ModalRoute.of(tester.element(switcherSheet));
    expect(route, isA<CupertinoSheetRoute<void>>());
    await tester.tap(inSheet(find.text('Carol')));
    await tester.pumpAndSettle();
    expect(
      containerOf(tester).read(accountsProvider).value!.activeAccountId,
      accounts.carol.id,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("the iOS sheet's title sits below the drag handle", (
    tester,
  ) async {
    await accounts.seed();
    await accounts.pump(tester);

    await openSwitcher(tester);

    final sheetTop = tester.getTopLeft(switcherSheet).dy;
    final titleTop = tester
        .getTopLeft(inSheet(find.text(en.accountsHeading)))
        .dy;
    // The handle is drawn 5 to 10 points below the top, in a 15 point inset.
    expect(titleTop - sheetTop, greaterThanOrEqualTo(15));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await accounts.seed(bobNeedsReauth: true);
    accounts.carolData.tasks.pendingChanges = 2;
    await accounts.pump(tester);

    await openSwitcher(tester);

    expect(inSheet(find.text(de.accountsHeading)), findsOneWidget);
    expect(inSheet(find.text(de.accountBadgeSignInAgain)), findsOneWidget);
    expect(inSheet(find.text(de.accountBadgeUnsent(2))), findsOneWidget);
    expect(inSheet(find.text(de.accountAdd)), findsOneWidget);
    expect(inSheet(find.text(de.accountManage)), findsOneWidget);

    await tester.tap(inSheet(find.text('Bob')));
    await tester.pumpAndSettle();
    expect(find.text(de.accountSwitchedTo('Bob')), findsOneWidget);
  });

  testWidgets('switching and adding rest while a sign-in runs, which '
      'activates its account when it ends', (tester) async {
    await accounts.seed(withCarol: false);
    accounts.auth.webAuthenticator.handler = (_, _) => Completer<Uri?>().future;
    await accounts.pump(tester);
    final container = containerOf(tester);
    unawaited(
      container
          .read(signInControllerProvider.notifier)
          .signIn(oauthServer230(), confirm: (_) async => true),
    );
    await tester.pump();

    await openSwitcher(tester);

    final bob = tester.widget<ListTile>(
      find.descendant(
        of: tileOf(accounts.bob.id),
        matching: find.byType(ListTile),
      ),
    );
    expect(bob.onTap, isNull);
    final add = tester.widget<ListTile>(
      find.ancestor(
        of: inSheet(find.text(en.accountAdd)),
        matching: find.byType(ListTile),
      ),
    );
    expect(add.onTap, isNull);
    expect(
      await container.read(accountSwitcherProvider).switchTo(accounts.bob.id),
      isFalse,
    );
    expect(
      container.read(accountsProvider).value!.activeAccountId,
      accounts.alice.id,
    );
  });

  testWidgets('switching rests while a sign-out runs', (tester) async {
    await accounts.seed(withCarol: false);
    await accounts.pump(tester);
    final container = containerOf(tester);

    await openSwitcher(tester);
    accounts.auth.secureStore.beforeDelete = (_) => Completer<void>().future;
    unawaited(
      container
          .read(signOutControllerProvider.notifier)
          .signOut(accounts.bob.id),
    );
    await tester.pump();

    final bob = tester.widget<ListTile>(
      find.descendant(
        of: tileOf(accounts.bob.id),
        matching: find.byType(ListTile),
      ),
    );
    expect(bob.onTap, isNull);
  });
}
