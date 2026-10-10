import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  List<Project> tree() => [
    sampleProject(id: 1, title: 'Work', position: 200, hexColor: '1973ff'),
    sampleProject(id: 2, title: 'Home', position: 100, favorite: true),
    sampleProject(id: 3, title: 'Reports', parent: 1, position: 20),
    sampleProject(id: 4, title: 'Admin', parent: 1, position: 10),
    sampleProject(id: 5, title: 'Old', archived: true),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = tree();
  });

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<ProjectRow>(find.byType(ProjectRow)))
      row.project.title,
  ];

  Future<void> pumpProjects(WidgetTester tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabProjects);
  }

  testWidgets('shows favourites first, then the tree by position', (
    tester,
  ) async {
    await pumpProjects(tester);

    expect(find.text(en.projectsFavouritesHeading), findsOneWidget);
    expect(find.text(en.projectsAllHeading), findsOneWidget);
    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
    expect(find.text('Old'), findsNothing);
    expect(find.text(en.projectChildCount(2)), findsOneWidget);
    final stars = tester.widgetList<Icon>(find.byIcon(Icons.star));
    expect(stars.map((icon) => icon.semanticLabel), [
      en.favouriteLabel,
      en.favouriteLabel,
    ]);
  });

  testWidgets('children are indented and can be collapsed', (tester) async {
    await pumpProjects(tester);
    final parentLeft = tester.getTopLeft(find.text('Work')).dx;
    final childLeft = tester.getTopLeft(find.text('Admin')).dx;
    expect(childLeft, greaterThan(parentLeft));

    await tester.tap(find.byTooltip(en.projectCollapse('Work')));
    await tester.pumpAndSettle();
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    await tester.tap(find.byTooltip(en.projectExpand('Work')));
    await tester.pumpAndSettle();
    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
  });

  testWidgets('tapping a project opens its tasks', (tester) async {
    await pumpProjects(tester);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectTasksScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Reports'), findsOneWidget);
  });

  testWidgets('without projects shows the empty state', (tester) async {
    data.projects.all = [];
    await pumpProjects(tester);

    expect(find.text(en.projectsEmptyTitle), findsOneWidget);
  });

  testWidgets('a refresh the server fails is explained above the list', (
    tester,
  ) async {
    await pumpProjects(tester);
    data.engine.onRefresh = () async => throw const ServerFailure(502);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(
      find.text(en.failureUnavailableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(find.text('Work'), findsOneWidget);

    data.engine.onRefresh = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('pull to refresh runs a sync, whose result shows', (
    tester,
  ) async {
    await pumpProjects(tester);
    data.engine.onRefresh = () async =>
        data.projects.all = [sampleProject(id: 9, title: 'Fresh')];

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(rowTitles(tester), ['Fresh']);
    expect(data.engine.refreshCalls, 1);
  });

  testWidgets('the app bar button refreshes without a drag', (tester) async {
    await pumpProjects(tester);
    data.engine.onRefresh = () async =>
        data.projects.all = [sampleProject(id: 9, title: 'Fresh')];

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(rowTitles(tester), ['Fresh']);
    expect(data.engine.refreshCalls, 1);
  });

  testWidgets('a failure notice and collapsed state do not outlive the '
      'account', (tester) async {
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(
        issuedAt: DateTime.now().toUtc(),
        userId: 8,
        username: 'bob',
      ),
      activate: false,
    );
    data.accounts[bob.id] = AccountDataFakes(now: now)
      ..projects.all = [sampleProject(id: 7, title: 'Bob project')];
    await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
    await openTab(tester, en.tabProjects);
    await tester.tap(find.byTooltip(en.projectCollapse('Work')));
    await tester.pumpAndSettle();
    data.engine.onRefresh = () async => throw const ServerFailure(502);
    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();

    expect(find.byType(DataFailureCard), findsNothing);
    expect(rowTitles(tester), ['Bob project']);
  });
}
