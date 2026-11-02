import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;
  final listView = sampleListView(id: 11, projectId: 1);
  const gantt = ProjectView(
    id: 12,
    projectId: 1,
    title: 'Gantt',
    kind: ProjectViewKind.gantt,
    position: 200,
  );
  final table = sampleListView(
    id: 13,
    projectId: 1,
    title: 'Table',
    kind: ProjectViewKind.table,
    position: 300,
    filter: '',
  );
  const kanban = ProjectView(
    id: 14,
    projectId: 1,
    title: 'Kanban',
    kind: ProjectViewKind.kanban,
    position: 400,
  );
  final openTable = sampleListView(
    id: 15,
    projectId: 1,
    title: 'Open table',
    kind: ProjectViewKind.table,
    position: 500,
  );
  // The engine refuses `position`, so only the server can answer.
  final serverTable = sampleListView(
    id: 16,
    projectId: 1,
    title: 'Server table',
    kind: ProjectViewKind.table,
    position: 600,
    filter: 'position > 0',
  );

  List<Task> tasks() => [
    sampleTask(id: 1, title: 'Parent', subtaskIds: [2]),
    sampleTask(id: 2, title: 'Child', parentIds: [1]),
    sampleTask(id: 3, title: 'Done three', done: true, doneAt: now),
    sampleTask(
      id: 4,
      title: 'Four',
      due: now.add(const Duration(days: 1)),
      priority: TaskPriority.high,
    ),
    sampleTask(
      id: 5,
      title: 'Five',
      due: now.subtract(const Duration(days: 1)),
    ),
  ];

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
        views: [listView, gantt, table, kanban, openTable, serverTable],
      ),
    ];
    data.tasks.all = tasks();
    data.tasks.setSnapshot(
      'view:11',
      ListSnapshot(positions: const {5: 1, 4: 2, 1: 3}, loadedAt: now),
    );
  });

  Future<void> pumpProject(WidgetTester tester, {int? viewId}) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2400));
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(1, viewId: viewId));
    await tester.pumpAndSettle();
  }

  List<String> rows(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      row.task.title,
  ];

  Future<void> selectView(WidgetTester tester, String title) async {
    final tab = find.widgetWithText(Tab, title);
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Finder sheetTiles<T extends Widget>() =>
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(T));

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  Future<void> openSort(WidgetTester tester, String current) async {
    await tester.tap(find.byTooltip(en.projectSortCurrent(current)));
    await tester.pumpAndSettle();
  }

  Future<void> openColumns(WidgetTester tester) async {
    // The chips scroll sideways when they do not fit.
    final chip = find.widgetWithText(ActionChip, en.projectTableColumns);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  final showDoneChip = find.widgetWithText(FilterChip, en.projectShowDoneChip);

  testWidgets('the tabs show table and Gantt views in the order of their '
      'positions; a table lists every task flat, the highest number first', (
    tester,
  ) async {
    await pumpProject(tester);

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(
      [for (final tab in bar.tabs) (tab as Tab).text],
      [
        en.projectViewList,
        en.projectViewGantt,
        en.projectViewTable,
        en.projectViewKanban,
        'Open table',
        'Server table',
      ],
    );

    await selectView(tester, en.projectViewTable);

    expect(rows(tester), ['Five', 'Four', 'Done three', 'Child', 'Parent']);
    expect(
      tester.widgetList<TaskRow>(find.byType(TaskRow)).map((row) => row.depth),
      everyElement(0),
    );
    expect(find.byType(ListSectionHeader), findsNothing);
    expect(showDoneChip, findsNothing);
    expect(
      find.byTooltip(en.projectSortCurrent(en.projectTableSortDefault)),
      findsOneWidget,
    );
    expect(find.textContaining('#'), findsNothing);
    // The view's filter is evaluated here: nothing to download.
    expect(data.tasks.projectListRefreshes, isEmpty);
    // The FAB as in a list.
    expect(find.text(en.newTask), findsOneWidget);
  });

  testWidgets("the sort sheet offers the default and the table's other sorts "
      'in its column order, and keeps the choice per view', (tester) async {
    await pumpProject(tester, viewId: 13);

    await openSort(tester, en.projectTableSortDefault);
    final tiles = tester.widgetList<ListTile>(sheetTiles<ListTile>()).toList();
    expect(
      [for (final tile in tiles) (tile.title! as Text).data],
      [
        en.projectTableSortDefault,
        en.projectTableSortDoneAsc,
        en.projectTableSortDoneDesc,
        en.sortTitleAsc,
        en.sortTitleDesc,
        en.sortPriorityDesc,
        en.sortPriorityAsc,
        en.sortDueDateAsc,
        en.sortDueDateDesc,
        en.sortStartDateAsc,
        en.sortStartDateDesc,
        en.sortEndDateAsc,
        en.sortEndDateDesc,
        en.sortPercentDoneDesc,
        en.sortPercentDoneAsc,
        en.projectTableSortDoneAtDesc,
        en.projectTableSortDoneAtAsc,
        en.sortCreatedDesc,
        en.sortCreatedAsc,
        en.sortUpdatedDesc,
        en.sortUpdatedAsc,
      ],
    );
    expect(
      [for (final tile in tiles) tile.selected].indexed.where((e) => e.$2),
      [(0, true)],
    );

    await tester.tap(find.text(en.sortDueDateAsc));
    await tester.pumpAndSettle();

    expect(
      data.listPreferences.views['view:13']?.tableSort,
      const TableSort(TableSortField.dueDate, descending: false),
    );
    // Without a due date last, newest first.
    expect(rows(tester), ['Five', 'Four', 'Done three', 'Child', 'Parent']);
    await openSort(tester, en.sortDueDateAsc);
    await tester.tap(find.text(en.sortDueDateDesc));
    await tester.pumpAndSettle();
    expect(rows(tester), ['Four', 'Five', 'Done three', 'Child', 'Parent']);

    await openSort(tester, en.sortDueDateDesc);
    await tester.tap(find.text(en.projectTableSortDefault));
    await tester.pumpAndSettle();
    expect(
      data.listPreferences.views['view:13']?.tableSort,
      TableSort.defaultSort,
    );
    expect(rows(tester).first, 'Five');

    // The list view keeps its own sort.
    await selectView(tester, en.projectViewList);
    expect(
      find.byTooltip(en.projectSortCurrent(en.sortManual)),
      findsOneWidget,
    );
  });

  testWidgets("the columns sheet lists the web's columns but its number in "
      'its order with the title always on; a change shows at once in every '
      'table view', (tester) async {
    await pumpProject(tester, viewId: 13);

    await openColumns(tester);
    final boxes = tester
        .widgetList<CheckboxListTile>(sheetTiles<CheckboxListTile>())
        .toList();
    expect(
      [for (final box in boxes) (box.title! as Text).data],
      [
        en.taskDone,
        en.taskEditProject,
        en.taskEditTitleLabel,
        en.taskDetailPriority,
        en.taskDetailLabels,
        en.taskDetailAssignees,
        en.projectTableColumnComments,
        en.taskDetailDueDate,
        en.taskDetailStartDate,
        en.taskDetailEndDate,
        en.taskDetailProgress,
        en.projectTableColumnDoneAt,
        en.projectTableColumnCreated,
        en.projectTableColumnUpdated,
        en.projectTableColumnCreatedBy,
      ],
    );
    expect(
      [for (final box in boxes) box.value],
      [
        true, false, true, false, true, true, false, true, //
        false, false, false, false, false, false, false,
      ],
    );
    final title = boxes[2];
    expect(title.onChanged, isNull);
    expect((title.subtitle! as Text).data, en.projectTableColumnTitleAlways);
    final reset = find.widgetWithText(TextButton, en.projectTableColumnsReset);
    expect(tester.widget<TextButton>(reset).onPressed, isNull);

    await tester.tap(inSheet(en.taskDetailPriority));
    await tester.pumpAndSettle();

    expect(data.listPreferences.saves, ['tableColumns']);
    expect(data.listPreferences.tableColumns, {
      ...TableColumn.defaults,
      TableColumn.priority,
    });
    // Every priority, Unset too, as the web table shows it.
    expect(find.byType(TablePriorityLabel), findsNWidgets(5));
    expect(find.text(en.priorityUnset), findsNWidgets(4));

    await tester.tap(inSheet(en.taskDone));
    await tester.pumpAndSettle();
    expect(
      data.listPreferences.tableColumns.contains(TableColumn.done),
      isFalse,
    );
    expect(find.byType(DoneBadge), findsNothing);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(data.listPreferences.tableColumns, TableColumn.defaults);
    expect(find.byType(TablePriorityLabel), findsNothing);
    expect(find.byType(DoneBadge), findsOneWidget);
    expect(tester.widget<TextButton>(reset).onPressed, isNull);

    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
    await selectView(tester, 'Open table');
    expect(find.byType(TablePriorityLabel), findsNothing);
  });

  testWidgets('a sort on a hidden column gives way to the default until the '
      'column shows again; choosing one shows its column', (tester) async {
    const byDue = TableSort(TableSortField.dueDate, descending: true);
    data.listPreferences.views['view:13'] = const ViewPreferences(
      tableSort: byDue,
    );
    await pumpProject(tester, viewId: 13);
    expect(rows(tester), ['Four', 'Five', 'Done three', 'Child', 'Parent']);

    Future<void> toggleDueColumn() async {
      await openColumns(tester);
      await tester.tap(inSheet(en.taskDetailDueDate));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
    }

    await toggleDueColumn();
    expect(rows(tester), ['Five', 'Four', 'Done three', 'Child', 'Parent']);
    expect(
      find.byTooltip(en.projectSortCurrent(en.projectTableSortDefault)),
      findsOneWidget,
    );
    expect(data.listPreferences.views['view:13']?.tableSort, byDue);

    await toggleDueColumn();
    expect(rows(tester), ['Four', 'Five', 'Done three', 'Child', 'Parent']);

    await toggleDueColumn();
    await openSort(tester, en.projectTableSortDefault);
    final tiles = tester.widgetList<ListTile>(sheetTiles<ListTile>()).toList();
    expect(tiles.first.selected, isTrue);
    await tester.tap(find.text(en.sortDueDateDesc));
    await tester.pumpAndSettle();
    expect(data.listPreferences.tableColumns, TableColumn.defaults);
    expect(rows(tester), ['Four', 'Five', 'Done three', 'Child', 'Parent']);
  });

  testWidgets('a stored sort by number, lowest first, which the sheet no '
      'longer offers, works as the default', (tester) async {
    data.listPreferences.views['view:13'] = const ViewPreferences(
      tableSort: TableSort(TableSortField.taskIndex, descending: false),
    );
    await pumpProject(tester, viewId: 13);

    expect(rows(tester), ['Five', 'Four', 'Done three', 'Child', 'Parent']);
    expect(
      find.byTooltip(en.projectSortCurrent(en.projectTableSortDefault)),
      findsOneWidget,
    );
  });

  testWidgets('"Show done" shows on a table whose filter is done = false, and '
      'adds the done tasks among the open ones, saved for the view', (
    tester,
  ) async {
    await pumpProject(tester, viewId: 15);

    expect(rows(tester), ['Five', 'Four', 'Child', 'Parent']);
    expect(showDoneChip, findsOneWidget);
    expect(data.tasks.projectListWatches.last, (1, 15, false));

    await tester.tap(showDoneChip);
    await tester.pumpAndSettle();

    expect(data.listPreferences.views['view:15']?.showDone, isTrue);
    expect(data.tasks.projectListWatches.last, (1, 15, true));
    expect(rows(tester), ['Five', 'Four', 'Done three', 'Child', 'Parent']);
    expect(find.byType(ListSectionHeader), findsNothing);
  });

  testWidgets('a task marked done keeps its row and its place while its Undo '
      'is offered', (tester) async {
    await pumpProject(tester, viewId: 15);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TaskRow, 'Four'),
        matching: find.byTooltip(en.taskMarkDone),
      ),
    );
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 4 true']);
    expect(rows(tester), ['Five', 'Four', 'Child', 'Parent']);
    expect(find.byTooltip(en.taskMarkNotDone), findsOneWidget);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(rows(tester), ['Five', 'Child', 'Parent']);
  });

  testWidgets('sorted by done, a task marked done moves among the done ones '
      'only once its Undo has gone', (tester) async {
    data.listPreferences.views['view:13'] = const ViewPreferences(
      tableSort: TableSort(TableSortField.done, descending: false),
    );
    await pumpProject(tester, viewId: 13);
    expect(rows(tester), ['Five', 'Four', 'Child', 'Parent', 'Done three']);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TaskRow, 'Four'),
        matching: find.byTooltip(en.taskMarkDone),
      ),
    );
    await tester.pumpAndSettle();
    expect(rows(tester), ['Five', 'Four', 'Child', 'Parent', 'Done three']);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(rows(tester), ['Five', 'Child', 'Parent', 'Four', 'Done three']);
  });

  testWidgets('a table whose filter only the server can answer downloads '
      'when it opens and shows that download under a note', (tester) async {
    data.tasks.onRefreshProjectList = (_, viewId) async =>
        data.tasks.setSnapshot(
          'view:$viewId',
          ListSnapshot(positions: const {1: 1, 4: 2}, loadedAt: now),
        );
    await pumpProject(tester, viewId: 16);

    expect(data.tasks.projectListRefreshes, [(1, 16)]);
    expect(rows(tester), ['Four', 'Parent']);
    expect(
      find.text(en.projectViewFilterNotice('position > 0', en.relativeNow)),
      findsOneWidget,
    );
  });

  testWidgets('such a table never downloaded says it loads once online', (
    tester,
  ) async {
    data.tasks.refreshProjectListFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpProject(tester, viewId: 16);

    expect(find.text(en.projectViewNotLoadedTitle), findsOneWidget);
    expect(
      find.text(en.projectViewNotLoadedBody('position > 0')),
      findsOneWidget,
    );
  });

  testWidgets('a pull on a table syncs through the repository', (tester) async {
    await pumpProject(tester, viewId: 13);
    expect(data.tasks.projectListRefreshes, isEmpty);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(data.tasks.projectListRefreshes, [(1, 13)]);
  });

  testWidgets('a tap on a row opens the task sheet', (tester) async {
    await pumpProject(tester, viewId: 13);

    await tester.tap(find.text('Four'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);
  });

  testWidgets('an empty table says why', (tester) async {
    data.tasks.all = [];
    await pumpProject(tester, viewId: 13);

    expect(find.text(en.projectTasksEmptyAllTitle), findsOneWidget);
  });

  testWidgets('a table of open tasks whose tasks are all done says so', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 3, title: 'Done three', done: true)];
    await pumpProject(tester, viewId: 15);

    expect(find.text(en.projectTasksEmptyTitle), findsOneWidget);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpProject(tester, viewId: 13);

    expect(find.widgetWithText(Tab, de.projectViewTable), findsOneWidget);
    expect(find.widgetWithText(Tab, de.projectViewGantt), findsOneWidget);
    expect(find.text(de.projectTableSortDefault), findsOneWidget);
    expect(find.text(de.projectTableColumns), findsOneWidget);
  });
}
