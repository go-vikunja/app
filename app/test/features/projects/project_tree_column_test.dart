import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/common/presentation/loading_placeholder.dart';
import 'package:vikunja_mobile/features/projects/presentation/board/project_board.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_table_body.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tree_column.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/search/presentation/search_button.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_row.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/selected_task_highlight.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/auth_fakes.dart';
import '../../helpers/back_gestures.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';

final _android = TargetPlatformVariant.only(TargetPlatform.android);

final Finder _column = find.byType(ProjectTreeColumn);

Finder _inColumn(Finder matching) =>
    find.descendant(of: _column, matching: matching);

String _location(WidgetTester tester) =>
    routerOf(tester).routerDelegate.state.matchedLocation;

Future<void> _goTo(WidgetTester tester, String location) async {
  goTo(tester, location);
  await tester.pumpAndSettle();
}

Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _tapRail(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// A favourite project has two: in Favourites and in the tree.
Finder _projectRows(int id) => find.byWidgetPredicate(
  (widget) => widget is ProjectRow && widget.project.id == id,
);

Finder _treeRow(int id) => find.byWidgetPredicate(
  (widget) =>
      widget is ProjectRow &&
      widget.project.id == id &&
      widget.onToggleExpanded != null,
);

Finder _smartRows(String title) => find.byWidgetPredicate(
  (widget) => widget is SmartListRow && widget.title == title,
);

final Finder _anyRow = find.byWidgetPredicate(
  (widget) => widget is ProjectRow || widget is SmartListRow,
);

Finder _only(Element element) =>
    find.byElementPredicate((candidate) => candidate == element);

Finder _backButtonOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byType(BackButton));

/// Whether [row] carries the selected look, and how its node reads.
({bool marked, Tristate selected}) _selectionOf(
  WidgetTester tester,
  Element row,
) {
  final marked = find
      .descendant(
        of: _only(row),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Ink && widget.decoration is SelectedTaskDecoration,
        ),
      )
      .evaluate()
      .isNotEmpty;
  final node = tester.getSemantics(
    find.descendant(of: _only(row), matching: find.byType(ListTile)),
  );
  return (
    marked: marked,
    selected: node.getSemanticsData().flagsCollection.isSelected,
  );
}

void _expectSelected(
  WidgetTester tester,
  Finder rows, {
  required int count,
  required bool selected,
}) {
  final found = rows.evaluate().toList();
  expect(found, hasLength(count), reason: '$rows');
  for (final row in found) {
    expect(_selectionOf(tester, row), (
      marked: selected,
      selected: selected ? Tristate.isTrue : Tristate.isFalse,
    ), reason: '${row.widget}');
  }
}

/// Every text and icon below [rows], with its colour.
List<(String, Color?)> _coloursOf(WidgetTester tester, Finder rows) => [
  for (final text in tester.widgetList<RichText>(
    find.descendant(of: rows, matching: find.byType(RichText)),
  ))
    (text.text.toPlainText(), text.text.style?.color),
];

Rect _tabsRect(WidgetTester tester) =>
    tester.getRect(find.byType(TaskDetailPaneScope));

ScrollPosition _verticalListIn(WidgetTester tester, Finder area) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: area,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
            ),
          )
          .first,
    )
    .position;

ScrollPosition _projectList(WidgetTester tester) =>
    _verticalListIn(tester, find.byType(ProjectListBody));

ScrollPosition _paneList(WidgetTester tester) =>
    _verticalListIn(tester, find.byType(TaskDetailPane));

final String _longDescription = [
  for (var line = 1; line <= 60; line++) '<p>Line $line of the plan.</p>',
].join();

void main() {
  test("the column's open id comes from a project's location alone", () {
    for (final id in [workProjectId, Project.favoritesId, urgentFilterId]) {
      expect(AppRoutes.projectIdIn(AppRoutes.project(id)), id);
    }
    for (final location in [
      AppRoutes.projects,
      AppRoutes.overview,
      '${AppRoutes.projects}/work',
      '${AppRoutes.projects}/1/more',
      AppRoutes.projectEdit(workProjectId),
      AppRoutes.savedFilterEdit(urgentFilterId),
      AppRoutes.taskEdit(1),
    ]) {
      expect(AppRoutes.projectIdIn(location), isNull, reason: location);
    }
  });

  group('where the column shows', () {
    // The tabs' width beside the column without a pane and with one, beside
    // the rail the tests pump (128 dp at 1280×800, 80 on a device).
    for (final (window, variant, tabsWidth, tabsBesidePane) in [
      (androidTabletLandscape, _android, 831.0, 369.2),
      // The gate comes from the window, though the test rail leaves 1,072.
      (const Size(1200, 800), _android, 751.0, 321.2),
      (androidLargeLandscape, _android, 1151.0, 670.0),
      (iPad11Landscape, iOSOnly, 873.0, 394.4),
      (iPadMiniLandscape, iOSOnly, 812.0, 357.8),
      (iPad13Landscape, iOSOnly, 1045.0, 564.0),
    ]) {
      testWidgets('at ${sizeName(window)}: the column of 320 beside the '
          'rail, its divider, then the tabs up to the pane', (tester) async {
        useWindow(tester, window);
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.project(workProjectId));

        final column = treeColumnRect(tester)!;
        expect(column.left, railRight(tester));
        expect(column.width, ProjectTreeColumn.width);
        final divider = tester.getRect(
          find.byKey(const ValueKey('tree divider')),
        );
        expect(divider.left, column.right);
        expect(divider.width, 1);
        expect(contentLeft(tester), column.right + 1);
        final tabs = _tabsRect(tester);
        expect(tabs.left, contentLeft(tester));
        expect(tabs.right, window.width);
        expect(tabs.width, moreOrLessEquals(tabsWidth));

        await tapTaskRow(tester, 4);
        expectPane(tester, taskId: 4);
        final pane = tester.getRect(find.byType(TaskDetailPane));
        expect(pane.right, window.width);
        expect(pane.width, moreOrLessEquals(expectedPaneWidth(tester, window)));
        final paneDivider = tester.getRect(
          find.byKey(const ValueKey('pane divider')),
        );
        expect(paneDivider.right, moreOrLessEquals(pane.left));
        final beside = _tabsRect(tester);
        expect(beside.left, contentLeft(tester));
        expect(beside.right, moreOrLessEquals(paneDivider.left));
        expect(beside.width, moreOrLessEquals(tabsBesidePane));
        expect(treeColumnRect(tester), column);
      }, variant: variant);
    }

    for (final (window, variant) in [
      (const Size(1199, 800), _android),
      (const Size(1119, 800), iOSOnly),
      (const Size(1000, 800), _android),
      (iPad13Portrait, iOSOnly),
      (iPad11Portrait, iOSOnly),
      (androidTabletPortrait, _android),
      (androidFoldable, _android),
      (androidLandscape, _android),
      (defaultSurface, _android),
      (androidPhone, _android),
      (iPhone, iOSOnly),
    ]) {
      testWidgets('none at ${sizeName(window)}: the tree is the first page, '
          'and the project has its back arrow', (tester) async {
        useWindow(tester, window);
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.projects);
        expect(_column, findsNothing);
        expect(find.byType(NoProjectOpen), findsNothing);
        expect(find.byType(ProjectsScreen), findsOneWidget);

        await _goTo(tester, AppRoutes.project(workProjectId));
        expect(_column, findsNothing);
        expect(_backButtonOf(ProjectTasksScreen), findsOneWidget);
        expect(_tabsRect(tester).left, railRight(tester));
      }, variant: variant);
    }

    testWidgets('none for a link-share guest, whose one project keeps the '
        'room', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = SyncFakes(now: sweepNow);
      data.projects.all = [guestProject(permission: Permission.write)];
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: data,
        permission: Permission.write,
      );
      await _goTo(tester, AppRoutes.project(guestProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(_column, findsNothing);
      expect(_backButtonOf(ProjectTasksScreen), findsOneWidget);

      await _goTo(tester, AppRoutes.projects);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(find.byType(NoProjectOpen), findsNothing);
    });

    testWidgets('none on a half-opened vertical fold', (tester) async {
      useWindow(tester, androidTabletLandscape);
      tester.view.displayFeatures = const [
        DisplayFeature(
          bounds: Rect.fromLTWH(640, 0, 0, 800),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      expect(_column, findsNothing);
      expect(_backButtonOf(ProjectTasksScreen), findsOneWidget);
    });
  });

  group('the Projects tab beside the column', () {
    testWidgets('with nothing open it says so, with the one tree in the '
        'column and no pane', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.projects);

      expect(find.byType(NoProjectOpen), findsOneWidget);
      expect(find.text(en.projectsNoneOpenTitle), findsOneWidget);
      expect(find.text(en.projectsNoneOpenBody), findsOneWidget);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(_inColumn(find.byType(ProjectsScreen)), findsOneWidget);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(
        tester.getRect(find.byType(NoProjectOpen)).left,
        contentLeft(tester),
      );
    });

    testWidgets('opening a project keeps the tree as it is', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.projects);
      final tree = tester.state(find.byType(ProjectsScreen));

      await tester.tap(_treeRow(workProjectId));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(find.byType(NoProjectOpen), findsNothing);
      expect(tester.state(find.byType(ProjectsScreen)), same(tree));
    });
  });

  group('the open list in the column', () {
    testWidgets("both of a favourite project's rows are marked and read as "
        'selected, the others not', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));

      _expectSelected(
        tester,
        _projectRows(workProjectId),
        count: 2,
        selected: true,
      );
      _expectSelected(
        tester,
        _projectRows(gardenProjectId),
        count: 1,
        selected: false,
      );
      _expectSelected(
        tester,
        _smartRows(en.projectsFavouriteTasks),
        count: 1,
        selected: false,
      );
      _expectSelected(tester, _smartRows('Urgent'), count: 2, selected: false);
      semantics.dispose();
    });

    testWidgets('Favourite tasks and both rows of a favourite saved filter '
        'likewise', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);

      await _goTo(tester, AppRoutes.project(Project.favoritesId));
      expect(find.byType(SmartListScreen), findsOneWidget);
      _expectSelected(
        tester,
        _smartRows(en.projectsFavouriteTasks),
        count: 1,
        selected: true,
      );
      _expectSelected(tester, _smartRows('Urgent'), count: 2, selected: false);
      _expectSelected(
        tester,
        _projectRows(workProjectId),
        count: 2,
        selected: false,
      );

      await _goTo(tester, AppRoutes.project(urgentFilterId));
      _expectSelected(tester, _smartRows('Urgent'), count: 2, selected: true);
      _expectSelected(
        tester,
        _smartRows(en.projectsFavouriteTasks),
        count: 1,
        selected: false,
      );
      semantics.dispose();
    });

    testWidgets("a marked row keeps an unmarked row's colours: its title, "
        'subtitle and icons', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.projects);
      final rows = _inColumn(_anyRow);
      expect([
        for (final row in rows.evaluate()) _selectionOf(tester, row).marked,
      ], everyElement(isFalse));
      final unmarked = _coloursOf(tester, rows);
      expect(unmarked, isNotEmpty);

      for (final (id, marked) in [
        (workProjectId, _projectRows(workProjectId)),
        (Project.favoritesId, _smartRows(en.projectsFavouriteTasks)),
        (urgentFilterId, _smartRows('Urgent')),
      ]) {
        await _goTo(tester, AppRoutes.project(id));
        expect([
          for (final row in marked.evaluate()) _selectionOf(tester, row).marked,
        ], everyElement(isTrue));
        expect(_coloursOf(tester, rows), unmarked, reason: '$id');
      }
    });

    testWidgets("search's project rows are never selected", (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));

      await tester.tap(_inColumn(find.byType(SearchButton)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchPage),
          matching: find.byType(TextField),
        ),
        'Work',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      _expectSelected(
        tester,
        find.descendant(
          of: find.byType(SearchPage),
          matching: find.byType(ProjectRow),
        ),
        count: 1,
        selected: false,
      );
      semantics.dispose();
    });

    testWidgets('no row is selected on a narrow window', (tester) async {
      useWindow(tester, const Size(1000, 800));
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      // The tree under the project page, offstage.
      expect(
        tester
            .widget<ProjectsScreen>(
              find.byType(ProjectsScreen, skipOffstage: false),
            )
            .selectedId,
        isNull,
      );

      await _pressBack(tester);
      expect(_location(tester), AppRoutes.projects);
      expect(_anyRow, findsWidgets);
      for (final row in _anyRow.evaluate()) {
        expect(_selectionOf(tester, row), (
          marked: false,
          selected: Tristate.isFalse,
        ), reason: '${row.widget}');
      }
      semantics.dispose();
    });
  });

  group('taps in the column', () {
    testWidgets('on the open project keep the location, the view and the '
        'pane', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      // As a link names it: going to the project once more would drop the
      // view it was opened on, and the one chosen since.
      await _goTo(tester, AppRoutes.project(workProjectId, viewId: listViewId));
      await tapTaskRow(tester, 4);
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectTableBody), findsOneWidget);
      expectPane(tester, taskId: 4);
      final screen = tester.state(find.byType(ProjectTasksScreen));

      for (final row in _projectRows(workProjectId).evaluate().toList()) {
        await tester.tap(_only(row));
        await tester.pumpAndSettle();
        expect(_location(tester), AppRoutes.project(workProjectId));
        expect(tester.state(find.byType(ProjectTasksScreen)), same(screen));
        expect(find.byType(ProjectTableBody), findsOneWidget);
        expectPane(tester, taskId: 4);
      }
    });

    testWidgets('on another project open it and close the pane', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);

      await tester.tap(_treeRow(gardenProjectId));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.project(gardenProjectId));
      expect(find.byType(TaskDetailPane), findsNothing);
      _expectSelected(
        tester,
        _projectRows(gardenProjectId),
        count: 1,
        selected: true,
      );
      _expectSelected(
        tester,
        _projectRows(workProjectId),
        count: 2,
        selected: false,
      );
      semantics.dispose();
    });

    testWidgets('selecting the Projects tab again shows that nothing is '
        'open, closes the pane and keeps the column', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);
      final tree = tester.state(_inColumn(find.byType(ProjectsScreen)));

      await _tapRail(tester, en.tabProjects);
      expect(_location(tester), AppRoutes.projects);
      expect(find.byType(NoProjectOpen), findsOneWidget);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(tester.state(_inColumn(find.byType(ProjectsScreen))), same(tree));
    });
  });

  group('back', () {
    for (final (how, back) in [('swipe', swipeBack), ('button', _pressBack)]) {
      testWidgets('by $how at 1280×800: the pane, the project with the '
          'column staying, then the Overview', (tester) async {
        useWindow(tester, androidTabletLandscape);
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.project(workProjectId));
        await tapTaskRow(tester, 4);

        await back(tester);
        expect(find.byType(TaskDetailPane), findsNothing);
        expect(_location(tester), AppRoutes.project(workProjectId));
        expect(_column, findsOneWidget);

        await back(tester);
        expect(_location(tester), AppRoutes.projects);
        expect(find.byType(NoProjectOpen), findsOneWidget);
        expect(_column, findsOneWidget);

        await back(tester);
        expect(_location(tester), AppRoutes.overview);
        expect(_column, findsNothing);
      });
    }

    testWidgets("on an iPad a swipe from the project's own edge goes back "
        'to the tree', (tester) async {
      useWindow(tester, iPad11Landscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      expect(treeColumnRect(tester)!.left, 0);

      await tester.dragFrom(
        Offset(contentLeft(tester) + 5, 400),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.projects);
      expect(find.byType(NoProjectOpen), findsOneWidget);
      expect(_column, findsOneWidget);
    }, variant: iOSOnly);

    testWidgets('beside the column a project or list has no back arrow; '
        'without it, one', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = sweepData();
      await pumpSweepApp(tester, data: data);
      await _goTo(tester, AppRoutes.project(workProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
      expect(_backButtonOf(ProjectTasksScreen), findsNothing);
      await _goTo(tester, AppRoutes.project(Project.favoritesId));
      expect(find.byType(SmartListScreen), findsOneWidget);
      expect(_backButtonOf(SmartListScreen), findsNothing);
      await _goTo(tester, AppRoutes.project(gardenProjectId));
      data.projects.all = [
        for (final project in data.projects.all)
          if (project.id != gardenProjectId) project,
      ];
      await tester.pumpAndSettle();
      expect(find.text(en.projectGoneTitle), findsOneWidget);
      expect(_backButtonOf(ProjectTasksScreen), findsNothing);

      useWindow(tester, const Size(1000, 800));
      await tester.pumpAndSettle();
      expect(find.text(en.projectGoneTitle), findsOneWidget);
      expect(_backButtonOf(ProjectTasksScreen), findsOneWidget);
      await _goTo(tester, AppRoutes.project(workProjectId));
      expect(_backButtonOf(ProjectTasksScreen), findsOneWidget);
      await _goTo(tester, AppRoutes.project(Project.favoritesId));
      expect(_backButtonOf(SmartListScreen), findsOneWidget);
    });
  });

  group('a resize keeps the open project, its list and the pane', () {
    for (final (sizes, variant) in [
      (
        [androidTabletLandscape, const Size(1000, 800), androidTabletLandscape],
        _android,
      ),
      ([iPad13Landscape, iPad13Portrait], iOSOnly),
    ]) {
      testWidgets(sizes.map(sizeName).join(' → '), (tester) async {
        useWindow(tester, sizes.first);
        final data = sweepData();
        data.tasks.all = [
          for (final task in data.tasks.all)
            if (task.id == 4)
              task.copyWith(description: _longDescription)
            else
              task,
          for (var id = 100; id < 130; id++)
            sampleTask(id: id, title: 'Filler $id'),
        ];
        await pumpSweepApp(tester, data: data);
        await _goTo(tester, AppRoutes.project(workProjectId));
        expect(_column, findsOneWidget);
        await tapOutsidePane(tester, taskRowOf(120));
        expect(_projectList(tester).pixels, greaterThan(0));
        tester
            .widget<TaskDetailSheet>(paneDetail)
            .pane!
            .openOther(data.tasks.all.firstWhere((task) => task.id == 4));
        await tester.pumpAndSettle();
        final pane = _paneList(tester);
        pane.jumpTo(pane.maxScrollExtent / 2);
        await tester.pumpAndSettle();
        final paneOffset = _paneList(tester).pixels;
        expect(paneOffset, greaterThan(0));
        final listOffset = _projectList(tester).pixels;
        final screen = tester.state(find.byType(ProjectTasksScreen));
        final detail = tester.state(paneDetail);

        for (final size in sizes.skip(1)) {
          useWindow(tester, size);
          await tester.pumpAndSettle();
          final threePane = size == sizes.first;
          expect(_column, threePane ? findsOneWidget : findsNothing);
          expectPane(tester, taskId: 4);
          expect(tester.state(find.byType(ProjectTasksScreen)), same(screen));
          expect(tester.state(paneDetail), same(detail));
          expect(_projectList(tester).pixels, listOffset);
          expect(_paneList(tester).pixels, paneOffset);
          expect(_tabsRect(tester).left, contentLeft(tester));
        }
      }, variant: variant);
    }

    testWidgets("at the tab's first page the tree and the note take turns", (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.projects);
      expect(find.byType(NoProjectOpen), findsOneWidget);
      expect(_inColumn(find.byType(ProjectsScreen)), findsOneWidget);

      useWindow(tester, const Size(1000, 800));
      await tester.pumpAndSettle();
      expect(_column, findsNothing);
      expect(find.byType(NoProjectOpen), findsNothing);
      expect(find.byType(ProjectsScreen), findsOneWidget);

      useWindow(tester, androidTabletLandscape);
      await tester.pumpAndSettle();
      expect(find.byType(NoProjectOpen), findsOneWidget);
      expect(find.byType(ProjectsScreen), findsOneWidget);
      expect(_inColumn(find.byType(ProjectsScreen)), findsOneWidget);
    });

    for (final (from, to) in [
      (androidTabletLandscape, const Size(1000, 800)),
      (const Size(1000, 800), androidTabletLandscape),
    ]) {
      testWidgets("${sizeName(from)} → ${sizeName(to)}: the tree's open "
          "menu closes, as that tree is gone, and the other tree's menu "
          'works', (tester) async {
        useWindow(tester, from);
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.projects);
        final menuButton = find.descendant(
          of: find.byType(ProjectsScreen),
          matching: find.byTooltip(en.moreActions),
        );
        final showArchived = find.ancestor(
          of: find.text(en.projectsShowArchived),
          matching: find.byWidgetPredicate(
            (widget) => widget is CheckedPopupMenuItem,
          ),
        );
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        expect(showArchived, findsOneWidget);

        useWindow(tester, to);
        await tester.pumpAndSettle();
        expect(showArchived, findsNothing);

        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckedPopupMenuItem<Object?>>(showArchived).checked,
          isFalse,
        );
        await tester.tap(showArchived);
        await tester.pumpAndSettle();
        expect(showArchived, findsNothing);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckedPopupMenuItem<Object?>>(showArchived).checked,
          isTrue,
        );
      });
    }
  });

  testWidgets('the column keeps its place in the tree across a switch to '
      'another tab', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final data = sweepData();
    data.projects.all = [
      ...data.projects.all,
      for (var id = 300; id < 330; id++)
        sampleProject(id: id, title: 'Filler $id', position: id.toDouble()),
    ];
    await pumpSweepApp(tester, data: data);
    await _goTo(tester, AppRoutes.projects);
    await tester.drag(_treeRow(workProjectId), const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = _verticalListIn(tester, _column).pixels;
    expect(offset, greaterThan(0));

    await _tapRail(tester, en.tabOverview);
    expect(_column, findsNothing);
    await _tapRail(tester, en.tabProjects);
    expect(_column, findsOneWidget);
    expect(_verticalListIn(tester, _column).pixels, offset);
  });

  for (final location in [
    AppRoutes.projects,
    AppRoutes.project(workProjectId),
  ]) {
    testWidgets('back from another tab at $location, the column shows its '
        'tree in the first frame, without loading it again', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, location);
      await _tapRail(tester, en.tabOverview);
      expect(_column, findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(en.tabProjects),
        ),
      );
      await tester.pump();
      expect(_column, findsOneWidget);
      expect(_inColumn(find.byType(LoadingPlaceholder)), findsNothing);
      expect(_inColumn(_treeRow(workProjectId)), findsOneWidget);
    });
  }

  group('regions', () {
    testWidgets('the column, the tabs and the pane are three regions in '
        'that order, each with its level-1 heading', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      await tapTaskRow(tester, 4);

      final columnRegion = tester.widget<Semantics>(
        find.descendant(of: _column, matching: find.byType(Semantics)).first,
      );
      expect(columnRegion.container, isTrue);
      expect(columnRegion.explicitChildNodes, isTrue);
      final tabsRegion = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(TaskDetailPaneScope),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(tabsRegion.container, isTrue);
      expect(tabsRegion.explicitChildNodes, isTrue);

      final column = tester.getSemantics(_column);
      final tabs = tester.getSemantics(find.byType(TaskDetailPaneScope));
      final pane = paneRegion(tester);
      final root = tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!;
      final order = semanticsInOrder(root);
      expect(order.indexOf(column), greaterThanOrEqualTo(0));
      expect(order.indexOf(column), lessThan(order.indexOf(tabs)));
      expect(order.indexOf(tabs), lessThan(order.indexOf(pane)));
      final columnNodes = semanticsInOrder(column).toSet();
      final tabsNodes = semanticsInOrder(tabs).toSet();
      final paneNodes = semanticsInOrder(pane).toSet();
      expect(columnNodes.intersection(tabsNodes), isEmpty);
      expect(columnNodes.intersection(paneNodes), isEmpty);
      expect(tabsNodes.intersection(paneNodes), isEmpty);

      List<String> headingsIn(Iterable<SemanticsNode> nodes) => [
        for (final node in nodes)
          if (node.getSemanticsData().headingLevel == 1) node.label,
      ];
      expect(headingsIn(order), [en.tabProjects, 'Work', 'Plan the team day']);
      expect(headingsIn(columnNodes), [en.tabProjects]);
      expect(headingsIn(tabsNodes), ['Work']);
      semantics.dispose();
    });

    testWidgets(
      "with nothing open the tab's region has the note's title as "
      'its level-1 heading, which names the route on Android',
      (tester) async {
        useWindow(tester, androidTabletLandscape);
        final semantics = tester.ensureSemantics();
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.projects);

        final tabs = tester.getSemantics(find.byType(TaskDetailPaneScope));
        final headings = [
          for (final node in semanticsInOrder(tabs))
            if (node.getSemanticsData().headingLevel == 1) node,
        ];
        expect(
          [for (final node in headings) node.label],
          [en.projectsNoneOpenTitle],
        );
        final title = headings.single;
        expect(title.getSemanticsData().flagsCollection.isHeader, isTrue);
        expect(
          title.getSemanticsData().flagsCollection.namesRoute,
          defaultTargetPlatform == TargetPlatform.android,
        );
        // The route it names is the note's own, not the shell's around the
        // tree's column.
        var route = title.parent;
        while (route != null &&
            !route.getSemanticsData().flagsCollection.scopesRoute) {
          route = route.parent;
        }
        expect(route, isNotNull);
        expect(
          semanticsInOrder(route!),
          isNot(contains(tester.getSemantics(_column))),
        );
        semantics.dispose();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets("from another tab's pane to the column and back, the tabs "
        'keep their region and its focus group', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final semantics = tester.ensureSemantics();
      await pumpSweepApp(tester);
      await tapTaskRow(tester, 1);
      final group = find
          .ancestor(
            of: find.byType(TaskDetailPaneScope),
            matching: find.byType(FocusTraversalGroup),
          )
          .first;
      final region = tester.getSemantics(find.byType(TaskDetailPaneScope)).id;
      final groupState = tester.state(group);

      for (final (tab, column) in [
        (en.tabProjects, true),
        (en.tabOverview, false),
      ]) {
        await _tapRail(tester, tab);
        expect(_column, column ? findsOneWidget : findsNothing);
        expect(find.byType(TaskDetailPane), column ? findsNothing : findsOne);
        expect(
          tester.getSemantics(find.byType(TaskDetailPaneScope)).id,
          region,
          reason: tab,
        );
        expect(tester.state(group), same(groupState), reason: tab);
      }
      semantics.dispose();
    });

    for (final (how, back) in [('swipe', swipeBack), ('button', _pressBack)]) {
      testWidgets("by $how the column's menu closes before the pane", (
        tester,
      ) async {
        useWindow(tester, androidTabletLandscape);
        await pumpSweepApp(tester);
        await _goTo(tester, AppRoutes.project(workProjectId));
        await tapTaskRow(tester, 4);
        await tester.tap(_inColumn(find.byTooltip(en.moreActions)));
        await tester.pumpAndSettle();
        final menu = find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem,
        );
        expect(menu, findsWidgets);

        await back(tester);
        expect(menu, findsNothing);
        expectPane(tester, taskId: 4);

        await back(tester);
        expect(find.byType(TaskDetailPane), findsNothing);
        expect(_location(tester), AppRoutes.project(workProjectId));
      });
    }
  });

  group('at 1600×1000', () {
    testWidgets("the List view's rows lie in the middle's readable band", (
      tester,
    ) async {
      useWindow(tester, androidLargeLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));

      final left = contentLeft(tester);
      expect(_tabsRect(tester).width, 1151);
      final band = readableBand(tester, ReadableWidth.list, left: left);
      expect(band.left - left, (1151 - ReadableWidth.list) / 2);
      final rows = find.byType(TaskRow).evaluate().toList();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expectFillsBand(tester.getRect(_only(row)), band);
      }
    });

    testWidgets('the board spans the middle up to the window edge', (
      tester,
    ) async {
      useWindow(tester, androidLargeLandscape);
      await pumpSweepApp(tester);
      await _goTo(tester, AppRoutes.project(workProjectId));
      await tester.tap(find.text('Kanban'));
      await tester.pumpAndSettle();

      expectFillsBand(tester.getRect(find.byType(ProjectBoard)), (
        left: contentLeft(tester),
        right: androidLargeLandscape.width,
      ));
    });
  });
}
