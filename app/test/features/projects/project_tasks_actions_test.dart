import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      for (var i = 1; i <= 3; i++) sampleTask(id: i, title: 'Open $i'),
      sampleTask(id: 4, title: 'Done 4', done: true),
    ];
  });

  Future<void> pumpProject(WidgetTester tester) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
  }

  Future<void> toggleShowDone(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
    );
    await tester.pumpAndSettle();
  }

  Finder inRow(String title, Finder matching) => find.descendant(
    of: find.widgetWithText(TaskRow, title),
    matching: matching,
  );

  TextDecoration? decorationOf(WidgetTester tester, String title) =>
      tester.widget<Text>(find.text(title)).style?.decoration;

  testWidgets('a task marked done stays struck through until the snackbar '
      'hides, then leaves the open list', (tester) async {
    await pumpProject(tester);

    await tester.tap(inRow('Open 2', find.byTooltip(en.taskMarkDone)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 2 true']);
    expect(decorationOf(tester, 'Open 2'), TextDecoration.lineThrough);
    expect(find.text(en.taskMarkedDone), findsOneWidget);
    expect(find.byType(TaskRow), findsNWidgets(3));

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Open 2'), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(2));
  });

  testWidgets(
    'with done tasks shown the row stays, and its circle reopens it',
    (tester) async {
      await pumpProject(tester);
      await toggleShowDone(tester);

      await tester.tap(inRow('Open 3', find.byTooltip(en.taskMarkDone)));
      await tester.pumpAndSettle();
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();

      expect(find.text('Open 3'), findsOneWidget);
      expect(decorationOf(tester, 'Open 3'), TextDecoration.lineThrough);
      expect(find.byType(TaskRow), findsNWidgets(4));
      // Now in the done part, below its header.
      expect(
        tester.getTopLeft(find.text('Open 3')).dy,
        greaterThan(
          tester.getTopLeft(find.text(en.projectTasksDoneSection)).dy,
        ),
      );

      await tester.tap(inRow('Done 4', find.byTooltip(en.taskMarkNotDone)));
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['setDone 3 true', 'setDone 4 false']);
      expect(decorationOf(tester, 'Done 4'), isNull);
      expect(find.text(en.taskMarkedDone), findsNothing);
    },
  );

  testWidgets('a subtask marked done stays under its parent', (tester) async {
    data.tasks.all = [
      sampleTask(id: 1, title: 'Parent', subtaskIds: [2]),
      sampleTask(id: 2, title: 'Child', parentIds: [1]),
    ];
    await pumpProject(tester);

    await tester.tap(inRow('Child', find.byTooltip(en.taskMarkDone)));
    await tester.pumpAndSettle();
    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();

    expect(decorationOf(tester, 'Child'), TextDecoration.lineThrough);
    expect(
      tester.widget<TaskRow>(find.widgetWithText(TaskRow, 'Child')).depth,
      1,
    );
  });

  testWidgets('the star and the not-yet-synced mark work in a project list', (
    tester,
  ) async {
    data.tasks.pendingTaskIds = {1};
    await pumpProject(tester);

    expect(
      inRow('Open 1', find.byIcon(Icons.cloud_off_outlined)),
      findsOneWidget,
    );
    await tester.tap(inRow('Open 1', find.byTooltip(en.taskAddFavourite)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setFavorite 1 true']);
    expect(
      inRow('Open 1', find.byTooltip(en.taskRemoveFavourite)),
      findsOneWidget,
    );
  });
}
