import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  final listView = sampleListView(id: 11, projectId: 1);
  final everything = sampleListView(
    id: 12,
    projectId: 1,
    title: 'Everything',
    position: 200,
    filter: '',
  );
  final urgent = sampleListView(
    id: 13,
    projectId: 1,
    title: 'Urgent',
    position: 300,
    filter: 'priority >= 4',
  );
  const kanban = ProjectView(
    id: 14,
    projectId: 1,
    title: 'Kanban',
    kind: ProjectViewKind.kanban,
    position: 400,
  );

  Project work({List<ProjectView>? views}) => sampleProject(
    id: 1,
    title: 'Work',
    views: views ?? [listView, everything, urgent, kanban],
  );

  List<Task> tasks() => [
    sampleTask(id: 1, title: 'Parent', subtaskIds: [2, 3]),
    sampleTask(id: 2, title: 'Open child', parentIds: [1], subtaskIds: [4]),
    sampleTask(
      id: 3,
      title: 'Done child',
      parentIds: [1],
      done: true,
      doneAt: now,
    ),
    sampleTask(id: 4, title: 'Grandchild', projectId: 2, parentIds: [2]),
    sampleTask(
      id: 5,
      title: 'Done parent',
      subtaskIds: [6],
      done: true,
      doneAt: now.subtract(const Duration(days: 1)),
    ),
    sampleTask(id: 6, title: 'Orphan', parentIds: [5]),
    sampleTask(id: 7, title: 'Seven', priority: TaskPriority.urgent),
    sampleTask(id: 8, title: 'Eight'),
    sampleTask(id: 9, title: 'Done nine', done: true, doneAt: now),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      work(),
      sampleProject(id: 2, title: 'Home', hexColor: '1973ff'),
    ];
    data.tasks.all = tasks();
    data.tasks.setSnapshot(
      'view:11',
      ListSnapshot(positions: const {7: 1, 1: 2, 8: 3, 6: 4}, loadedAt: now),
    );
  });

  Future<void> pumpProject(WidgetTester tester, {int id = 1}) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(id));
    await tester.pumpAndSettle();
  }

  List<(String, int)> rows(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      (row.task.title, row.depth),
  ];

  List<String> sectionTitles(WidgetTester tester) => [
    for (final header in tester.widgetList<ListSectionHeader>(
      find.byType(ListSectionHeader),
    ))
      header.title,
  ];

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
  }

  // The item's text sits under an IgnorePointer; the item itself takes taps.
  Future<void> toggleShowDone(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectView(WidgetTester tester, String title) async {
    await tester.tap(find.widgetWithText(ChoiceChip, title));
    await tester.pumpAndSettle();
  }

  testWidgets("shows the list view's open tasks in its positions, each "
      'followed by its subtasks', (tester) async {
    await pumpProject(tester);

    expect(find.widgetWithText(AppBar, 'Work'), findsOneWidget);
    expect(rows(tester), [
      ('Seven', 0),
      ('Parent', 0),
      ('Open child', 1),
      ('Grandchild', 2),
      ('Done child', 1),
      ('Eight', 0),
      ('Orphan', 0),
    ]);
    // A subtask from another project names it.
    expect(find.text('#4 · Home'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Done child')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(sectionTitles(tester), isEmpty);
    // Downloaded just now: nothing to fetch.
    expect(data.tasks.projectListRefreshes, isEmpty);
  });

  testWidgets('nested rows are indented, at most four levels deep', (
    tester,
  ) async {
    data.tasks.all = [
      for (var i = 1; i <= 6; i++)
        sampleTask(
          id: i,
          title: 'Level ${i - 1}',
          parentIds: [if (i > 1) i - 1],
          subtaskIds: [if (i < 6) i + 1],
        ),
    ];
    await pumpProject(tester);

    double start(String title) => tester
        .getTopLeft(
          find.descendant(
            of: find.widgetWithText(TaskRow, title),
            matching: find.byTooltip(en.taskMarkDone),
          ),
        )
        .dx;
    expect(start('Level 1') - start('Level 0'), 22);
    expect(start('Level 4') - start('Level 0'), 88);
    expect(start('Level 5'), start('Level 4'));
  });

  testWidgets('a stale download fetches the view again when it opens, '
      'quietly when that fails', (tester) async {
    data.tasks.setSnapshot(
      'view:11',
      ListSnapshot(
        positions: const {7: 1},
        loadedAt: now.subtract(const Duration(minutes: 6)),
      ),
    );
    data.tasks.refreshProjectListFailure = const ServerFailure(502);
    await pumpProject(tester);

    expect(data.tasks.projectListRefreshes, [(1, 11)]);
    expect(find.byType(DataFailureCard), findsNothing);
    expect(rows(tester).first, ('Eight', 0));
  });

  testWidgets('a view never downloaded fetches its positions when it opens', (
    tester,
  ) async {
    data.tasks.setSnapshot('view:11', const ListSnapshot());
    data.tasks.onRefreshProjectList = (projectId, viewId) async =>
        data.tasks.setSnapshot(
          'view:11',
          ListSnapshot(positions: const {8: 1, 7: 2}, loadedAt: now),
        );
    await pumpProject(tester);

    expect(data.tasks.projectListRefreshes, [(1, 11)]);
    expect(rows(tester).map((row) => row.$1).take(3), [
      // Not in the download: first, newest first.
      'Orphan',
      'Parent',
      'Open child',
    ]);
    expect(rows(tester).where((row) => row.$2 == 0).map((row) => row.$1), [
      'Orphan',
      'Parent',
      'Eight',
      'Seven',
    ]);
  });

  testWidgets('a refresh downloads the view; a failure keeps the rows with '
      'a notice', (tester) async {
    await pumpProject(tester);
    data.tasks.refreshProjectListFailure = const Forbidden(code: 3004);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();

    expect(data.tasks.projectListRefreshes, [(1, 11)]);
    expect(find.byType(TaskRow), findsNWidgets(7));
    expect(
      find.text(en.dataFailureForbidden('tasks.example.org')),
      findsOneWidget,
    );

    data.tasks.refreshProjectListFailure = null;
    await tester.tap(find.text(en.retry));
    await tester.pumpAndSettle();
    expect(find.byType(DataFailureCard), findsNothing);
    expect(data.tasks.projectListRefreshes, hasLength(2));
    expect(data.engine.refreshCalls, 2);
  });

  testWidgets('offline, the saved tasks stay with the quiet notice', (
    tester,
  ) async {
    await pumpProject(tester);
    data.tasks.refreshProjectListFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(find.byType(TaskRow), findsNWidgets(7));
    expect(find.byType(OfflineNotice), findsOneWidget);
    expect(find.byType(DataFailureCard), findsNothing);
  });

  testWidgets('the switcher offers the list views and remembers the one '
      'picked', (tester) async {
    await pumpProject(tester);

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.widgetWithText(ChoiceChip, en.projectViewList), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Kanban'), findsNothing);

    await selectView(tester, 'Everything');

    expect(data.listPreferences.saves, ['remember 1 12']);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Everything'))
          .selected,
      isTrue,
    );
    // Without a filter the done tasks show below, the open child of the
    // done parent under it.
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
    expect(rows(tester).sublist(rows(tester).length - 3), [
      ('Done nine', 0),
      ('Done parent', 0),
      ('Orphan', 1),
    ]);
    expect(data.tasks.projectListRefreshes, [(1, 12)]);
  });

  testWidgets('switching views keeps the chips and the rows on screen while '
      'the other view loads', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProject(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Everything'));
    await tester.pump();

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Everything'))
          .selected,
      isTrue,
    );
    expect(find.byType(LoadingPlaceholder), findsNothing);
    expect(find.byType(TaskRow), findsWidgets);

    await tester.pumpAndSettle();
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
    semantics.dispose();
  });

  testWidgets('a view that fails to load keeps the switcher to go back', (
    tester,
  ) async {
    data.tasks.projectListErrors[13] = const ServerFailure(500);
    await pumpProject(tester);

    await selectView(tester, 'Urgent');
    // Retried a while first; the other view's rows do not stand in.
    expect(find.byType(TaskRow), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 7));
    }
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));

    await selectView(tester, en.projectViewList);
    expect(find.byType(DataFailureCard), findsNothing);
    expect(rows(tester).first, ('Seven', 0));
  });

  testWidgets('opens on the view last picked', (tester) async {
    data.listPreferences.lastViews[1] = 12;
    await pumpProject(tester);

    // Only the view shown downloads.
    expect(data.tasks.projectListRefreshes, [(1, 12)]);

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Everything'))
          .selected,
      isTrue,
    );
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
  });

  testWidgets('a view the device cannot evaluate shows its last download '
      'under a note with its filter', (tester) async {
    data.tasks.setSnapshot(
      'view:13',
      ListSnapshot(
        positions: const {7: 1},
        loadedAt: now.subtract(const Duration(minutes: 3)),
      ),
    );
    await pumpProject(tester);

    await selectView(tester, 'Urgent');

    expect(rows(tester), [('Seven', 0)]);
    expect(
      find.text(en.projectViewFilterNotice('priority >= 4', '3 minutes ago')),
      findsOneWidget,
    );
    await openMenu(tester);
    expect(find.text(en.projectTasksShowDone), findsNothing);
  });

  testWidgets('a download that finished after the last tick reads as now', (
    tester,
  ) async {
    data.tasks.setSnapshot(
      'view:13',
      ListSnapshot(
        positions: const {7: 1},
        loadedAt: now.add(const Duration(seconds: 50)),
      ),
    );
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);

    expect(
      find.text(en.projectViewFilterNotice('priority >= 4', en.relativeNow)),
      findsOneWidget,
    );
  });

  testWidgets('such a view never downloaded says it loads once online', (
    tester,
  ) async {
    data.tasks.refreshProjectListFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);

    expect(find.text(en.projectViewNotLoadedTitle), findsOneWidget);
    expect(
      find.text(en.projectViewNotLoadedBody('priority >= 4')),
      findsOneWidget,
    );
    expect(data.tasks.projectListRefreshes, [(1, 13)]);
  });

  testWidgets('online, such a view says it is downloading, or that it could '
      'not be downloaded', (tester) async {
    final download = Completer<void>();
    data.tasks.onRefreshProjectList = (_, _) => download.future;
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);

    expect(find.text(en.projectViewDownloadingTitle), findsOneWidget);
    expect(find.text(en.projectViewNotLoadedTitle), findsNothing);

    data.tasks.refreshProjectListFailure = const NotFound();
    download.complete();
    await tester.pumpAndSettle();
    expect(find.text(en.projectViewDownloadFailedTitle), findsOneWidget);
    expect(
      find.text(en.projectViewDownloadFailedBody('priority >= 4')),
      findsOneWidget,
    );
    expect(find.text(en.projectViewNotLoadedTitle), findsNothing);

    await pullToRefresh(tester, find.byType(CustomScrollView));
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(find.text(en.projectViewDownloadFailedTitle), findsOneWidget);
  });

  testWidgets('the sort sheet lists the web sorts and keeps the choice per '
      'view', (tester) async {
    await pumpProject(tester);

    await tester.tap(find.byTooltip(en.projectSortCurrent(en.sortManual)));
    await tester.pumpAndSettle();

    final sheet = find.byType(DraggableScrollableSheet);
    expect(
      find.descendant(of: sheet, matching: find.byType(ListTile)),
      findsWidgets,
    );
    final first = tester
        .widgetList<ListTile>(
          find.descendant(of: sheet, matching: find.byType(ListTile)),
        )
        .first;
    expect((first.title! as Text).data, en.sortManual);
    expect(first.selected, isTrue);

    await tester.tap(find.text(en.sortTitleAsc));
    await tester.pumpAndSettle();

    expect(data.listPreferences.views['view:11']?.sort, TaskListSort.titleAsc);
    expect(rows(tester).where((row) => row.$2 == 0).map((row) => row.$1), [
      'Eight',
      'Orphan',
      'Parent',
      'Seven',
    ]);
    expect(
      find.byTooltip(en.projectSortCurrent(en.sortTitleAsc)),
      findsOneWidget,
    );

    await selectView(tester, 'Everything');
    expect(
      find.byTooltip(en.projectSortCurrent(en.sortManual)),
      findsOneWidget,
    );
  });

  testWidgets('show done adds a done part below, saved for the view', (
    tester,
  ) async {
    await pumpProject(tester);

    await toggleShowDone(tester);

    expect(data.listPreferences.views['view:11']?.showDone, isTrue);
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
    // The open child of the done parent moves under it rather than also
    // staying at the top.
    expect(rows(tester).sublist(6), [
      ('Done nine', 0),
      ('Done parent', 0),
      ('Orphan', 1),
    ]);
    expect(find.text('Orphan'), findsOneWidget);
    expect(find.byTooltip(en.taskMarkNotDone), findsNWidgets(3));

    await toggleShowDone(tester);
    expect(sectionTitles(tester), isEmpty);
    expect(find.text('Done nine'), findsNothing);
  });

  testWidgets('only a view that shows done tasks loads them', (tester) async {
    await pumpProject(tester);
    expect(data.tasks.projectListWatches.last, (1, 11, false));

    await toggleShowDone(tester);
    expect(data.tasks.projectListWatches.last, (1, 11, true));

    await selectView(tester, 'Urgent');
    expect(data.tasks.projectListWatches.last, (1, 13, false));
    await selectView(tester, 'Everything');
    expect(data.tasks.projectListWatches.last, (1, 12, true));
  });

  testWidgets('a project without list views lists its open tasks and only '
      'syncs', (tester) async {
    data.projects.all = [
      work(views: const [kanban]),
    ];
    await pumpProject(tester);

    expect(find.byType(ChoiceChip), findsNothing);
    // No positions without a view: newest first.
    expect(rows(tester).first, ('Eight', 0));
    expect(data.tasks.projectListRefreshes, isEmpty);

    await tester.tap(find.byTooltip(en.refresh));
    await tester.pumpAndSettle();
    expect(data.tasks.projectListRefreshes, [(1, 0)]);
  });

  testWidgets('empty states differ with and without done tasks', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 1, title: 'Finished', done: true)];
    await pumpProject(tester);
    expect(find.text(en.projectTasksEmptyTitle), findsOneWidget);

    await toggleShowDone(tester);
    expect(find.text('Finished'), findsOneWidget);

    data.tasks.all = [];
    await tester.pumpAndSettle();
    expect(find.text(en.projectTasksEmptyAllTitle), findsOneWidget);
  });

  testWidgets('a project missing from the list still shows its tasks', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 1, title: 'Lonely', projectId: 42)];
    await pumpProject(tester, id: 42);

    expect(find.widgetWithText(AppBar, en.projectUnknownTitle), findsOneWidget);
    expect(find.text('Lonely'), findsOneWidget);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpProject(tester);

    expect(find.widgetWithText(ChoiceChip, de.projectViewList), findsOneWidget);
    expect(
      find.byTooltip(de.projectSortCurrent(de.sortManual)),
      findsOneWidget,
    );
  });
}
