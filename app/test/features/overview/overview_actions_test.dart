import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
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
      sampleTask(
        id: 1,
        title: 'Pay the bill',
        due: now.subtract(const Duration(days: 1)),
      ),
      sampleTask(
        id: 2,
        title: 'Call mum',
        due: now.add(const Duration(hours: 6)),
        favorite: true,
      ),
      sampleTask(
        id: 3,
        title: 'Write report',
        due: now.add(const Duration(days: 3)),
      ),
    ];
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
  }

  Finder inRow(String title, Finder matching) => find.descendant(
    of: find.widgetWithText(TaskRow, title),
    matching: matching,
  );

  Finder markDone(String title) =>
      inRow(title, find.byTooltip(en.taskMarkDone));

  Finder markNotDone(String title) =>
      inRow(title, find.byTooltip(en.taskMarkNotDone));

  TextDecoration? decorationOf(WidgetTester tester, String title) =>
      tester.widget<Text>(find.text(title)).style?.decoration;

  List<Object?> recordHaptics(WidgetTester tester) {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return calls;
  }

  testWidgets('the circle marks the task done at once, with a haptic, and '
      'offers Undo while the row stays struck through', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpOverview(tester);

    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true']);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(data.tasks.find(3)?.done, isTrue);
    expect(decorationOf(tester, 'Write report'), TextDecoration.lineThrough);
    expect(markNotDone('Write report'), findsOneWidget);
    expect(find.text(en.taskMarkedDone), findsOneWidget);
    expect(find.text(en.undo), findsOneWidget);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();

    expect(find.text('Write report'), findsNothing);
    expect(find.text(en.taskMarkedDone), findsNothing);
    expect(find.byType(TaskRow), findsNWidgets(2));
  });

  testWidgets('Undo reopens the task in place', (tester) async {
    await pumpOverview(tester);
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true', 'undoDone 3']);
    expect(data.tasks.find(3)?.done, isFalse);
    expect(find.text('Write report'), findsOneWidget);
    expect(decorationOf(tester, 'Write report'), isNull);
    expect(markDone('Write report'), findsOneWidget);
    expect(find.text(en.taskMarkedDone), findsNothing);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Write report'), findsOneWidget);
    expect(find.byType(TaskRow), findsNWidgets(3));
  });

  testWidgets('the circle of a done row reopens it without a snackbar', (
    tester,
  ) async {
    await pumpOverview(tester);
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    await tester.tap(markNotDone('Write report'));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true', 'setDone 3 false']);
    expect(decorationOf(tester, 'Write report'), isNull);
    expect(find.text(en.taskMarkedDone), findsNothing);
    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Write report'), findsOneWidget);
  });

  testWidgets('a second done replaces the snackbar; the first row leaves when '
      'its own time is up, not under the finger', (tester) async {
    await pumpOverview(tester);
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    await tester.tap(markDone('Call mum'));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true', 'setDone 2 true']);
    expect(find.text('Write report'), findsOneWidget);
    expect(decorationOf(tester, 'Write report'), TextDecoration.lineThrough);
    expect(decorationOf(tester, 'Call mum'), TextDecoration.lineThrough);
    expect(find.text(en.taskMarkedDone), findsOneWidget);

    // Undo belongs to the latest task only.
    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();
    expect(data.tasks.writes.last, 'undoDone 2');
    expect(decorationOf(tester, 'Call mum'), isNull);
    expect(find.text('Write report'), findsOneWidget);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Write report'), findsNothing);
    expect(find.text('Call mum'), findsOneWidget);
  });

  testWidgets('reopening an earlier row from its circle leaves the latest '
      'Undo alone', (tester) async {
    await pumpOverview(tester);
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();
    await tester.tap(markDone('Call mum'));
    await tester.pumpAndSettle();

    await tester.tap(markNotDone('Write report'));
    await tester.pumpAndSettle();

    expect(data.tasks.writes.last, 'setDone 3 false');
    expect(decorationOf(tester, 'Write report'), isNull);
    expect(find.text(en.undo), findsOneWidget);
    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();
    expect(data.tasks.writes.last, 'undoDone 2');
  });

  testWidgets('a sync that reopens the task while Undo is offered wins, like '
      'the next occurrence of a repeating task', (tester) async {
    await pumpOverview(tester);
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id != 3) task,
      sampleTask(
        id: 3,
        title: 'Write report',
        due: now.add(const Duration(days: 4)),
      ),
    ];
    await tester.pumpAndSettle();

    expect(find.text('Write report'), findsOneWidget);
    expect(decorationOf(tester, 'Write report'), isNull);
    expect(find.text('in 4 days'), findsOneWidget);
    expect(find.text(en.undo), findsOneWidget);

    // Undo takes the previous occurrence back, dates included.
    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 3 true', 'undoDone 3']);
    expect(find.text('in 3 days'), findsOneWidget);
    expect(find.text('in 4 days'), findsNothing);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Write report'), findsOneWidget);
  });

  testWidgets('under a screen reader the snackbar waits for the user, and '
      'so does the row', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpOverview(tester);

    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();
    await tester.pump(markedDoneSnackBarDuration * 3);
    await tester.pumpAndSettle();

    expect(find.text(en.undo), findsOneWidget);
    expect(find.text('Write report'), findsOneWidget);
    expect(decorationOf(tester, 'Write report'), TextDecoration.lineThrough);

    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 3 true', 'undoDone 3']);
    expect(decorationOf(tester, 'Write report'), isNull);
    expect(find.byType(TaskRow), findsNWidgets(3));
  });

  testWidgets('a task in the middle of a section keeps its place while it '
      'leaves', (tester) async {
    data.tasks.all = [
      for (var i = 1; i <= 3; i++)
        sampleTask(
          id: i,
          title: 'Later $i',
          due: now.add(Duration(days: 10 + i)),
        ),
    ];
    await pumpOverview(tester);

    await tester.tap(markDone('Later 2'));
    await tester.pumpAndSettle();

    List<String> titles() => [
      for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
        row.task.title,
    ];
    expect(titles(), ['Later 1', 'Later 2', 'Later 3']);
    expect(decorationOf(tester, 'Later 2'), TextDecoration.lineThrough);

    // A sync meanwhile changes nothing about where the row sits.
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(
        id: 4,
        title: 'Later 4',
        due: now.add(const Duration(days: 20)),
      ),
    ];
    await tester.pumpAndSettle();
    expect(titles(), ['Later 1', 'Later 2', 'Later 3', 'Later 4']);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(titles(), ['Later 1', 'Later 3', 'Later 4']);
  });

  testWidgets('the star toggles the favourite', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpOverview(tester);

    await tester.tap(
      inRow('Write report', find.byTooltip(en.taskAddFavourite)),
    );
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setFavorite 3 true']);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(
      inRow('Write report', find.byTooltip(en.taskRemoveFavourite)),
      findsOneWidget,
    );

    await tester.tap(inRow('Call mum', find.byTooltip(en.taskRemoveFavourite)));
    await tester.pumpAndSettle();
    expect(data.tasks.writes.last, 'setFavorite 2 false');
    expect(
      inRow('Call mum', find.byTooltip(en.taskAddFavourite)),
      findsOneWidget,
    );
  });

  testWidgets('a task with a queued change carries the not-yet-synced mark', (
    tester,
  ) async {
    data.tasks.pendingTaskIds = {2};
    await pumpOverview(tester);

    final semantics = tester.ensureSemantics();
    final mark = inRow('Call mum', find.byIcon(Icons.cloud_off_outlined));
    expect(mark, findsOneWidget);
    expect(
      tester.getSemantics(find.text('Call mum')).label,
      contains(en.taskNotYetSynced),
    );
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    semantics.dispose();

    data.tasks.pendingTaskIds = {};
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
  });

  testWidgets('the controls take taps 22 dp off their icon, and the texts '
      'open the details', (tester) async {
    await pumpOverview(tester);

    // The icon is 40 dp; the tap target around it is 48 dp.
    await tester.tapAt(
      tester.getCenter(markDone('Write report')) + const Offset(22, 22),
    );
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 3 true']);

    await tester.tapAt(
      tester.getCenter(
            inRow('Call mum', find.byTooltip(en.taskRemoveFavourite)),
          ) +
          const Offset(-22, 22),
    );
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 3 true', 'setFavorite 2 false']);

    await tester.tap(find.text('Call mum'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(data.tasks.writes, hasLength(2));
  });

  testWidgets('at 200 % text scale in dark mode the rows, the controls and '
      'the snackbar still work', (tester) async {
    useAccessibilityExtremes(tester);
    await pumpOverview(tester);

    expect(find.byType(TaskRow), findsNWidgets(3));
    await tester.tap(markDone('Write report'));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true']);
    expect(find.text(en.taskMarkedDone), findsOneWidget);
    expect(find.text(en.undo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await pumpOverview(tester);

    await tester.tap(inRow('Write report', find.byTooltip(de.taskMarkDone)));
    await tester.pumpAndSettle();

    expect(find.text(de.taskMarkedDone), findsOneWidget);
    expect(find.text(de.undo), findsOneWidget);
    expect(
      inRow('Write report', find.byTooltip(de.taskMarkNotDone)),
      findsOneWidget,
    );
    expect(find.byTooltip(de.taskAddFavourite), findsNWidgets(2));
  });
}
