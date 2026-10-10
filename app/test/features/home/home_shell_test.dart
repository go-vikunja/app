import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';

import '../../helpers/fake_read_client.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  late FakeReadClient client;

  setUp(() {
    client = FakeReadClient();
    client.projects.all = [sampleProject(id: 1, title: 'Work')];
  });

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .toString();

  testWidgets('opens on the overview and switches between the tabs', (
    tester,
  ) async {
    await pumpSignedInApp(tester, readClient: client);

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
    await pumpSignedInApp(tester, readClient: client);
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
    await pumpSignedInApp(tester, readClient: client);
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
    await pumpSignedInApp(tester, readClient: client);
    await openTab(tester, en.tabProjects);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(find.byType(ProjectsScreen), findsNothing);
    expect(location(tester), AppRoutes.overview);
  });

  testWidgets('the app bar of a project offers a back button', (tester) async {
    await pumpSignedInApp(tester, readClient: client);
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
    await pumpSignedInApp(tester, readClient: client);

    containerOf(tester).read(appRouterProvider).go('/home/projects/abc');
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.projects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  });

  testWidgets('/home opens the overview', (tester) async {
    await pumpSignedInApp(tester, readClient: client);
    await openTab(tester, en.tabProjects);

    containerOf(tester).read(appRouterProvider).go(AppRoutes.home);
    await tester.pumpAndSettle();

    expect(location(tester), AppRoutes.overview);
    expect(find.byType(OverviewScreen), findsOneWidget);
  });

  testWidgets('uses the Cupertino tab bar on iOS', (tester) async {
    await pumpSignedInApp(tester, readClient: client);

    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await openTab(tester, en.tabProjects);
    expect(find.byType(ProjectsScreen), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the tab labels are in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpSignedInApp(tester, readClient: client);

    expect(find.text(de.tabOverview), findsAtLeast(1));
    expect(find.text(de.tabProjects), findsOneWidget);
    expect(find.text(de.tabAccount), findsOneWidget);
  });
}
