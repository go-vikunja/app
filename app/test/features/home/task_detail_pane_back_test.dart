import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tree_column.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/back_gestures.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/task_detail_panes.dart';

String _location(WidgetTester tester) =>
    routerOf(tester).routerDelegate.state.matchedLocation;

Future<void> _openProject(WidgetTester tester) async {
  goTo(tester, AppRoutes.project(workProjectId));
  await tester.pumpAndSettle();
}

Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Task 4 in the project's pane, then its related task 3 inside it.
Future<void> _paneOfTwo(WidgetTester tester) async {
  await _openProject(tester);
  await tapTaskRow(tester, 4);
  await openRelatedInPane(tester);
  expect(paneTaskId(tester), 3);
}

void main() {
  group('at 1280×800', () {
    testWidgets('with a page of a hidden tab, Android hears that the app '
        'handles back while the Overview pane is open, and a swipe closes '
        'the pane and leaves the hidden page', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final reports = recordBackReports(tester);
      await pumpSweepApp(tester);
      await _openProject(tester);
      await openTab(tester, en.tabOverview);
      await tapTaskRow(tester, 1);
      expect(reports.last, isTrue);

      await swipeBack(tester);
      expect(find.byType(TaskDetailPane), findsNothing);
      expect(_location(tester), AppRoutes.overview);
      // Already true before the pane opened: the hidden tab's page makes
      // the router report that it can pop (before 36c too).
      await openTab(tester, en.tabProjects);
      expect(_location(tester), AppRoutes.project(workProjectId));
    });

    for (final (how, back) in [('swipe', swipeBack), ('button', _pressBack)]) {
      testWidgets('by $how: the task before in the pane, then the pane, then '
          'the project page', (tester) async {
        useWindow(tester, androidTabletLandscape);
        await pumpSweepApp(tester);
        await _paneOfTwo(tester);

        await back(tester);
        expect(paneTaskId(tester), 4);
        expect(_location(tester), AppRoutes.project(workProjectId));

        await back(tester);
        expect(find.byType(TaskDetailPane), findsNothing);
        expect(_location(tester), AppRoutes.project(workProjectId));

        await back(tester);
        expect(_location(tester), AppRoutes.projects);
      });
    }

    testWidgets('a swipe on the edit page over the pane pops only the edit '
        'page', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _openProject(tester);
      await tapTaskRow(tester, 4);
      await tester.tap(inPane(find.byTooltip(en.taskEdit)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsOneWidget);

      await swipeBack(tester);
      expect(find.byType(TaskEditPage), findsNothing);
      expectPane(tester, taskId: 4);
      expect(_location(tester), AppRoutes.project(workProjectId));
    });

    testWidgets('a swipe on a sheet over a project page closes only the '
        'sheet', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _openProject(tester);
      final task = sweepData().tasks.all.firstWhere((task) => task.id == 4);
      unawaited(
        showTaskDetail(
          routerOf(tester).routerDelegate.navigatorKey.currentContext!,
          task: task,
        ),
      );
      await tester.pumpAndSettle();
      expectSheet(tester, taskId: 4);

      await swipeBack(tester);
      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    for (final (how, back) in [('swipe', swipeBack), ('button', _pressBack)]) {
      // The tab's menu opens on the tab's navigator, the column's, outside
      // the tabs, on the root navigator.
      for (final (whose, screen, root) in [
        ("the tab's menu", ProjectTasksScreen, false),
        ("the project tree's column's menu", ProjectTreeColumn, true),
      ]) {
        testWidgets('by $how: $whose closes before the pane', (tester) async {
          useWindow(tester, androidTabletLandscape);
          await pumpSweepApp(tester);
          await _openProject(tester);
          await tapTaskRow(tester, 4);
          await tapOutsidePane(
            tester,
            find.descendant(
              of: find.byType(screen),
              matching: find.byTooltip(en.moreActions),
            ),
          );
          final menu = find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem,
          );
          expect(menu, findsWidgets);
          final rootNavigator = routerOf(tester)
              .routerDelegate
              .navigatorKey
              .currentState;
          expect(
            ModalRoute.of(tester.element(menu.first))!.navigator,
            root
                ? same(rootNavigator)
                : same(
                    Navigator.of(
                      tester.element(find.byType(ProjectTasksScreen)),
                    ),
                  ),
          );

          await back(tester);
          expect(menu, findsNothing);
          expectPane(tester, taskId: 4);

          await back(tester);
          expect(find.byType(TaskDetailPane), findsNothing);
          expect(_location(tester), AppRoutes.project(workProjectId));
        });
      }
    }
  });

  group('on a phone', () {
    testWidgets('a swipe on the sheet over a project page closes only the '
        'sheet', (tester) async {
      useWindow(tester, androidPhone);
      await pumpSweepApp(tester);
      await _openProject(tester);
      await tapTaskRow(tester, 4);
      expectSheet(tester, taskId: 4);

      await swipeBack(tester);
      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });

    testWidgets('a swipe on search over a project page pops only search', (
      tester,
    ) async {
      useWindow(tester, androidPhone);
      await pumpSweepApp(tester);
      await _openProject(tester);
      pushTo(tester, AppRoutes.search);
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);

      await swipeBack(tester);
      expect(find.byType(SearchPage), findsNothing);
      expect(_location(tester), AppRoutes.project(workProjectId));
      expect(find.byType(ProjectTasksScreen), findsOneWidget);
    });
  });
}
