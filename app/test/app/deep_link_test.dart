import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../features/accounts/accounts_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_details_fakes.dart';

const String _scheme = oauthCallbackScheme;

void main() {
  late SyncFakes data;

  setUp(() {
    data = SyncFakes();
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
    ];
    data.tasks.all = [
      sampleTask(id: 7, title: 'Water the plants', identifier: 'WORK-7'),
    ];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).state.matchedLocation;

  String activeAccountId(WidgetTester tester) =>
      containerOf(tester).read(accountsProvider).value!.activeAccountId!;

  final sheet = find.byType(TaskDetailSheet);

  Finder inSheet(String text) =>
      find.descendant(of: sheet, matching: find.text(text));

  void startWith(WidgetTester tester, String link) {
    tester.platformDispatcher.defaultRouteNameTestValue = link;
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  }

  Future<bool> push(WidgetTester tester, String link) async {
    final handled = await tester.binding.handlePushRoute(link);
    await tester.pumpAndSettle();
    return handled;
  }

  group('while the app runs', () {
    testWidgets('a task link opens the task over the overview', (tester) async {
      await pumpSignedInApp(tester, sync: data);

      expect(await push(tester, '$_scheme://task/7'), isTrue);

      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('by identifier, in any case, from another tab', (tester) async {
      await pumpSignedInApp(tester, sync: data);
      await openTab(tester, en.tabUpcoming);

      await push(tester, '$_scheme://task/work-7');

      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
      expect(data.resolver.resolved, [const TaskByIdentifier('work', 7)]);
    });

    testWidgets('a task not on this device is read online in the active '
        'account, saying so meanwhile', (tester) async {
      data.resolver.online[const TaskById(50)] = sampleTask(
        id: 50,
        title: 'Shared chore',
      );
      final read = Completer<void>();
      data.resolver.beforeResolve = (_) => read.future;
      await pumpSignedInApp(tester, sync: data);

      await push(tester, '$_scheme://task/50');
      expect(find.text(en.taskOpening), findsOneWidget);
      read.complete();
      await tester.pumpAndSettle();

      expect(data.resolver.onlineRequests, [const TaskById(50)]);
      expect(inSheet('Shared chore'), findsOneWidget);
      expect(find.text(en.taskOpening), findsNothing);
    });

    testWidgets('a task on this device opens without saying so', (
      tester,
    ) async {
      await pumpSignedInApp(tester, sync: data);

      await tester.binding.handlePushRoute('$_scheme://task/7');
      var announced = false;
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        announced |= find.text(en.taskOpening).evaluate().isNotEmpty;
      }
      await tester.pumpAndSettle();

      expect(announced, isFalse);
      expect(inSheet('Water the plants'), findsOneWidget);
    });

    for (final (name, failure, message) in [
      ('one that does not exist', null, en.taskOpenNotFound),
      (
        'one the user cannot read',
        const Forbidden() as Exception,
        en.taskOpenForbidden,
      ),
      (
        'one that is not here while offline',
        const NetworkFailure(NetworkProblem.unreachable),
        en.taskOpenOffline,
      ),
    ]) {
      testWidgets('$name is reported', (tester) async {
        if (failure != null) {
          data.resolver.failures[const TaskById(50)] = failure;
        }
        await pumpSignedInApp(tester, sync: data);

        await push(tester, '$_scheme://task/50');

        expect(sheet, findsNothing);
        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('a late OAuth callback and other links of the scheme are '
        'swallowed, never routed', (tester) async {
      await pumpSignedInApp(tester, sync: data);
      await openTab(tester, en.tabUpcoming);

      for (final link in [
        '$_scheme://oauth/callback?code=abc&state=xyz',
        '$_scheme://project/3',
        '$_scheme://task/',
        '$_scheme://task/PROJ-0',
      ]) {
        expect(await push(tester, link), isTrue, reason: link);
      }

      expect(location(tester), AppRoutes.upcoming);
      expect(find.byType(UpcomingScreen), findsOneWidget);
      expect(sheet, findsNothing);
      expect(data.resolver.resolved, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pushed route of the app is dropped too: any app can '
        'push one on Android', (tester) async {
      await pumpSignedInApp(tester, sync: data);

      expect(await push(tester, AppRoutes.upcoming), isTrue);

      expect(location(tester), AppRoutes.overview);
    });

    testWidgets('another deep-link source feeds the same opener', (
      tester,
    ) async {
      final source = FakeDeepLinkSource(
        initial: Uri.parse('$_scheme://task/7'),
      );
      addTearDown(source.controller.close);
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [deepLinkSourceProvider.overrideWithValue(source)],
      );

      expect(source.initialLinkCalls, 1);
      expect(inSheet('Water the plants'), findsOneWidget);

      source.push(Uri.parse('$_scheme://task/50'));
      await tester.pumpAndSettle();

      expect(data.resolver.resolved, [const TaskById(7), const TaskById(50)]);
      expect(find.text(en.taskOpenNotFound), findsOneWidget);
    });

    testWidgets('signed out a link is dropped', (tester) async {
      await pumpVikunjaApp(tester);

      await push(tester, '$_scheme://task/7');

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(sheet, findsNothing);
    });
  });

  group('the link that starts the app', () {
    testWidgets('starts at the splash and opens the task once the shell '
        'shows', (tester) async {
      startWith(tester, '$_scheme://task/7');
      await pumpSignedInApp(tester, sync: data);

      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
      expect(find.text('Page Not Found'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits for the first sync', (tester) async {
      startWith(tester, '$_scheme://task/7');
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      final sync = SyncFakes(status: const SyncNeverRun());
      sync.projects.all = data.projects.all;
      sync.tasks.all = data.tasks.all;
      final firstSync = Completer<void>();
      sync.engine.onEnsureInitialSync = () => firstSync.future;
      await pumpVikunjaApp(tester, auth: auth, sync: sync, settle: false);
      await pumpUntil(tester, find.byType(FirstSyncScreen));
      await pumpFrames(tester, 3);
      expect(sheet, findsNothing);

      firstSync.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
    });

    testWidgets('an OAuth callback as the start link opens nothing', (
      tester,
    ) async {
      startWith(tester, '$_scheme://oauth/callback?code=abc');
      await pumpSignedInApp(tester, sync: data);

      expect(location(tester), AppRoutes.overview);
      expect(sheet, findsNothing);
      expect(data.resolver.resolved, isEmpty);
    });
  });

  group('with several accounts', () {
    late ThreeAccounts accounts;

    setUp(() async {
      accounts = ThreeAccounts();
    });

    Future<void> seedAndPump(WidgetTester tester) async {
      await accounts.seed();
      accounts.aliceData.projects.all = data.projects.all;
      accounts.aliceData.tasks.all = data.tasks.all;
      accounts.bobData.projects.all = [
        sampleProject(id: 3, title: 'Garden', identifier: 'GARDEN'),
      ];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
      accounts.carolData.projects.all = [sampleProject(id: 3, title: 'Shop')];
      await accounts.pump(tester);
    }

    Future<void> confirmSwitchTo(WidgetTester tester, String name) async {
      expect(find.byType(AccountPickerSheet), findsOneWidget);
      expect(find.text(en.deepLinkSwitchAccountTitle), findsOneWidget);
      expect(activeAccountId(tester), accounts.alice.id);
      await tester.tap(
        find.descendant(
          of: find.byType(AccountPickerSheet),
          matching: find.text(name),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the account a link names is used once the user agrees', (
      tester,
    ) async {
      await seedAndPump(tester);
      accounts.carolData.tasks.all = [
        sampleTask(id: 7, title: 'Restock', projectId: 3),
      ];

      await push(tester, '$_scheme://task/7?account=${accounts.carol.id}');
      await confirmSwitchTo(tester, 'Carol');

      expect(activeAccountId(tester), accounts.carol.id);
      expect(inSheet('Restock'), findsOneWidget);
    });

    testWidgets('a link naming the active account opens without asking', (
      tester,
    ) async {
      await seedAndPump(tester);

      await push(tester, '$_scheme://task/7?account=${accounts.alice.id}');

      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(inSheet('Water the plants'), findsOneWidget);
    });

    testWidgets('the active account wins when it has the task', (tester) async {
      await seedAndPump(tester);
      accounts.bobData.tasks.all = [
        ...accounts.bobData.tasks.all,
        sampleTask(id: 7, title: 'Bob’s seven', projectId: 3),
      ];

      await push(tester, '$_scheme://task/7?account=nobody');

      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(activeAccountId(tester), accounts.alice.id);
      expect(inSheet('Water the plants'), findsOneWidget);
    });

    testWidgets('the only other account that has it is switched to once '
        'the user agrees', (tester) async {
      await seedAndPump(tester);

      await push(tester, '$_scheme://task/31');
      await confirmSwitchTo(tester, 'Bob');

      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Mow the lawn'), findsOneWidget);
      expect(accounts.aliceData.resolver.resolved, isEmpty);
    });

    testWidgets('declining the switch opens nothing', (tester) async {
      await seedAndPump(tester);

      await push(tester, '$_scheme://task/31?account=${accounts.bob.id}');
      expect(find.byType(AccountPickerSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(activeAccountId(tester), accounts.alice.id);
      expect(sheet, findsNothing);
    });

    testWidgets('by identifier, the account with that project', (tester) async {
      await seedAndPump(tester);
      accounts.bobData.tasks.all = [
        sampleTask(
          id: 31,
          title: 'Mow the lawn',
          projectId: 3,
          identifier: 'GARDEN-31',
        ),
      ];

      await push(tester, '$_scheme://task/garden-31');
      await confirmSwitchTo(tester, 'Bob');

      expect(activeAccountId(tester), accounts.bob.id);
      expect(inSheet('Mow the lawn'), findsOneWidget);
    });

    testWidgets('several accounts that have it: the user picks one', (
      tester,
    ) async {
      await seedAndPump(tester);
      accounts.carolData.tasks.all = [
        sampleTask(id: 31, title: 'Buy flour', projectId: 3),
      ];

      await push(tester, '$_scheme://task/31');

      expect(find.byType(AccountPickerSheet), findsOneWidget);
      expect(find.text(en.deepLinkPickAccountTitle), findsOneWidget);
      expect(activeAccountId(tester), accounts.alice.id);

      await tester.tap(
        find.descendant(
          of: find.byType(AccountPickerSheet),
          matching: find.text('Carol'),
        ),
      );
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.carol.id);
      expect(inSheet('Buy flour'), findsOneWidget);
    });

    testWidgets('closing the picker opens nothing', (tester) async {
      await seedAndPump(tester);
      accounts.carolData.tasks.all = [
        sampleTask(id: 31, title: 'Buy flour', projectId: 3),
      ];

      await push(tester, '$_scheme://task/31');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(activeAccountId(tester), accounts.alice.id);
      expect(sheet, findsNothing);
    });
  });
}
