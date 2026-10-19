import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/realtime/realtime_connection.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/sync/application/realtime_connection_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
  });

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  Future<void> tapInAccountTab(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      100,
      scrollable: find
          .descendant(
            of: find.byType(AccountTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Finder progressBar(Finder screen) => find.descendant(
    of: find.descendant(of: screen, matching: find.byType(SyncProgressBar)),
    matching: find.byType(LinearProgressIndicator),
  );

  testWidgets('opens on the overview and switches between the tabs', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byType(NavigationRail), findsNothing);
    expect(location(tester), AppRoutes.overview);

    await openTab(tester, en.tabUpcoming);
    expect(find.byType(UpcomingScreen), findsOneWidget);
    expect(find.byType(OverviewScreen), findsNothing);
    expect(location(tester), AppRoutes.upcoming);

    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.byType(OverviewScreen), findsNothing);
    expect(location(tester), AppRoutes.projects);

    await openTab(tester, en.tabAccount);
    expect(find.byType(AccountTab), findsOneWidget);
    expect(find.text('Alice Example'), findsOneWidget);
    expect(location(tester), AppRoutes.account);

    await openTab(tester, en.tabOverview);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  testWidgets('a tab keeps its navigation stack while another is shown', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(location(tester), AppRoutes.project(1));

    await openTab(tester, en.tabOverview);
    expect(find.byType(OverviewScreen), findsOneWidget);
    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(location(tester), AppRoutes.project(1));

    // Re-selecting the tab returns to its first screen.
    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectTasksScreen), findsNothing);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(location(tester), AppRoutes.projects);
  });

  testWidgets('system back leaves a project for the project list', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ProjectTasksScreen), findsNothing);
    expect(find.byType(ProjectsScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('system back on another tab returns to the overview', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(ProjectsScreen), findsNothing);
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('the app bar of a project offers a back button', (tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('an unknown project id falls back to the project list', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, now: now);

    containerOf(tester).read(appRouterProvider).go('/home/projects/abc');
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.projects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('/home opens the overview', (tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  group('navigation', () {
    const wide = Size(800, 600);
    const landscapePhone = Size(740, 360);

    int? railIndex(WidgetTester tester) => tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .selectedIndex;

    for (final (name, size) in [('phone', phoneSize), ('wide window', wide)]) {
      testWidgets('iOS keeps the Cupertino tab bar in a $name', (tester) async {
        usePhoneSurface(tester, logicalSize: size);
        await pumpSignedInApp(tester, sync: data, now: now);

        expect(find.byType(CupertinoTabBar), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);

        await openTab(tester, en.tabProjects);
        expect(find.byType(ProjectsScreen), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    testWidgets('a wide window on Android has the rail with every label '
        'beside the content', (tester) async {
      usePhoneSurface(tester, logicalSize: wide);
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final railWidget = tester.widget<NavigationRail>(
        find.byType(NavigationRail),
      );
      expect(railWidget.destinations, hasLength(4));
      expect(railWidget.labelType, NavigationRailLabelType.all);
      for (final label in [en.tabUpcoming, en.tabProjects, en.tabAccount]) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(railIndex(tester), 0);
      final rail = tester.getRect(find.byType(NavigationRail));
      final content = tester.getRect(find.byType(OverviewScreen));
      expect(rail.left, 0);
      expect(content.left, greaterThan(rail.right));
      expect(content.bottom, wide.height);

      await openTab(tester, en.tabProjects);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(railIndex(tester), 2);
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTasksScreen), findsOneWidget);

      // Re-selecting the tab returns to its first screen.
      await openTab(tester, en.tabProjects);
      expect(find.byType(ProjectTasksScreen), findsNothing);
      expect(find.byType(ProjectsScreen), findsOneWidget);

      await openTab(tester, en.tabAccount);
      expect(find.byType(AccountTab), findsOneWidget);
      expect(railIndex(tester), 3);

      // System back on another tab's root returns to the first tab.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(OverviewScreen), findsOneWidget);
      expect(railIndex(tester), 0);
    });

    testWidgets('a phone turned to landscape gets the rail and every tab '
        'keeps its place', (tester) async {
      usePhoneSurface(tester);
      await pumpSignedInApp(tester, sync: data, now: now);
      await openTab(tester, en.tabProjects);
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      usePhoneSurface(tester, logicalSize: landscapePhone);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(railIndex(tester), 2);
      expect(location(tester), AppRoutes.project(1));

      usePhoneSurface(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      await openTab(tester, en.tabOverview);
      await openTab(tester, en.tabProjects);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('an account switch puts the rail back on the overview and '
        'every tab at its first screen', (tester) async {
      usePhoneSurface(tester, logicalSize: wide);
      final auth = AuthFakes();
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        displayName: 'Bob',
        activate: false,
      );
      data.accounts[bob.id] = AccountDataFakes(now: now)
        ..projects.all = [sampleProject(id: 7, title: 'Bob project')];
      await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
      await openTab(tester, en.tabProjects);
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
      await tester.pumpAndSettle();

      expect(find.byType(OverviewScreen), findsOneWidget);
      expect(railIndex(tester), 0);
      await openTab(tester, en.tabProjects);
      expect(find.byType(ProjectTasksScreen), findsNothing);
      expect(find.text('Bob project'), findsOneWidget);
    });

    testWidgets('the system insets go to the bar, the rail and the offline '
        'banner, never twice to the content', (tester) async {
      usePhoneSurface(tester);
      tester.view.padding = const FakeViewPadding(bottom: 24 * 3);
      await pumpSignedInApp(tester, sync: data, now: now);
      EdgeInsets contentPadding() =>
          MediaQuery.paddingOf(tester.element(find.byType(OverviewScreen)));
      expect(contentPadding().bottom, 0);

      usePhoneSurface(tester, logicalSize: landscapePhone);
      tester.view.padding = const FakeViewPadding(left: 40 * 3, bottom: 20 * 3);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(contentPadding().left, 0);
      expect(contentPadding().bottom, 20);

      data.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(contentPadding().bottom, 0);
      final banner = tester.getRect(find.byType(OfflineBanner));
      expect(banner.bottom, landscapePhone.height);
      final icon = tester.getRect(
        find.descendant(
          of: find.byType(OfflineBanner),
          matching: find.byIcon(Icons.cloud_off_outlined),
        ),
      );
      expect(icon.bottom, lessThanOrEqualTo(landscapePhone.height - 20));
      expect(icon.left - banner.left, 16);
    });

    testWidgets('a rotation keeps the offline banner, which screen readers '
        'would otherwise hear again', (tester) async {
      usePhoneSurface(tester);
      await pumpSignedInApp(tester, sync: data, now: now);
      data.engine.emit(
        SyncFailed(
          failure: const NetworkFailure(NetworkProblem.unreachable),
          lastSyncedAt: now,
        ),
      );
      await tester.pumpAndSettle();
      final banner = tester.element(find.byType(OfflineBanner));

      usePhoneSurface(tester, logicalSize: landscapePhone);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.element(find.byType(OfflineBanner)), same(banner));

      usePhoneSurface(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.element(find.byType(OfflineBanner)), same(banner));
    });

    testWidgets("beside the rail a tab's snackbar leaves the rail free", (
      tester,
    ) async {
      usePhoneSurface(tester, logicalSize: landscapePhone);
      data.tasks.all = [sampleTask(id: 1, title: 'Call mom')];
      await pumpSignedInApp(tester, sync: data, now: now);

      await tester.tap(find.byTooltip(en.taskMarkDone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        tester.getRect(find.byType(SnackBar)).left,
        greaterThan(tester.getRect(find.byType(NavigationRail)).right),
      );
    });

    testWidgets('the rail labels are in German', (tester) async {
      useLocale(tester, const Locale('de'));
      usePhoneSurface(tester, logicalSize: wide);
      await pumpSignedInApp(tester, sync: data, now: now);

      for (final label in [
        de.tabOverview,
        de.tabUpcoming,
        de.tabProjects,
        de.tabAccount,
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    });
  });

  testWidgets('the tab labels are in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.text(de.tabOverview), findsAtLeast(1));
    expect(find.text(de.tabUpcoming), findsOneWidget);
    expect(find.text(de.tabProjects), findsOneWidget);
    expect(find.text(de.tabAccount), findsOneWidget);
  });

  group('quiet sync', () {
    testWidgets('a sync after the first shows a slim bar under the app bar', (
      tester,
    ) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      final run = Completer<void>();
      data.engine.onRefresh = () => run.future;
      expect(progressBar(find.byType(OverviewScreen)), findsNothing);

      await tester.tap(find.byTooltip(en.refresh));
      await tester.pump();

      expect(progressBar(find.byType(OverviewScreen)), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        progressBar(find.byType(OverviewScreen)),
      );
      expect(bar.semanticsLabel, en.syncIndicatorLabel);
      expect(bar.value, isNull);

      // No settling: the bar animates until the run ends.
      await tester.tap(find.text(en.tabAccount));
      await pumpFrames(tester, 2);
      expect(progressBar(find.byType(AccountTab)), findsOneWidget);

      run.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('runs at start when the last sync is older than a minute', (
      tester,
    ) async {
      data = SyncFakes(
        now: now,
        status: SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 1))),
      );
      final run = Completer<void>();
      data.engine.onRefresh = () => run.future;

      await pumpSignedInApp(tester, sync: data, now: now, settle: false);
      await pumpUntil(tester, progressBar(find.byType(OverviewScreen)));

      expect(data.engine.refreshCalls, 1);
      expect(find.byType(HomeShell), findsOneWidget);

      run.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('is skipped right after a sync', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(data.engine.refreshCalls, 0);
    });

    testWidgets('retries at start after a failed sync', (tester) async {
      data = SyncFakes(
        now: now,
        status: SyncFailed(
          failure: const ServerFailure(502),
          lastSyncedAt: now.subtract(const Duration(minutes: 1)),
        ),
      );

      await pumpSignedInApp(tester, sync: data, now: now);

      expect(data.engine.refreshCalls, 1);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('does not run for a session that needs a new sign-in', (
      tester,
    ) async {
      data = SyncFakes(
        now: now,
        status: SyncIdle(lastSyncedAt: now.subtract(const Duration(hours: 1))),
      );
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );

      await pumpVikunjaApp(tester, auth: auth, sync: data);

      expect(find.byType(HomeShell), findsOneWidget);
      expect(data.engine.refreshCalls, 0);
    });
  });

  group('foreground sync', () {
    const minute = Duration(seconds: 60);

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    const leave = [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ];
    const comeBack = [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ];

    testWidgets('syncs a minute after the last run while the app is in '
        'front', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      expect(data.engine.refreshCalls, 0);

      await tester.pump(const Duration(seconds: 30));
      expect(data.engine.refreshCalls, 0);
      await tester.pump(const Duration(seconds: 30));
      expect(data.engine.refreshCalls, 1);
      expect(data.engine.fullResyncCalls, 0);
      await tester.pumpAndSettle();

      await tester.pump(minute);
      expect(data.engine.refreshCalls, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('switching tabs neither restarts the wait nor pulls the '
        'activity again', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      expect(data.foregroundActivityRuns, 1);

      await tester.pump(const Duration(seconds: 40));
      await openTab(tester, en.tabUpcoming);
      await openTab(tester, en.tabAccount);
      await openTab(tester, en.tabOverview);
      await tester.pump(const Duration(seconds: 20));

      expect(data.engine.refreshCalls, 1);
      expect(data.foregroundActivityRuns, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('waits longer while the server is unreachable', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      data.engine.onRefresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);

      await tester.pump(minute);
      await tester.pumpAndSettle();
      expect(data.engine.refreshCalls, 1);

      await tester.pump(minute);
      expect(data.engine.refreshCalls, 1);
      await tester.pump(minute);
      await tester.pumpAndSettle();
      expect(data.engine.refreshCalls, 2);
    });

    testWidgets('nothing runs in the background; coming back after more than '
        'a minute syncs', (tester) async {
      var current = now;
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [clockProvider.overrideWithValue(() => current)],
      );

      lifecycle(tester, leave);
      await tester.pump(const Duration(minutes: 5));
      expect(data.engine.refreshCalls, 0);

      current = now.add(const Duration(minutes: 5));
      lifecycle(tester, comeBack);
      await tester.pumpAndSettle();
      expect(data.engine.refreshCalls, 1);
    });

    testWidgets('coming back within a minute lets the timer finish the wait', (
      tester,
    ) async {
      var current = now;
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [clockProvider.overrideWithValue(() => current)],
      );

      lifecycle(tester, leave);
      current = now.add(const Duration(seconds: 30));
      lifecycle(tester, comeBack);
      await tester.pumpAndSettle();
      expect(data.engine.refreshCalls, 0);

      await tester.pump(const Duration(seconds: 30));
      expect(data.engine.refreshCalls, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('signing out stops it', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      await openTab(tester, en.tabAccount);
      await tapInAccountTab(tester, en.homeSignOut);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsNothing);

      await tester.pump(const Duration(minutes: 5));

      expect(data.engine.refreshCalls, 0);
    });

    testWidgets('does not run for a session that needs a new sign-in', (
      tester,
    ) async {
      final auth = AuthFakes();
      await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
        needsReauth: true,
      );
      await pumpVikunjaApp(tester, auth: auth, sync: data);

      await tester.pump(const Duration(minutes: 5));

      expect(data.engine.refreshCalls, 0);
    });

    testWidgets('rests while the shell is gone: an unsynced account that '
        'becomes active on sign-out and is cancelled on its first-sync '
        'screen starts nothing', (tester) async {
      final auth = AuthFakes();
      final bob = await auth.seedAccount(
        fullServer270(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        displayName: 'Bob',
        activate: false,
      );
      // Offline: the first sync fails at once, so the first-sync screen
      // shows the failure and the scheduler's timer keeps looking again.
      final bobData = AccountDataFakes(now: now, status: const SyncNeverRun());
      bobData.engine.onEnsureInitialSync = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      data.accounts[bob.id] = bobData;
      await pumpSignedInApp(tester, sync: data, auth: auth, now: now);

      await openTab(tester, en.tabAccount);
      await tapInAccountTab(tester, en.homeSignOutOfThisAccount);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FirstSyncScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(bobData.engine.ensureInitialSyncCalls, 1);
      expect(find.text(en.accountSignedOutOf('Alice Example')), findsOneWidget);

      // The snackbar covers the button.
      ScaffoldMessenger.of(tester.element(find.byType(FirstSyncScreen)))
          .removeCurrentSnackBar();
      await tester.ensureVisible(find.text(en.firstSyncCancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.firstSyncCancel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConnectServerScreen), findsOneWidget);

      // Signed out and no longer in need of a first sync: a timer still
      // alive would start a run now.
      bobData.engine.emit(SyncIdle(lastSyncedAt: now));
      await tester.pump(const Duration(minutes: 5));

      expect(bobData.engine.refreshCalls, 0);
      expect(data.engine.refreshCalls, 0);
    });
  });

  group('realtime', () {
    setUp(() => data.realtime.accepts = true);

    testWidgets("the shell keeps the active account's socket open", (
      tester,
    ) async {
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(data.realtime.urls, [
        Uri.parse('wss://tasks.example.org/vikunja/api/v2/ws'),
      ]);
      expect(
        containerOf(tester).read(realtimeConnectionProvider)?.state,
        RealtimeState.live,
      );
    });

    testWidgets('switching tabs keeps the socket', (tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);

      await openTab(tester, en.tabUpcoming);
      await openTab(tester, en.tabAccount);
      await openTab(tester, en.tabOverview);

      expect(data.realtime.connectCalls, 1);
      expect(data.realtime.lastSocket.isClosed, isFalse);
    });

    testWidgets('signing out closes the socket before the logout request, '
        'and the close the logout causes is ignored', (tester) async {
      final auth = AuthFakes();
      int? closedAtLogout;
      auth.accountGateway.onLogout = (_) async {
        final socket = data.realtime.lastSocket;
        closedAtLogout = socket.closedWith;
        socket.serverClose(1008, 'session revoked');
      };
      await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
      data.realtime.lastSocket.awaitsServerClose = true;

      await openTab(tester, en.tabAccount);
      await tapInAccountTab(tester, en.homeSignOut);
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsNothing);
      expect(closedAtLogout, 1000);
      expect(auth.tokenGateway.refreshedTokens, isEmpty);
      expect(data.realtime.connectCalls, 1);
    });

    testWidgets('a session revoked elsewhere reaches the session manager, '
        'which asks for a new sign-in', (tester) async {
      final auth = AuthFakes();
      auth.tokenGateway.onRefresh = (_) async =>
          throw const SessionEnded(SessionEndReason.expired);
      await pumpSignedInApp(tester, sync: data, auth: auth, now: now);

      data.realtime.lastSocket.serverClose(1008, 'session revoked');
      await tester.pumpAndSettle();

      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      final accounts = containerOf(tester).read(accountsProvider).value!;
      expect(accounts.activeAccount!.account.needsReauth, isTrue);
      expect(containerOf(tester).read(realtimeConnectionProvider), isNull);
      expect(data.realtime.connectCalls, 1);
    });
  });
}
