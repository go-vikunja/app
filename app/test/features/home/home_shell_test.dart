import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

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

  Finder progressBar(Finder screen) => find.descendant(
    of: find.descendant(of: screen, matching: find.byType(SyncProgressBar)),
    matching: find.byType(LinearProgressIndicator),
  );

  testWidgets('opens on the overview and switches between the tabs', (
    tester,
  ) async {
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(location(tester), AppRoutes.overview);

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

  testWidgets('uses the Cupertino tab bar on iOS', (tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the tab labels are in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.text(de.tabOverview), findsAtLeast(1));
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
}
