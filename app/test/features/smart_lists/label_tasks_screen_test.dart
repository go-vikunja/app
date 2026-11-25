import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';

void main() {
  for (final size in [androidPhone, androidTabletLandscape]) {
    testWidgets("at ${sizeName(size)} the app bar's back button, title and "
        "refresh keep to the list's band, where the cards are, and its "
        'surface spans the window over the shell', (tester) async {
      useWindow(tester, size);
      await pumpSweepApp(tester);
      pushTo(tester, AppRoutes.labelTasks(calls.id));
      await tester.pumpAndSettle();

      final screen = find.byType(LabelTasksScreen);
      final band = readableBand(tester, ReadableWidth.list, left: 0);
      expect(band.left, size == androidPhone ? 0 : 220);
      final appBar = find.descendant(of: screen, matching: find.byType(AppBar));
      expect(tester.getRect(appBar).width, size.width);
      expect(
        tester.getCenter(find.byType(BackButton)).dx,
        band.left + kToolbarHeight / 2,
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(of: appBar, matching: find.text('Calls')),
            )
            .dx,
        band.left + kToolbarHeight + NavigationToolbar.kMiddleSpacing,
      );
      expect(
        tester
            .getRect(
              find.ancestor(
                of: find.byTooltip(en.refresh),
                matching: find.byType(IconButton),
              ),
            )
            .right,
        band.right,
      );
      expectFillsBand(
        tester.getRect(find.widgetWithText(TaskRow, 'Call the plumber')),
        (left: band.left + 16, right: band.right - 16),
      );
    });
  }

  testWidgets("at midnight, within a minute while it is open, last night's "
      "task is overdue and tomorrow's is today", (tester) async {
    var current = DateTime(2026, 10, 10, 22);
    final data = sweepData();
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Late call',
        due: DateTime(2026, 10, 10, 23),
        labels: [calls],
      ),
      sampleTask(
        id: 2,
        title: 'Morning call',
        due: DateTime(2026, 10, 11, 10),
        labels: [calls],
      ),
    ];
    await pumpSignedInApp(
      tester,
      sync: data,
      overrides: [
        ...sweepRepositoryOverrides(),
        clockProvider.overrideWithValue(() => current),
      ],
    );
    pushTo(tester, AppRoutes.labelTasks(calls.id));
    await tester.pumpAndSettle();
    List<String> headings() => [
      for (final header in tester.widgetList<ListSectionHeader>(
        find.byType(ListSectionHeader),
      ))
        header.title,
    ];
    expect(headings(), [en.sectionToday, en.sectionNextSevenDays]);

    current = DateTime(2026, 10, 11, 8);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(headings(), [en.sectionOverdue, en.sectionToday]);
    expect(
      [
        for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
          row.task.title,
      ],
      ['Late call', 'Morning call'],
    );
  });
}
