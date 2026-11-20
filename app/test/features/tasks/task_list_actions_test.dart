import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

/// A task created on this device keeps its temporary id until the server
/// answers its create; the row marked done follows it to the server id.
void main() {
  final now = DateTime(2026, 10, 10, 12);
  const localId = -5;
  const serverId = 123;
  const title = 'Made offline';
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
  });

  Finder rowsOf(String title) => find.widgetWithText(TaskRow, title);

  Finder rowWithId(int id) => find.byWidgetPredicate(
    (widget) => widget is TaskRow && widget.task.id == id,
  );

  TaskRow rowOf(WidgetTester tester, String title) =>
      tester.widget<TaskRow>(rowsOf(title));

  TextDecoration? decorationOf(WidgetTester tester, String title) =>
      tester.widget<Text>(find.text(title)).style?.decoration;

  group('in the Overview', () {
    setUp(() {
      data.tasks.all = [
        sampleTask(
          id: 1,
          title: 'Pay the bill',
          due: now.subtract(const Duration(days: 1)),
        ),
        sampleTask(
          id: localId,
          title: title,
          due: now.add(const Duration(days: 3)),
        ),
      ];
    });

    Future<void> pumpOverview(WidgetTester tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      await pumpSignedInApp(tester, sync: data, now: now);
    }

    Future<void> markDone(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: rowsOf(title),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('given its server id while Undo is offered, Undo brings back '
        'one row', (tester) async {
      await pumpOverview(tester);
      await markDone(tester);

      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();
      expect(rowsOf(title), findsOneWidget);
      expect(decorationOf(tester, title), TextDecoration.lineThrough);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['setDone $localId true', 'undoDone $localId']);
      expect(data.tasks.find(serverId)?.done, isFalse);
      expect(rowsOf(title), findsOneWidget);
      expect(rowOf(tester, title).task.id, serverId);
      expect(decorationOf(tester, title), isNull);

      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();
      expect(rowsOf(title), findsOneWidget);
      expect(find.byType(TaskRow), findsNWidgets(2));
    });

    testWidgets('given its server id before the Undo reaches the list, one '
        'row comes back', (tester) async {
      await pumpOverview(tester);
      await markDone(tester);
      data.tasks.beforeWrite = () async {
        data.tasks.beforeWrite = null;
        data.tasks.remapTask(localId, serverId);
      };

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.find(serverId)?.done, isFalse);
      expect(rowsOf(title), findsOneWidget);
      expect(rowOf(tester, title).task.id, serverId);
      expect(decorationOf(tester, title), isNull);
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();
      expect(rowsOf(title), findsOneWidget);
    });

    testWidgets('given its server id after Undo, one row stays', (
      tester,
    ) async {
      await pumpOverview(tester);
      await markDone(tester);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();

      expect(rowsOf(title), findsOneWidget);
      expect(rowOf(tester, title).task.id, serverId);
      expect(decorationOf(tester, title), isNull);
    });

    testWidgets('given its server id while it leaves, it leaves on time', (
      tester,
    ) async {
      await pumpOverview(tester);
      await markDone(tester);

      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();

      expect(rowsOf(title), findsNothing);
      expect(find.byType(TaskRow), findsOneWidget);
    });

    testWidgets('given its server id in the middle of a section, it keeps its '
        'place while it leaves', (tester) async {
      data.tasks.all = [
        sampleTask(
          id: 1,
          title: 'Later 1',
          due: now.add(const Duration(days: 11)),
        ),
        sampleTask(
          id: localId,
          title: title,
          due: now.add(const Duration(days: 12)),
        ),
        sampleTask(
          id: 3,
          title: 'Later 3',
          due: now.add(const Duration(days: 13)),
        ),
      ];
      await pumpOverview(tester);
      await markDone(tester);

      List<String> titles() => [
        for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
          row.task.title,
      ];
      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();

      expect(titles(), ['Later 1', title, 'Later 3']);
      expect(rowOf(tester, title).task.id, serverId);
      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();
      expect(titles(), ['Later 1', 'Later 3']);
    });
  });

  group('in a project list that shows done tasks', () {
    setUp(() {
      data.tasks.all = [
        sampleTask(id: 1, title: 'Open 1'),
        sampleTask(id: localId, title: title),
        sampleTask(id: 4, title: 'Done 4', done: true),
      ];
    });

    Future<void> pumpProject(WidgetTester tester) async {
      await pumpSignedInApp(tester, sync: data, now: now);
      containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, en.projectShowDoneChip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: rowsOf(title),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('given its server id while Undo is offered, it keeps one row '
        'where it was, then moves to the done part', (tester) async {
      await pumpProject(tester);
      final place = tester.getTopLeft(rowsOf(title));

      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();

      expect(rowsOf(title), findsOneWidget);
      expect(rowOf(tester, title).task.id, serverId);
      expect(tester.getTopLeft(rowsOf(title)), place);
      expect(find.text(en.taskMarkedDone), findsOneWidget);

      await tester.pump(markedDoneSnackBarDuration);
      await tester.pumpAndSettle();
      expect(rowsOf(title), findsOneWidget);
      expect(
        tester.getTopLeft(rowsOf(title)).dy,
        greaterThan(
          tester.getTopLeft(find.text(en.projectTasksDoneSection)).dy,
        ),
      );
    });

    testWidgets('reopening the row under its server id takes the Undo away', (
      tester,
    ) async {
      await pumpProject(tester);
      data.tasks.remapTask(localId, serverId);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: rowWithId(serverId),
          matching: find.byTooltip(en.taskMarkNotDone),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.writes.last, 'setDone $serverId false');
      expect(find.text(en.taskMarkedDone), findsNothing);
      expect(rowsOf(title), findsOneWidget);
      expect(decorationOf(tester, title), isNull);
    });
  });
}
