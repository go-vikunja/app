import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../a11y/sweep_data.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';

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
}
