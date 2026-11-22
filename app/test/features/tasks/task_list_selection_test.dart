import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_selection.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

/// Swipes, the rows' screen reader actions, selecting several tasks and
/// the Overdue heading's Reschedule, on the Overview (decision log: Tasks).
void main() {
  // Saturday noon.
  final now = DateTime(2026, 10, 10, 12);
  final yesterday = DateTime(2026, 10, 9);
  final today = DateTime(2026, 10, 10);
  final tomorrow = DateTime(2026, 10, 11);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(
        id: 2,
        title: 'Shared',
      ).copyWith(maxPermission: Permission.read),
      sampleProject(id: 3, title: 'Home', position: 2),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Pay the bill',
        due: yesterday.add(const Duration(hours: 9)),
      ),
      sampleTask(
        id: 2,
        title: 'Water plants',
        due: yesterday.add(const Duration(hours: 18)),
      ),
      sampleTask(
        id: 3,
        title: 'Call mum',
        due: today.add(const Duration(hours: 18)),
      ),
      sampleTask(
        id: 4,
        title: 'Read only',
        projectId: 2,
        due: today.add(const Duration(hours: 20)),
      ),
      sampleTask(id: 5, title: 'Write report', due: DateTime(2026, 10, 13, 10)),
      sampleTask(
        id: 6,
        title: 'Shared bill',
        projectId: 2,
        due: yesterday.add(const Duration(hours: 10)),
      ),
    ];
  });

  Future<void> pumpOverview(
    WidgetTester tester, {
    ServerConnection? connection,
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 2000));
    await pumpSignedInApp(tester, sync: data, now: now, connection: connection);
  }

  Finder row(String title) => find.widgetWithText(TaskRow, title);

  List<String> actionsOf(WidgetTester tester, String title) => [
    for (final id
        in tester
                .getSemantics(find.text(title))
                .getSemanticsData()
                .customSemanticsActionIds ??
            const <int>[])
      CustomSemanticsAction.getAction(id)!.label!,
  ];

  void performAction(WidgetTester tester, String title, String label) {
    final node = tester.getSemantics(find.text(title));
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
    );
  }

  List<String> said(WidgetTester tester) => [
    for (final announcement in tester.takeAnnouncements()) announcement.message,
  ];

  Future<void> swipe(WidgetTester tester, String title, double dx) async {
    await tester.drag(find.text(title), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, List<String> titles) async {
    await tester.longPress(find.text(titles.first));
    await tester.pumpAndSettle();
    for (final title in titles.skip(1)) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
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

  DateChange dueChange(DateTime local) => DateChange.set(local.toUtc());

  group('swipes', () {
    testWidgets('toward the end marks the task done, with Undo', (
      tester,
    ) async {
      await pumpOverview(tester);

      await swipe(tester, 'Call mum', 250);

      expect(data.tasks.writes, ['setDone 3 true']);
      expect(find.text(en.taskMarkedDone), findsOneWidget);
    });

    testWidgets('toward the start opens the due-date choices', (tester) async {
      await pumpOverview(tester);

      await swipe(tester, 'Call mum', -250);
      expect(find.text(en.taskDetailDueDate), findsWidgets);
      await tester.tap(find.text(en.shortcutTomorrow));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (
          3,
          TaskChanges(
            dueDate: dueChange(tomorrow.add(const Duration(hours: 18))),
          ),
        ),
      ]);
    });

    testWidgets('a task of a project the user may only read does not move', (
      tester,
    ) async {
      await pumpOverview(tester);
      final rest = tester.getTopLeft(find.text('Read only'));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Read only')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Read only')), rest);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(data.tasks.writes, isEmpty);
    });
  });

  group('screen reader actions', () {
    testWidgets('match the swipes and select; none on a read-only task', (
      tester,
    ) async {
      await pumpOverview(tester);

      expect(actionsOf(tester, 'Call mum'), [
        en.taskMarkDone,
        en.taskDetailChangeDueDate,
        en.taskSelect,
      ]);
      expect(actionsOf(tester, 'Read only'), isEmpty);
      // The swipe offers no scroll actions, which would run its actions.
      final row = tester.getSemantics(find.text('Call mum')).getSemanticsData();
      expect(row.hasAction(SemanticsAction.scrollLeft), isFalse);
      expect(row.hasAction(SemanticsAction.scrollRight), isFalse);

      performAction(tester, 'Call mum', en.taskMarkDone);
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['setDone 3 true']);
      expect(actionsOf(tester, 'Call mum'), contains(en.taskMarkNotDone));
    });

    testWidgets('Select starts selecting with the task, announced', (
      tester,
    ) async {
      await pumpOverview(tester);
      tester.takeAnnouncements();

      performAction(tester, 'Call mum', en.taskSelect);
      await tester.pumpAndSettle();

      expect(find.text(en.selectionCount(1)), findsOneWidget);
      expect(said(tester), [en.selectionStarted]);
      expect(actionsOf(tester, 'Call mum'), isEmpty);
      expect(
        tester.getSemantics(row('Call mum')),
        isSemantics(hasCheckedState: true, isChecked: true, hasTapAction: true),
      );
    });
  });

  group('selecting', () {
    testWidgets('a long press starts it: the bars replace the button, a tap '
        'selects, a task the user may not change cannot be selected', (
      tester,
    ) async {
      await pumpOverview(tester);
      expect(find.text(en.newTask), findsOneWidget);

      await select(tester, ['Call mum', 'Write report']);
      await tester.tap(find.text('Read only'));
      await tester.pumpAndSettle();

      expect(find.text(en.selectionCount(2)), findsOneWidget);
      expect(find.byType(TaskSelectionActionBar), findsOneWidget);
      expect(find.text(en.newTask), findsNothing);
      expect(find.byTooltip(en.taskAddFavourite).hitTestable(), findsNothing);

      await tester.tap(find.text('Write report'));
      await tester.pumpAndSettle();
      expect(find.text(en.selectionCount(1)), findsOneWidget);
      expect(data.tasks.writes, isEmpty);
    });

    testWidgets('Select all takes every task that may be changed; then it '
        'reads Deselect all', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);

      await tester.tap(find.text(en.selectionSelectAll));
      await tester.pumpAndSettle();
      expect(find.text(en.selectionCount(4)), findsOneWidget);

      await tester.tap(find.text(en.selectionDeselectAll));
      await tester.pumpAndSettle();
      expect(find.text(en.selectionCount(0)), findsOneWidget);
    });

    testWidgets('the close button and Back end it, announced', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);
      tester.takeAnnouncements();

      await tester.tap(find.byTooltip(en.selectionEnd));
      await tester.pumpAndSettle();
      expect(find.byType(TaskSelectionActionBar), findsNothing);
      expect(find.text(en.newTask), findsOneWidget);
      expect(said(tester), [en.selectionEnded]);

      await select(tester, ['Call mum']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TaskSelectionActionBar), findsNothing);
      expect(find.text('Call mum'), findsOneWidget);
    });

    testWidgets('Back with a sheet of the bar open closes only the sheet', (
      tester,
    ) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);
      await act(tester, en.taskDetailDueDate);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(en.selectionCount(1)), findsOneWidget);
    });

    testWidgets('a task just marked done, still shown while its Undo is '
        'offered, cannot be selected', (tester) async {
      await pumpOverview(tester);
      await tester.tap(
        find.descendant(
          of: row('Call mum'),
          matching: find.byTooltip(en.taskMarkDone),
        ),
      );
      await tester.pumpAndSettle();

      await select(tester, ['Write report']);
      await tester.tap(find.text('Call mum'));
      await tester.pumpAndSettle();
      expect(find.text(en.selectionCount(1)), findsOneWidget);
      await tester.tap(find.text(en.selectionSelectAll));
      await tester.pumpAndSettle();
      expect(find.text(en.selectionCount(3)), findsOneWidget);
    });

    testWidgets('a row does not swipe while the list selects', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);

      await swipe(tester, 'Write report', 250);

      expect(data.tasks.writes, isEmpty);
      expect(find.text(en.selectionCount(1)), findsOneWidget);
    });

    testWidgets('Back on another tab leaves it alone: it goes to the '
        'Overview, which still selects', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);

      await openTab(tester, en.tabUpcoming);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Call mum'), findsOneWidget);
      expect(find.text(en.selectionCount(1)), findsOneWidget);
    });

    testWidgets('Done marks the selected ones done; Undo takes it back', (
      tester,
    ) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);

      await act(tester, en.selectionMarkDone);

      expect(data.tasks.writes, ['setDone 3 true', 'setDone 5 true']);
      expect(find.text(en.tasksMarkedDone(2)), findsOneWidget);
      expect(find.byType(TaskSelectionActionBar), findsNothing);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(data.tasks.writes.skip(2), ['undoDone 3', 'undoDone 5']);
    });

    testWidgets('Due date keeps each task its time of day', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);

      await act(tester, en.taskDetailDueDate);
      expect(find.text(en.selectionDueDateTitle(2)), findsOneWidget);
      await tester.tap(find.text(en.shortcutTomorrow));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (
          3,
          TaskChanges(
            dueDate: dueChange(tomorrow.add(const Duration(hours: 18))),
          ),
        ),
        (
          5,
          TaskChanges(
            dueDate: dueChange(tomorrow.add(const Duration(hours: 10))),
          ),
        ),
      ]);
      expect(find.text(en.tasksDueDateChanged(2)), findsOneWidget);
    });

    testWidgets('Due date asks once when reminders would fall together; '
        'Cancel changes none', (tester) async {
      data.tasks.all = [
        for (final task in data.tasks.all)
          if (task.id == 3)
            task.copyWith(
              reminders: [
                const TaskReminder(
                  relativePeriod: Duration(days: -1),
                  relativeTo: ReminderRelativeTo.dueDate,
                ),
                TaskReminder(
                  reminder: today.add(const Duration(hours: 18)).toUtc(),
                ),
              ],
            )
          else
            task,
      ];
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);

      await act(tester, en.taskDetailDueDate);
      await tester.tap(find.text(en.shortcutTomorrow));
      await tester.pumpAndSettle();

      expect(find.text(en.tasksDueDateCoincideBody(1)), findsOneWidget);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();
      expect(data.tasks.updates, isEmpty);
      expect(find.byType(TaskSelectionActionBar), findsOneWidget);

      final reminders = data.tasks.find(3)!.reminders;
      await act(tester, en.taskDetailDueDate);
      await tester.tap(find.text(en.shortcutTomorrow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskDetailDueDateCoincideConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      // The Undo sends the reminders of the task whose reminders fell
      // together, which the server kept only one of.
      expect(data.tasks.updates.skip(2).map((update) => update.$1), [3, 5]);
      expect(data.tasks.updates[2].$2.reminders, reminders);
      expect(data.tasks.updates[3].$2.reminders, isNull);
    });

    testWidgets('Due date: Pick date sets the one moment picked for all, '
        'Clear removes it', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);
      await act(tester, en.taskDetailDueDate);
      await tester.tap(find.text(en.newTaskPickDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final picked = dueChange(DateTime(2026, 10, 20, 12));
      expect(data.tasks.updates, [
        (3, TaskChanges(dueDate: picked)),
        (5, TaskChanges(dueDate: picked)),
      ]);

      // At once: selecting again closes the snackbar that would cover the
      // bar.
      expect(find.text(en.tasksDueDateChanged(2)), findsOneWidget);
      await select(tester, ['Call mum']);
      expect(find.text(en.tasksDueDateChanged(2)), findsNothing);
      await act(tester, en.taskDetailDueDate);
      await tester.tap(find.text(en.taskEditClearDueDate));
      await tester.pumpAndSettle();
      expect(data.tasks.updates.last, (
        3,
        const TaskChanges(dueDate: DateChange.clear()),
      ));
    });

    testWidgets('Due date: Pick date with the clock cancelled still sets the '
        'day picked, at the default time, for all; Undo puts each one back', (
      tester,
    ) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);
      await act(tester, en.taskDetailDueDate);
      await tester.tap(find.text(en.newTaskPickDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final picked = dueChange(DateTime(2026, 10, 20, 12));
      expect(data.tasks.updates, [
        (3, TaskChanges(dueDate: picked)),
        (5, TaskChanges(dueDate: picked)),
      ]);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(
        [for (final update in data.tasks.updates.skip(2)) update.$2.dueDate],
        [
          dueChange(today.add(const Duration(hours: 18))),
          dueChange(DateTime(2026, 10, 13, 10)),
        ],
      );
    });

    testWidgets('Priority sets it; Undo puts each one back', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);

      await act(tester, en.taskDetailPriority);
      expect(find.text(en.selectionPriorityTitle(1)), findsOneWidget);
      await tester.tap(find.text(en.priorityHigh));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (3, const TaskChanges(priority: 3)),
        (3, const TaskChanges(priority: 0)),
      ]);
    });

    testWidgets('Move puts them in the project picked, named in the '
        'snackbar', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum', 'Write report']);

      await act(tester, en.selectionMove);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (3, const TaskChanges(projectId: 3)),
        (5, const TaskChanges(projectId: 3)),
      ]);
      expect(find.text(en.tasksMovedTo(2, 'Home')), findsOneWidget);
    });

    testWidgets('Delete asks first; on a server with the trash Undo '
        'restores them', (tester) async {
      await pumpOverview(tester, connection: fullServer280());
      await select(tester, ['Call mum', 'Write report']);

      await act(tester, en.selectionDelete);
      expect(find.text(en.tasksDeleteDialogTitle(2)), findsOneWidget);
      expect(find.text(en.tasksDeleteDialogBodyTrash(2)), findsOneWidget);
      // The dialog's button, above the bar's.
      await tester.tap(find.text(en.taskDeleteDialogConfirm).last);
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['delete 3', 'delete 5']);
      expect(find.text(en.tasksMovedToTrash(2)), findsOneWidget);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(data.tasks.writes.skip(2), ['restore 3', 'restore 5']);
      expect(find.text(en.tasksRestored(2)), findsOneWidget);
    });

    testWidgets('Delete of a task created on this device: Undo takes it '
        'back too, and the snackbar does not promise the trash', (
      tester,
    ) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(
          id: -1,
          title: 'Not sent yet',
          due: DateTime(2026, 10, 14, 9),
        ),
      ];
      await pumpOverview(tester, connection: fullServer280());
      await select(tester, ['Not sent yet', 'Write report']);

      await act(tester, en.selectionDelete);
      await tester.tap(find.text(en.taskDeleteDialogConfirm).last);
      await tester.pumpAndSettle();
      expect(find.text(en.tasksDeleted(2)), findsOneWidget);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, [
        'delete 5',
        'delete -1',
        'restore 5',
        'restore -1',
      ]);
    });

    testWidgets('Delete without the trash says they are deleted, without '
        'Undo', (tester) async {
      await pumpOverview(tester);
      await select(tester, ['Call mum']);

      await act(tester, en.selectionDelete);
      expect(find.text(en.tasksDeleteDialogBody(1)), findsOneWidget);
      // The dialog's button, above the bar's.
      await tester.tap(find.text(en.taskDeleteDialogConfirm).last);
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['delete 3']);
      expect(find.text(en.tasksDeleted(1)), findsOneWidget);
      expect(find.text(en.undo), findsNothing);
    });
  });

  group('Reschedule on the Overdue heading', () {
    testWidgets('moves the overdue tasks to today, each at its time of day '
        'while that is ahead, else 23:59; Undo puts them back', (tester) async {
      await pumpOverview(tester);

      await tester.tap(find.text(en.overdueReschedule));
      await tester.pumpAndSettle();
      // Not 'Shared bill', whose project the user may only read.
      expect(find.text(en.overdueRescheduleTitle(2)), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(en.shortcutToday),
        ),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (
          1,
          TaskChanges(
            dueDate: dueChange(
              today.add(const Duration(hours: 23, minutes: 59)),
            ),
          ),
        ),
        (
          2,
          TaskChanges(dueDate: dueChange(today.add(const Duration(hours: 18)))),
        ),
      ]);
      expect(data.tasks.updates.map((update) => update.$1), [1, 2]);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(data.tasks.updates.skip(2), [
        (
          1,
          TaskChanges(
            dueDate: dueChange(yesterday.add(const Duration(hours: 9))),
          ),
        ),
        (
          2,
          TaskChanges(
            dueDate: dueChange(yesterday.add(const Duration(hours: 18))),
          ),
        ),
      ]);
    });

    testWidgets('is not offered while selecting', (tester) async {
      await pumpOverview(tester);
      expect(find.text(en.overdueReschedule), findsOneWidget);

      await select(tester, ['Call mum']);

      expect(find.text(en.overdueReschedule), findsNothing);
    });
  });
}
