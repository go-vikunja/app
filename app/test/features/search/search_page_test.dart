import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final reporting = sampleLabel(id: 5, title: 'Reporting', hexColor: '1973ff');
  late SyncFakes data;

  SyncFakes sampleData({SyncStatus? status}) {
    final data = SyncFakes(now: now, status: status);
    data.projects.all = [
      sampleProject(id: 1, title: 'Office', identifier: 'OFF'),
      sampleProject(id: 2, title: 'Reports'),
      sampleProject(id: 3, title: 'Old', archived: true),
    ];
    data.projects.savedFilters = const [
      SavedFilterRef(projectId: -2, title: 'Reports due'),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Report draft', done: true),
      sampleTask(
        id: 2,
        title: 'Quarterly report',
        due: now.add(const Duration(days: 1)),
        labels: [reporting],
      ),
      sampleTask(
        id: 3,
        title: 'Notes',
        description: '<p>The report is attached</p>',
        projectId: 2,
      ),
      sampleTask(id: 4, title: 'Old report', projectId: 3, labels: [reporting]),
      sampleTask(id: 12, title: 'Twelve'),
    ];
    data.tasks.archivedProjectIds = {3};
    data.search.labels = [reporting, sampleLabel(id: 6, title: 'Home')];
    return data;
  }

  setUp(() => data = sampleData());

  Future<void> pumpApp(WidgetTester tester) => pumpSignedInApp(
    tester,
    sync: data,
    now: now,
    overrides: [
      labelRepositoryProvider.overrideWithValue(
        FakeLabelRepository(labels: data.search.labels),
      ),
    ],
  );

  Future<void> openSearch(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip(en.search));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchPage),
        matching: find.byType(TextField),
      ),
      query,
    );
    await tester.pumpAndSettle();
  }

  List<String> headings(WidgetTester tester) => [
    for (final header in tester.widgetList<ListSectionHeader>(
      find.byType(ListSectionHeader),
    ))
      header.title,
  ];

  List<String> taskTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      row.task.title,
  ];

  testWidgets('opens from the Overview, Upcoming and Projects, and says '
      'what it finds before anything is typed', (tester) async {
    await pumpApp(tester);

    for (final tab in [null, en.tabUpcoming, en.tabProjects]) {
      if (tab != null) await openTab(tester, tab);
      await tester.tap(find.byTooltip(en.search));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.text(en.searchStartTitle), findsOneWidget);
      expect(find.text(en.searchStartBody), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsNothing);
    }
  });

  testWidgets('groups tasks, projects, saved filters and labels, open tasks '
      'first, then by due date; archived projects stay out', (tester) async {
    await openSearch(tester);

    await search(tester, 'REPORT');

    expect(headings(tester), [
      en.searchTasks,
      en.searchProjects,
      en.savedFiltersHeading,
      en.searchLabels,
    ]);
    expect(taskTitles(tester), ['Quarterly report', 'Notes', 'Report draft']);
    expect(
      tester
          .widget<ListSectionHeader>(
            find.widgetWithText(ListSectionHeader, en.searchTasks),
          )
          .count,
      3,
    );
    expect(
      find.descendant(
        of: find.byType(ProjectRow),
        matching: find.text('Reports'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reports due'), findsOneWidget);
    expect(find.byKey(const ValueKey(('label', 5))), findsOneWidget);
    expect(find.text('Old report'), findsNothing);
  });

  testWidgets('#12 finds index 12 in any project, OFF-12 the task with that '
      'identifier', (tester) async {
    await openSearch(tester);

    await search(tester, '#12');
    expect(taskTitles(tester), ['Twelve']);

    await search(tester, 'off-12');
    expect(taskTitles(tester), ['Twelve']);
  });

  testWidgets('nothing found says so', (tester) async {
    await openSearch(tester);

    await search(tester, 'zebra');

    expect(find.text(en.searchNoResultsTitle), findsOneWidget);
    expect(find.text(en.searchNoResultsBody('zebra')), findsOneWidget);
  });

  testWidgets('clearing the field starts over', (tester) async {
    await openSearch(tester);
    await search(tester, 'report');

    await tester.tap(find.byTooltip(en.clearSearch));
    await tester.pumpAndSettle();

    expect(find.text(en.searchStartTitle), findsOneWidget);
    expect(find.byType(TaskRow), findsNothing);
  });

  testWidgets('works offline, from this device alone', (tester) async {
    data = sampleData(
      status: SyncFailed(
        failure: const NetworkFailure(NetworkProblem.unreachable),
        lastSyncedAt: now,
      ),
    );
    await openSearch(tester);

    await search(tester, 'quarterly');

    expect(taskTitles(tester), ['Quarterly report']);
  });

  testWidgets('beyond the shown tasks it says how many more match', (
    tester,
  ) async {
    data.tasks.all = [
      for (var id = 1; id <= SearchResults.maxTasks + 5; id++)
        sampleTask(id: id, title: 'Step $id'),
    ];
    await openSearch(tester);

    await search(tester, 'step');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -50000));
    await tester.pumpAndSettle();

    expect(find.text(en.searchMoreTasks(5)), findsOneWidget);
  });

  testWidgets('the number of results is announced once typing pauses', (
    tester,
  ) async {
    await openSearch(tester);
    tester.takeAnnouncements();

    await search(tester, 'report');
    await tester.pump(SearchPage.announceDelay);

    expect(
      tester.takeAnnouncements(),
      contains(isAccessibilityAnnouncement(en.searchResultCount(6))),
    );
  });

  testWidgets('gets ready as it opens and shows progress until then', (
    tester,
  ) async {
    final indexing = data.search.indexing = Completer<void>();
    await pumpApp(tester);
    // The progress bar runs until the search is ready, so nothing settles.
    await tester.tap(find.byTooltip(en.search));
    await pumpFrames(tester, 10);

    expect(data.search.queries, ['']);
    expect(find.bySemanticsLabel(en.searchPreparing), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(SearchPage),
        matching: find.byType(TextField),
      ),
      'quarterly',
    );
    await pumpFrames(tester, 3);
    expect(find.byType(TaskRow), findsNothing);

    indexing.complete();
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(en.searchPreparing), findsNothing);
    expect(taskTitles(tester), ['Quarterly report']);
  });

  group('opens', () {
    testWidgets('a task in its sheet over the search', (tester) async {
      await openSearch(tester);
      await search(tester, 'quarterly');

      await tester.tap(find.text('Quarterly report'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.byType(SearchPage), findsOneWidget);
    });

    testWidgets('a project in the Projects tab; the search opens again with '
        'the query', (tester) async {
      await openSearch(tester);
      await search(tester, 'office');

      await tester.tap(find.text('Office'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Office'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(en.search));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(SearchPage),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'office');
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
      expect(find.byType(ProjectRow), findsOneWidget);
    });

    testWidgets('a saved filter as its list', (tester) async {
      await openSearch(tester);
      await search(tester, 'due');

      await tester.tap(find.text('Reports due'));
      await tester.pumpAndSettle();

      expect(find.byType(SmartListScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Reports due'), findsOneWidget);
    });

    testWidgets("a label as its open tasks in a saved filter's scope: outside "
        'archived projects, and favourites anywhere; back returns to the '
        'search', (tester) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(
          id: 13,
          title: 'Old favourite report',
          projectId: 3,
          labels: [reporting],
          favorite: true,
        ),
      ];
      await openSearch(tester);
      await search(tester, 'reporting');

      await tester.tap(find.byKey(const ValueKey(('label', 5))));
      await tester.pumpAndSettle();

      expect(find.byType(LabelTasksScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Reporting'), findsOneWidget);
      expect(taskTitles(tester), ['Quarterly report', 'Old favourite report']);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
    });

    testWidgets('a label without open tasks says so', (tester) async {
      await openSearch(tester);
      await search(tester, 'home');

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text(en.labelTasksEmptyTitle), findsOneWidget);
      expect(find.text(en.labelTasksEmptyBody('Home')), findsOneWidget);
    });
  });
}
