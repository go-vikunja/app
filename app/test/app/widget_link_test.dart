import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/account_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';

import '../features/accounts/accounts_harness.dart';
import '../features/quick_add/presentation/composer_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/task_details_fakes.dart';
import '../helpers/widget_fakes.dart';

void main() {
  late ComposerHarness harness;
  late FakeWidgetHost host;
  late FakeWidgetRefresher refresher;

  setUp(() {
    harness = ComposerHarness();
    harness.data.tasks.all = [
      sampleTask(id: 7, title: 'Water the plants'),
      sampleTask(id: 8, title: 'Read the contract', projectId: 3),
    ];
    harness.data.projects.savedFilters = [
      const SavedFilterRef(projectId: -3, title: 'Urgent'),
    ];
    host = FakeWidgetHost();
    refresher = FakeWidgetRefresher();
  });

  final widgetOverrides = [
    widgetHostProvider.overrideWith((ref) => FakeWidgetHost()),
    widgetRefresherProvider.overrideWith((ref) => FakeWidgetRefresher()),
  ];

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) =>
      routerOf(tester).state.matchedLocation;

  String activeAccountId(WidgetTester tester) =>
      containerOf(tester).read(accountsProvider).value!.activeAccountId!;

  final sheet = find.byType(TaskDetailSheet);

  Finder inSheet(String text) =>
      find.descendant(of: sheet, matching: find.text(text));

  Finder projectField(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ProjectField));

  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(
      tester,
      sync: harness.data,
      now: composerNow,
      overrides: [
        ...harness.overrides,
        widgetHostProvider.overrideWithValue(host),
        widgetRefresherProvider.overrideWithValue(refresher),
      ],
    );
  }

  Future<bool> push(WidgetTester tester, WidgetLink link) async {
    final handled = await tester.binding.handlePushRoute('${link.toUri()}');
    await tester.pumpAndSettle();
    return handled;
  }

  group('while the app runs', () {
    testWidgets('a row opens its task over the overview', (tester) async {
      await pumpApp(tester);
      await openTab(tester, en.tabUpcoming);

      final handled = await push(
        tester,
        WidgetTaskLink(accountId: activeAccountId(tester), taskId: 7),
      );

      expect(handled, isTrue);
      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
      expect(find.byType(AccountPickerSheet), findsNothing);
    });

    testWidgets('a task that is gone says so', (tester) async {
      await pumpApp(tester);

      await push(
        tester,
        WidgetTaskLink(accountId: activeAccountId(tester), taskId: 99),
      );

      expect(sheet, findsNothing);
      expect(find.text(en.notificationTaskGone), findsOneWidget);
    });

    testWidgets('"+" opens the New task sheet in the widget\'s project', (
      tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester).go(AppRoutes.project(1));
      await tester.pumpAndSettle();

      await push(
        tester,
        WidgetNewTaskLink(accountId: activeAccountId(tester), projectId: 3),
      );

      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(location(tester), AppRoutes.overview);
      expect(projectField('Garage Sale'), findsOneWidget);

      await push(tester, const WidgetNewTaskLink());
      expect(find.byType(NewTaskSheet), findsOneWidget);
    });

    testWidgets('a Quick add widget without an account uses the active one', (
      tester,
    ) async {
      await pumpApp(tester);

      await push(tester, const WidgetNewTaskLink(projectId: 3));

      expect(find.byType(NewTaskSheet), findsOneWidget);
      // The project belongs to an account, so it is not used without one.
      expect(projectField('Inbox'), findsOneWidget);
    });

    testWidgets('the lists open where the app shows them', (tester) async {
      await pumpApp(tester);
      final account = activeAccountId(tester);

      Future<void> open(WidgetListKind kind, {int? id}) =>
          push(tester, WidgetListLink(accountId: account, kind: kind, id: id));

      await open(WidgetListKind.upcoming);
      expect(location(tester), AppRoutes.upcoming);
      expect(find.byType(UpcomingScreen), findsOneWidget);

      await open(WidgetListKind.today);
      expect(location(tester), AppRoutes.overview);

      await open(WidgetListKind.project, id: 3);
      expect(location(tester), AppRoutes.project(3));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);

      await open(WidgetListKind.overdue);
      expect(location(tester), AppRoutes.overview);

      await open(WidgetListKind.favorites);
      expect(location(tester), AppRoutes.project(Project.favoritesId));
      expect(find.byType(SmartListScreen), findsOneWidget);

      await open(WidgetListKind.savedFilter, id: 2);
      expect(location(tester), AppRoutes.project(-3));

      await open(WidgetListKind.label, id: 10);
      expect(location(tester), AppRoutes.labelTasks(10));
      expect(find.byType(LabelTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a reauth state opens the Account tab', (tester) async {
      await pumpApp(tester);

      await push(tester, WidgetAccountLink(accountId: activeAccountId(tester)));

      expect(location(tester), AppRoutes.account);
      expect(find.byType(AccountTab), findsOneWidget);
    });

    testWidgets('"Open Rurana" only opens the app', (tester) async {
      await pumpApp(tester);
      await openTab(tester, en.tabUpcoming);

      await push(tester, const WidgetOpenLink(accountId: 'gone'));
      await push(tester, const WidgetOpenLink());

      expect(location(tester), AppRoutes.upcoming);
    });

    testWidgets('a widget being set up opens its setup page', (tester) async {
      await pumpApp(tester);

      await push(tester, const WidgetConfigureLink(appWidgetId: 12));

      expect(find.byType(WidgetConfigurePage), findsOneWidget);
      expect(
        routerOf(tester).state.uri.toString(),
        AppRoutes.widgetConfigure(12, fromWidget: true),
      );
      expect(
        tester
            .widget<WidgetConfigurePage>(find.byType(WidgetConfigurePage))
            .fromWidget,
        isTrue,
      );

      await push(tester, const WidgetConfigureLink(appWidgetId: 12));
      expect(find.byType(WidgetConfigurePage), findsOneWidget);
    });

    testWidgets('malformed widget links and unknown accounts are swallowed', (
      tester,
    ) async {
      await pumpApp(tester);
      await openTab(tester, en.tabUpcoming);

      for (final link in [
        '$_scheme://widget/task/seven?account=x',
        '$_scheme://widget/list?account=x&kind=weekly',
        '$_scheme://widget/settings',
        '${const WidgetTaskLink(accountId: 'nobody', taskId: 7).toUri()}',
        '$_scheme://widget/list?account=nobody&kind=today',
      ]) {
        expect(await tester.binding.handlePushRoute(link), isTrue);
        await tester.pumpAndSettle();
      }

      expect(location(tester), AppRoutes.upcoming);
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('another widget-link source feeds the same listener', (
      tester,
    ) async {
      final source = FakeDeepLinkSource();
      addTearDown(source.controller.close);
      usePhoneSurface(tester);
      await pumpSignedInApp(
        tester,
        sync: harness.data,
        now: composerNow,
        overrides: [
          ...harness.overrides,
          ...widgetOverrides,
          widgetLinkSourceProvider.overrideWithValue(source),
        ],
      );

      source.push(
        WidgetTaskLink(accountId: activeAccountId(tester), taskId: 7).toUri(),
      );
      await tester.pumpAndSettle();

      expect(source.initialLinkCalls, 1);
      expect(inSheet('Water the plants'), findsOneWidget);
    });

    testWidgets('signed out a widget link is dropped', (tester) async {
      await pumpVikunjaApp(tester, overrides: widgetOverrides);

      await tester.binding.handlePushRoute(
        '${const WidgetNewTaskLink().toUri()}',
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(find.byType(NewTaskSheet), findsNothing);
    });
  });

  group('the link that starts the app', () {
    void startWith(WidgetTester tester, String link) {
      tester.platformDispatcher.defaultRouteNameTestValue = link;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    }

    testWidgets('opens the task once the shell shows', (tester) async {
      final auth = AuthFakes();
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      startWith(
        tester,
        '${WidgetTaskLink(accountId: entry.id, taskId: 7).toUri()}',
      );
      usePhoneSurface(tester);
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: harness.data,
        overrides: [...harness.overrides, ...widgetOverrides],
      );

      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Water the plants'), findsOneWidget);
      expect(find.text('Page Not Found'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits for the first sync', (tester) async {
      final auth = AuthFakes();
      final entry = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      startWith(
        tester,
        '${WidgetNewTaskLink(accountId: entry.id, projectId: 3).toUri()}',
      );
      final sync = SyncFakes(status: const SyncNeverRun());
      sync.projects.all = harness.data.projects.all;
      final firstSync = Completer<void>();
      sync.engine.onEnsureInitialSync = () => firstSync.future;
      usePhoneSurface(tester);
      await pumpVikunjaApp(
        tester,
        auth: auth,
        sync: sync,
        overrides: [...harness.overrides, ...widgetOverrides],
        settle: false,
      );
      await pumpUntil(tester, find.byType(FirstSyncScreen));
      await pumpFrames(tester, 3);
      expect(find.byType(NewTaskSheet), findsNothing);

      firstSync.complete();
      await tester.pumpAndSettle();

      expect(location(tester), AppRoutes.overview);
      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(projectField('Garage Sale'), findsOneWidget);
    });

    testWidgets('a widget setup opens over the overview', (tester) async {
      startWith(tester, '${const WidgetConfigureLink(appWidgetId: 5).toUri()}');
      await pumpApp(tester);

      expect(find.byType(WidgetConfigurePage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.overview);
    });
  });

  group('with several accounts', () {
    late ThreeAccounts accounts;

    setUp(() async {
      accounts = ThreeAccounts();
      await accounts.seed();
      accounts.aliceData.projects.all = [sampleProject(id: 1, title: 'Work')];
      accounts.aliceData.tasks.all = [
        sampleTask(id: 7, title: 'Water the plants'),
      ];
      accounts.bobData.projects.all = [sampleProject(id: 3, title: 'Garden')];
      accounts.bobData.tasks.all = [
        sampleTask(id: 31, title: 'Mow the lawn', projectId: 3),
      ];
    });

    Future<void> pumpAccounts(WidgetTester tester) =>
        accounts.pump(tester, overrides: widgetOverrides);

    testWidgets("a row of another account's widget switches without asking", (
      tester,
    ) async {
      await pumpAccounts(tester);

      await push(
        tester,
        WidgetTaskLink(accountId: accounts.bob.id, taskId: 31),
      );

      expect(find.byType(AccountPickerSheet), findsNothing);
      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.overview);
      expect(inSheet('Mow the lawn'), findsOneWidget);
    });

    testWidgets('its list opens in that account', (tester) async {
      await pumpAccounts(tester);

      await push(
        tester,
        WidgetListLink(
          accountId: accounts.bob.id,
          kind: WidgetListKind.project,
          id: 3,
        ),
      );

      expect(activeAccountId(tester), accounts.bob.id);
      expect(location(tester), AppRoutes.project(3));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('a done link, which any app can send, neither switches nor '
        'writes', (tester) async {
      await pumpAccounts(tester);

      expect(
        await tester.binding.handlePushRoute(
          '$_scheme://widget/done/31?account=${accounts.bob.id}',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(activeAccountId(tester), accounts.alice.id);
      expect(accounts.bobData.tasks.writes, isEmpty);
      expect(accounts.aliceData.tasks.writes, isEmpty);
    });

    testWidgets('its "+" opens the New task sheet in that account', (
      tester,
    ) async {
      await pumpAccounts(tester);

      await push(
        tester,
        WidgetNewTaskLink(accountId: accounts.bob.id, projectId: 3),
      );

      expect(activeAccountId(tester), accounts.bob.id);
      expect(find.byType(NewTaskSheet), findsOneWidget);
      expect(projectField('Garden'), findsOneWidget);
    });

    testWidgets('a widget of an account that was removed opens nothing', (
      tester,
    ) async {
      await pumpAccounts(tester);
      await openTab(tester, en.tabUpcoming);

      await push(
        tester,
        const WidgetTaskLink(accountId: 'removed', taskId: 31),
      );

      expect(activeAccountId(tester), accounts.alice.id);
      expect(location(tester), AppRoutes.upcoming);
      expect(sheet, findsNothing);
    });
  });
}

const String _scheme = 'vikunja-dev.coderoftime.vikunja';
