import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';

typedef _List = ({
  String name,
  Future<void> Function(WidgetTester tester) open,
  int selected,
  bool projectsTab,
});

/// The selection bar of every list that selects keeps its close button,
/// count and Select all to the list's band, as a phone has them at the
/// window's edges, while its surface spans the screen.
void main() {
  Future<void> longPress(WidgetTester tester, String title) async {
    final row = find.text(title).first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.longPress(row);
    await tester.pumpAndSettle();
  }

  Future<void> settled(WidgetTester tester) => tester.pumpAndSettle();

  final lists = <_List>[
    (
      name: 'the Overview, whose header is no app bar',
      open: (tester) => longPress(tester, 'Buy seeds'),
      selected: 1,
      projectsTab: false,
    ),
    (
      name: 'Upcoming',
      open: (tester) async {
        await openTab(tester, en.tabUpcoming);
        await longPress(tester, 'Write the report');
      },
      selected: 1,
      projectsTab: false,
    ),
    (
      name: 'a project',
      open: (tester) async {
        goTo(tester, AppRoutes.project(workProjectId));
        await settled(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(ProjectTasksScreen),
            matching: find.byTooltip(en.moreActions),
          ),
        );
        await settled(tester);
        await tester.tap(find.text(en.selectTasks));
        await settled(tester);
      },
      selected: 0,
      projectsTab: true,
    ),
    (
      name: 'a saved filter',
      open: (tester) async {
        goTo(tester, AppRoutes.project(urgentFilterId));
        await settled(tester);
        await longPress(tester, 'Buy seeds');
      },
      selected: 1,
      projectsTab: true,
    ),
    (
      name: "a label's tasks over the shell",
      open: (tester) async {
        pushTo(tester, AppRoutes.labelTasks(calls.id));
        await settled(tester);
        await longPress(tester, 'Call the plumber');
      },
      selected: 1,
      projectsTab: false,
    ),
  ];

  for (final list in lists) {
    for (final size in [
      androidPhone,
      androidTabletLandscape,
      androidLargeLandscape,
    ]) {
      testWidgets('on ${list.name} at ${sizeName(size)}', (tester) async {
        useWindow(tester, size);
        await pumpSweepApp(tester);
        await list.open(tester);

        final bar = find.byType(TaskSelectionBar);
        expect(bar, findsOneWidget);
        final scaffold = find
            .ancestor(of: bar, matching: find.byType(Scaffold))
            .first;
        final screen = tester.getRect(scaffold);
        final inset = ReadableWidth.insetFor(
          available: screen.width,
          max: ReadableWidth.list,
          caps: WindowLayout(size).capsWidths,
        );
        if (size == androidPhone) {
          expect(inset, 0);
        } else if (size == androidLargeLandscape || !list.projectsTab) {
          expect(inset, greaterThan(0));
        }
        final band = (left: screen.left + inset, right: screen.right - inset);

        expectInBand(
          tester.getRect(
            find.descendant(of: scaffold, matching: find.byType(TaskRow)).first,
          ),
          band,
        );
        final appBar = tester.getRect(
          find.descendant(of: bar, matching: find.byType(AppBar)),
        );
        expect((appBar.left, appBar.right), (screen.left, screen.right));
        expect(
          tester.getCenter(find.byTooltip(en.selectionEnd)).dx,
          band.left + kToolbarHeight / 2,
        );
        final title = find.descendant(
          of: bar,
          matching: find.text(en.selectionCount(list.selected)),
        );
        expect(
          tester.getTopLeft(title).dx,
          band.left + kToolbarHeight + NavigationToolbar.kMiddleSpacing,
        );
        // Select all keeps the 8 its bar has after it on a phone.
        expect(
          tester
              .getRect(
                find.descendant(of: bar, matching: find.byType(TextButton)),
              )
              .right,
          band.right - 8,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
