import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/application/smart_list_providers.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_row.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

Future<void> refreshFromMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip(en.moreActions));
  await tester.pumpAndSettle();
  await tester.tap(find.text(en.refresh));
}

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

    await refreshFromMenu(tester);
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

  testWidgets('Refresh in the menu runs a sync without a drag', (tester) async {
    await pumpProjects(tester);
    data.engine.onRefresh = () async =>
        data.projects.all = [sampleProject(id: 9, title: 'Fresh')];

    await refreshFromMenu(tester);
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
    await refreshFromMenu(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();
    await openTab(tester, en.tabProjects);

    expect(find.byType(DataFailureCard), findsNothing);
    expect(rowTitles(tester), ['Bob project']);
  });

  group('sections', () {
    final filters = [
      const SavedFilterRef(projectId: -2, title: 'Zeta', isFavorite: true),
      const SavedFilterRef(projectId: -3, title: 'alpha'),
      const SavedFilterRef(projectId: -4, title: 'My Open Tasks'),
    ];

    final favoritesRow = find.widgetWithText(
      SmartListRow,
      en.projectsFavouriteTasks,
    );

    List<String> headings(WidgetTester tester) => [
      for (final header in tester.widgetList<ListSectionHeader>(
        find.byType(ListSectionHeader),
      ))
        header.title,
    ];

    /// Every row's title in order, smart lists and projects alike.
    List<String> rows(WidgetTester tester) => [
      for (final element
          in find
              .byWidgetPredicate((w) => w is SmartListRow || w is ProjectRow)
              .evaluate())
        switch (element.widget) {
          final SmartListRow row => row.title,
          final ProjectRow row => row.project.title,
          _ => '',
        },
    ];

    testWidgets('the favourites first (the Favorites list, favourite saved '
        'filters and projects), then every saved filter by title, then the '
        'tree', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1600));
      data.projects.savedFilters = filters;
      data.tasks.all = [
        sampleTask(id: 1, title: 'Starred', favorite: true),
        sampleTask(id: 2, title: 'Also starred', favorite: true),
        sampleTask(id: 3, title: 'Plain'),
      ];
      await pumpProjects(tester);

      expect(headings(tester), [
        en.projectsFavouritesHeading,
        en.savedFiltersHeading,
        en.projectsAllHeading,
      ]);
      expect(rows(tester), [
        en.projectsFavouriteTasks,
        'Zeta',
        'Home',
        'alpha',
        en.savedFilterMyOpenTasks,
        'Zeta',
        'Home',
        'Work',
        'Admin',
        'Reports',
      ]);
      expect(find.text(en.smartListOpenTaskCount(2)), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsNWidgets(4));
    });

    testWidgets('the Favorites row is not named like the heading above it, '
        'its list keeps the name', (tester) async {
      data.tasks.all = [sampleTask(id: 1, title: 'Starred', favorite: true)];
      await pumpProjects(tester);

      expect(find.text(en.projectsFavouritesHeading), findsOneWidget);
      expect(favoritesRow, findsOneWidget);

      await tester.tap(favoritesRow);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, en.projectFavouritesTitle),
        findsOneWidget,
      );
    });

    testWidgets('the tree waits for the sections above it rather than jump '
        'down when they arrive', (tester) async {
      final filters = StreamController<List<SavedFilterRef>>();
      addTearDown(filters.close);
      await pumpSignedInApp(
        tester,
        sync: data,
        now: now,
        overrides: [savedFiltersProvider.overrideWith((ref) => filters.stream)],
      );
      await tester.tap(find.text(en.tabProjects));
      await pumpFrames(tester, 5);

      expect(find.byType(ProjectRow), findsNothing);
      expect(find.text(en.projectsLoading), findsOneWidget);

      filters.add(const [SavedFilterRef(projectId: -2, title: 'Zeta')]);
      await tester.pumpAndSettle();
      expect(headings(tester), [
        en.projectsFavouritesHeading,
        en.savedFiltersHeading,
        en.projectsAllHeading,
      ]);
    });

    testWidgets('the Favorites list shows only while a task is a favourite', (
      tester,
    ) async {
      data.tasks.all = [sampleTask(id: 1, title: 'Plain')];
      await pumpProjects(tester);
      expect(favoritesRow, findsNothing);

      data.tasks.all = [sampleTask(id: 1, title: 'Plain', favorite: true)];
      await tester.pumpAndSettle();
      expect(favoritesRow, findsOneWidget);
      expect(find.text(en.smartListOpenTaskCount(1)), findsOneWidget);

      data.tasks.all = [sampleTask(id: 1, title: 'Plain', done: true)];
      await tester.pumpAndSettle();
      expect(favoritesRow, findsNothing);
    });

    testWidgets('without saved filters there is no such section', (
      tester,
    ) async {
      await pumpProjects(tester);

      expect(headings(tester), [
        en.projectsFavouritesHeading,
        en.projectsAllHeading,
      ]);
    });

    testWidgets('only saved filters are no empty state', (tester) async {
      data.projects.all = [];
      data.projects.savedFilters = [filters[1]];
      await pumpProjects(tester);

      expect(find.text(en.projectsEmptyTitle), findsNothing);
      expect(headings(tester), [en.savedFiltersHeading]);
    });

    testWidgets('the Favorites list and a saved filter open as lists', (
      tester,
    ) async {
      data.projects.savedFilters = filters;
      data.tasks.all = [sampleTask(id: 1, title: 'Starred', favorite: true)];
      await pumpProjects(tester);

      await tester.tap(favoritesRow);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SmartListScreen>(find.byType(SmartListScreen))
            .pseudoProjectId,
        -1,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SmartListScreen>(find.byType(SmartListScreen))
            .pseudoProjectId,
        -3,
      );
      expect(find.byType(ProjectTasksScreen), findsNothing);
    });

    testWidgets('are in German', (tester) async {
      useLocale(tester, const Locale('de'));
      data.projects.savedFilters = filters;
      data.tasks.all = [sampleTask(id: 1, title: 'Starred', favorite: true)];
      await pumpSignedInApp(tester, sync: data, now: now);
      await openTab(tester, de.tabProjects);

      expect(headings(tester), [
        de.projectsFavouritesHeading,
        de.savedFiltersHeading,
        de.projectsAllHeading,
      ]);
      expect(find.text(de.projectsFavouriteTasks), findsOneWidget);
      expect(find.text(de.savedFilterMyOpenTasks), findsOneWidget);
      expect(find.text(de.smartListOpenTaskCount(1)), findsOneWidget);
    });
  });

  group('archived projects', () {
    Future<void> toggleArchived(WidgetTester tester) async {
      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text(en.projectsShowArchived),
          matching: find.byWidgetPredicate(
            (widget) => widget is CheckedPopupMenuItem,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      data.projects.all = [
        ...tree(),
        sampleProject(id: 6, title: 'Old notes', parent: 5, archived: true),
      ];
    });

    testWidgets('the menu shows them in the tree, marked, and hides them '
        'again; the choice is kept for the account', (tester) async {
      await pumpProjects(tester);
      expect(find.text('Old'), findsNothing);

      await toggleArchived(tester);

      // By position; the archived ones come first here.
      expect(rowTitles(tester), [
        'Home',
        'Old',
        'Old notes',
        'Home',
        'Work',
        'Admin',
        'Reports',
      ]);
      expect(
        find.descendant(
          of: find.widgetWithText(ProjectRow, 'Old notes'),
          matching: find.byIcon(Icons.archive_outlined),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<Icon>(find.byIcon(Icons.archive_outlined))
            .map((icon) => icon.semanticLabel),
        [en.projectArchived, en.projectArchived],
      );
      expect(data.listPreferences.projectTree.showArchived, isTrue);
      expect(data.listPreferences.saves, ['projectTree']);

      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckedPopupMenuItem<Object?>>(
              find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
            )
            .checked,
        isTrue,
      );
      await tester.tap(
        find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      );
      await tester.pumpAndSettle();

      expect(find.text('Old'), findsNothing);
      expect(data.listPreferences.projectTree.showArchived, isFalse);
    });

    testWidgets('shown at start when the account chose so', (tester) async {
      data.listPreferences.setProjectTree(
        const ProjectTreePreferences(showArchived: true),
      );
      await pumpProjects(tester);

      expect(find.text('Old'), findsOneWidget);
    });

    testWidgets('an archived project says so and offers no new task; its '
        'rows show done and favourite without changing them', (tester) async {
      data.tasks.all = [
        sampleTask(id: 1, title: 'Old idea', projectId: 6),
        sampleTask(id: 2, title: 'Live task'),
      ];
      await pumpProjects(tester);
      await toggleArchived(tester);

      await tester.tap(find.text('Old notes'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(find.text(en.projectArchivedNote), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      final archivedRow = tester.widget<TaskRow>(
        find.widgetWithText(TaskRow, 'Old idea'),
      );
      expect(archivedRow.onDoneChanged, isNull);
      expect(archivedRow.onFavoriteChanged, isNull);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text(en.projectArchivedNote), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      final liveRow = tester.widget<TaskRow>(
        find.widgetWithText(TaskRow, 'Live task'),
      );
      expect(liveRow.onDoneChanged, isNotNull);
      expect(liveRow.onFavoriteChanged, isNotNull);
    });
  });

  testWidgets('the collapsed projects are kept for the account', (
    tester,
  ) async {
    data.listPreferences.setProjectTree(
      const ProjectTreePreferences(collapsed: {1}),
    );
    await pumpProjects(tester);
    expect(rowTitles(tester), ['Home', 'Home', 'Work']);

    await tester.tap(find.byTooltip(en.projectExpand('Work')));
    await tester.pumpAndSettle();

    expect(rowTitles(tester), ['Home', 'Home', 'Work', 'Admin', 'Reports']);
    expect(data.listPreferences.projectTree.collapsed, isEmpty);
    expect(data.listPreferences.saves, ['projectTree']);
  });
}
