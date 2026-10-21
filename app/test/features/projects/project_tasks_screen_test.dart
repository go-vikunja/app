import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
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

  Future<void> refreshFromMenu(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text(en.refresh));
    await tester.pumpAndSettle();
  }

  final showDoneChip = find.widgetWithText(FilterChip, en.projectShowDoneChip);

  Future<void> toggleShowDone(WidgetTester tester) async {
    await tester.tap(showDoneChip);
    await tester.pumpAndSettle();
  }

  // The tabs scroll when their titles do not fit.
  Future<void> selectView(WidgetTester tester, String title) async {
    final tab = find.widgetWithText(Tab, title);
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  String selectedView(WidgetTester tester) {
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    return (bar.tabs[bar.controller!.index] as Tab).text!;
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
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('#4'), matching: find.byType(TaskRow)),
        matching: find.text('Home'),
      ),
      findsOneWidget,
    );
    expect(find.text('#2'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Done child')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(sectionTitles(tester), isEmpty);
    // Downloaded just now: nothing to fetch.
    expect(data.tasks.projectListRefreshes, isEmpty);
  });

  testWidgets("under the title the project's own tasks show its progress; "
      'rows lead with their identifier', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProject(tester);

    // Tasks 1 to 9 without 4, which is in another project; 3 of them done.
    expect(find.text(en.projectProgressDone(3, 8)), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .value,
      3 / 8,
    );
    expect(
      find.bySemanticsLabel(en.projectProgressSemantics(3, 8)),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<TaskRow>(find.byType(TaskRow))
          .map((row) => row.identifierBeforeTitle),
      everyElement(isTrue),
    );
    expect(
      find.widgetWithText(FloatingActionButton, en.newTask),
      findsOneWidget,
    );

    data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id == 8) task.copyWith(done: true) else task,
    ];
    await tester.pumpAndSettle();
    expect(find.text(en.projectProgressDone(4, 8)), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a long identifier sends every identifier of the list to the '
      'line below its title, so that the rows agree', (tester) async {
    data.tasks.all = [
      sampleTask(id: 7, title: 'Seven', identifier: 'LONGIDENT-7'),
      sampleTask(id: 8, title: 'Eight'),
    ];
    await pumpProject(tester);

    bool leads(String identifier, String title) =>
        tester.getTopLeft(find.text(identifier)).dy <
        tester.getBottomLeft(find.text(title)).dy;
    expect(leads('LONGIDENT-7', 'Seven'), isFalse);
    expect(leads('#8', 'Eight'), isFalse);
  });

  testWidgets('the tabs follow views added and removed while open', (
    tester,
  ) async {
    await pumpProject(tester);
    expect(find.byType(Tab), findsNWidgets(4));

    data.projects.all = [
      work(views: [listView, kanban]),
      sampleProject(id: 2, title: 'Home', hexColor: '1973ff'),
    ];
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(2));
    expect(selectedView(tester), en.projectViewList);

    await selectView(tester, en.projectViewKanban);
    expect(selectedView(tester), en.projectViewKanban);
    expect(find.byType(TaskRow), findsNothing);

    data.projects.all = [
      work(views: [listView]),
      sampleProject(id: 2, title: 'Home', hexColor: '1973ff'),
    ];
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TaskRow), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a project without tasks shows no progress', (tester) async {
    data.tasks.all = [];
    await pumpProject(tester);

    expect(find.text(en.projectProgressDone(0, 0)), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
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

    await refreshFromMenu(tester);

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

  testWidgets('offline, the saved tasks stay under the banner', (tester) async {
    await pumpProject(tester);
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(find.byType(TaskRow), findsNWidgets(7));
    expect(
      find.textContaining(en.offlineNotice, findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(OfflineNotice), findsNothing);
    expect(find.byType(DataFailureCard), findsNothing);
  });

  testWidgets('the tabs offer the list and kanban views and remember the one '
      'picked', (tester) async {
    await pumpProject(tester);

    expect(find.byType(Tab), findsNWidgets(4));
    expect(find.widgetWithText(Tab, en.projectViewList), findsOneWidget);
    expect(find.widgetWithText(Tab, en.projectViewKanban), findsOneWidget);
    expect(selectedView(tester), en.projectViewList);

    await selectView(tester, 'Everything');

    expect(data.listPreferences.saves, ['remember 1 12']);
    expect(selectedView(tester), 'Everything');
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

  testWidgets('switching views keeps the tabs and the rows on screen while '
      'the other view loads', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpProject(tester);

    await tester.tap(find.widgetWithText(Tab, 'Everything'));
    await tester.pump();

    expect(find.byType(Tab), findsNWidgets(4));
    expect(selectedView(tester), 'Everything');
    expect(find.byType(LoadingPlaceholder), findsNothing);
    expect(find.byType(TaskRow), findsWidgets);

    await tester.pumpAndSettle();
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
    semantics.dispose();
  });

  testWidgets('a view that fails to load keeps the tabs to go back', (
    tester,
  ) async {
    data.tasks.projectListErrors[13] = const ServerFailure(500);
    await pumpProject(tester);

    await selectView(tester, 'Urgent');
    // Retried a while first; the other view's rows do not stand in.
    expect(find.byType(TaskRow), findsNothing);
    expect(find.byType(Tab), findsNWidgets(4));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 7));
    }
    expect(find.byType(DataFailureCard), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(4));

    await selectView(tester, en.projectViewList);
    expect(find.byType(DataFailureCard), findsNothing);
    expect(rows(tester).first, ('Seven', 0));
  });

  testWidgets('opens on the view last picked', (tester) async {
    data.listPreferences.lastViews[1] = 12;
    await pumpProject(tester);

    // Only the view shown downloads.
    expect(data.tasks.projectListRefreshes, [(1, 12)]);

    expect(selectedView(tester), 'Everything');
    expect(sectionTitles(tester), [en.projectTasksDoneSection]);
  });

  testWidgets('a view whose filter the device evaluates lists its matches '
      'in their positions, done ones too, without a note', (tester) async {
    data.tasks
      ..setSnapshot(
        'view:13',
        ListSnapshot(positions: const {8: 1, 7: 2, 9: 3}, loadedAt: now),
      )
      ..setViewMatches(13, {7, 8, 9});
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);

    expect(rows(tester), [('Eight', 0), ('Seven', 0), ('Done nine', 0)]);
    expect(find.textContaining('priority >= 4'), findsNothing);
  });

  testWidgets('such a view needs no download to show its matches, and says '
      'when nothing matches', (tester) async {
    data.tasks
      ..refreshProjectListFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      )
      ..setViewMatches(13, {7});
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);

    expect(rows(tester), [('Seven', 0)]);
    expect(find.text(en.projectViewNotLoadedTitle), findsNothing);

    data.tasks.setViewMatches(13, {});
    await tester.pumpAndSettle();
    expect(find.text(en.projectViewEmptyTitle), findsOneWidget);
    expect(find.text(en.projectViewEmptyMatchingBody), findsOneWidget);
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
    // Its filter decides about the done tasks.
    expect(showDoneChip, findsNothing);
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

  testWidgets('offline and never downloaded, such a view downloads once '
      'back online', (tester) async {
    data.engine.onRefresh = () async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    data.listPreferences.lastViews[1] = 13;
    await pumpProject(tester);
    expect(find.text(en.projectViewNotLoadedTitle), findsOneWidget);

    data.engine.onRefresh = null;
    data.tasks.onRefreshProjectList = (_, _) async => data.tasks.setSnapshot(
      'view:13',
      ListSnapshot(positions: const {7: 1}, loadedAt: now),
    );
    data.engine.emit(SyncIdle(lastSyncedAt: now));
    await tester.pumpAndSettle();

    expect(data.tasks.projectListRefreshes, [(1, 13), (1, 13)]);
    expect(find.text(en.projectViewNotLoadedTitle), findsNothing);
    expect(find.byType(TaskRow), findsOneWidget);
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

  testWidgets('a row that stops being the last keeps its element, so its '
      'state and focus', (tester) async {
    await pumpProject(tester);
    await toggleShowDone(tester);
    Element orphan() => tester.element(
      find.ancestor(of: find.text('Orphan'), matching: find.byType(TaskRow)),
    );
    final before = orphan();

    data.tasks.all = [
      ...tasks(),
      sampleTask(
        id: 10,
        title: 'Done ten',
        done: true,
        doneAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    await tester.pumpAndSettle();

    expect(rows(tester).last, ('Done ten', 0));
    expect(identical(orphan(), before), isTrue);
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

  testWidgets('a project without views the app shows lists its open tasks '
      'and only syncs', (tester) async {
    data.projects.all = [
      work(
        views: const [
          ProjectView(
            id: 15,
            projectId: 1,
            title: 'Gantt',
            kind: ProjectViewKind.gantt,
          ),
        ],
      ),
    ];
    await pumpProject(tester);

    expect(find.byType(TabBar), findsNothing);
    // No positions without a view: newest first.
    expect(rows(tester).first, ('Eight', 0));
    expect(data.tasks.projectListRefreshes, isEmpty);

    await refreshFromMenu(tester);
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

    expect(find.widgetWithText(Tab, de.projectViewList), findsOneWidget);
    expect(
      find.widgetWithText(FilterChip, de.projectShowDoneChip),
      findsOneWidget,
    );
    expect(
      find.byTooltip(de.projectSortCurrent(de.sortManual)),
      findsOneWidget,
    );
  });
}
