import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/back_gestures.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/task_detail_panes.dart';

/// Back ends a selection on every list that selects, also where Android
/// asks the app for Back only while the app says it handles it
/// (decision log: Tasks).
void main() {
  String location(WidgetTester tester) =>
      routerOf(tester).routerDelegate.state.matchedLocation;

  bool selecting() => find.byType(TaskSelectionActionBar).evaluate().isNotEmpty;

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> longPress(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title).first);
    await tester.pumpAndSettle();
    expect(selecting(), isTrue);
  }

  Future<void> selectFromMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.selectTasks));
    await tester.pumpAndSettle();
    expect(selecting(), isTrue);
  }

  Future<void> act(WidgetTester tester, String action) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TaskSelectionActionBar),
        matching: find.text(action),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (how, back) in [('swipe', swipeBack), ('button', pressBack)]) {
    testWidgets('on the Overview Android hears that the app handles back '
        'while the list selects; back by $how ends it, and then the app '
        'leaves back to Android again', (tester) async {
      final reports = recordBackReports(tester);
      await pumpSweepApp(tester);
      expect(reports.last, isFalse);

      await longPress(tester, 'Buy seeds');
      expect(reports.last, isTrue);

      await back(tester);
      expect(selecting(), isFalse);
      expect(location(tester), AppRoutes.overview);
      expect(reports.last, isFalse);
    });
  }

  for (final (how, back) in [('swipe', swipeBack), ('button', pressBack)]) {
    for (final (what, open, shown) in [
      (
        'a sheet of the bar',
        (WidgetTester tester) => act(tester, en.taskDetailDueDate),
        find.byType(BottomSheet),
      ),
      (
        'the delete dialog',
        (WidgetTester tester) => act(tester, en.selectionDelete),
        find.byType(Dialog),
      ),
      (
        'the search page',
        (WidgetTester tester) async {
          pushTo(tester, AppRoutes.search);
          await tester.pumpAndSettle();
        },
        find.byType(SearchPage),
      ),
    ]) {
      testWidgets('on the Overview back by $how closes $what over the '
          'selection first, and the app handles back until the selection '
          'has ended', (tester) async {
        final reports = recordBackReports(tester);
        await pumpSweepApp(tester);
        await longPress(tester, 'Buy seeds');
        await open(tester);
        expect(shown, findsOneWidget);

        await back(tester);
        expect(shown, findsNothing);
        expect(selecting(), isTrue);
        expect(reports.last, isTrue);

        await back(tester);
        expect(selecting(), isFalse);
        expect(location(tester), AppRoutes.overview);
        expect(reports.last, isFalse);
      });
    }
  }

  testWidgets('a selection on a hidden tab leaves back on the Overview to '
      'Android, and holds it again once its tab shows', (tester) async {
    final reports = recordBackReports(tester);
    await pumpSweepApp(tester);
    await openTab(tester, en.tabUpcoming);
    await longPress(tester, 'Write the report');

    await openTab(tester, en.tabOverview);
    expect(reports.last, isFalse);

    await openTab(tester, en.tabUpcoming);
    expect(selecting(), isTrue);
    expect(reports.last, isTrue);
    await swipeBack(tester);
    expect(selecting(), isFalse);
    expect(location(tester), AppRoutes.upcoming);
  });

  testWidgets('with a pane open on the Overview the app keeps handling back '
      'until the selection has ended and the pane has closed', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final reports = recordBackReports(tester);
    await pumpSweepApp(tester);
    await tapTaskRow(tester, 1);
    await longPress(tester, 'Buy seeds');
    expect(reports.last, isTrue);

    await swipeBack(tester);
    await swipeBack(tester);
    expect(selecting(), isFalse);
    expect(paneTaskId(tester), isNull);
    expect(reports.last, isFalse);
  });

  group('back by swipe ends the selection and keeps the list', () {
    testWidgets('on a project', (tester) async {
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();
      await selectFromMenu(tester);

      await swipeBack(tester);
      expect(selecting(), isFalse);
      expect(location(tester), AppRoutes.project(workProjectId));
    });

    testWidgets('on a saved filter', (tester) async {
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(urgentFilterId));
      await tester.pumpAndSettle();
      await longPress(tester, 'Buy seeds');

      await swipeBack(tester);
      expect(selecting(), isFalse);
      expect(location(tester), AppRoutes.project(urgentFilterId));
    });

    testWidgets("on a label's tasks over the shell", (tester) async {
      await pumpSweepApp(tester);
      pushTo(tester, AppRoutes.labelTasks(calls.id));
      await tester.pumpAndSettle();
      await longPress(tester, 'Call the plumber');

      await swipeBack(tester);
      expect(selecting(), isFalse);
      expect(location(tester), AppRoutes.labelTasks(calls.id));
    });
  });

  group('on iOS the edge swipe still goes back from a list that selects, '
      'which ends the selection with the list', () {
    Future<void> edgeSwipe(WidgetTester tester) async {
      await tester.timedDragFrom(
        const Offset(5, 300),
        const Offset(500, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('from a project', (tester) async {
      await pumpSweepApp(tester);
      goTo(tester, AppRoutes.project(workProjectId));
      await tester.pumpAndSettle();
      await selectFromMenu(tester);

      await edgeSwipe(tester);
      expect(location(tester), AppRoutes.projects);
      expect(selecting(), isFalse);
    }, variant: iOSOnly);

    testWidgets("from a label's tasks over the shell", (tester) async {
      await pumpSweepApp(tester);
      pushTo(tester, AppRoutes.labelTasks(calls.id));
      await tester.pumpAndSettle();
      await longPress(tester, 'Call the plumber');

      await edgeSwipe(tester);
      expect(location(tester), AppRoutes.overview);
      expect(selecting(), isFalse);
    }, variant: iOSOnly);
  });
}
