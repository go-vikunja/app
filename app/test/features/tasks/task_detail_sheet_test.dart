import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', identifier: 'WORK'),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarterly report',
        identifier: 'WORK-1',
        due: DateTime(2026, 10, 12, 9, 30),
        start: DateTime(2026, 10, 11, 8),
        priority: TaskPriority.high,
        percentDone: 0.5,
        labels: [sampleLabel(id: 1, title: 'Finance', hexColor: 'ffeb10')],
        assignees: const [
          User(id: 7, username: 'alice', name: 'Alice Example'),
          User(id: 8, username: 'bob'),
        ],
        reminders: const [
          TaskReminder(
            relativePeriod: Duration(hours: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ],
        repeatAfter: const Duration(days: 14),
        favorite: true,
        description:
            '<p>Numbers &amp; charts</p><ul><li><p>revenue</p></li></ul>',
      ),
      sampleTask(id: 2, title: 'Bare task'),
    ];
  });

  Future<void> openDetail(
    WidgetTester tester,
    String title, {
    double width = 360,
  }) async {
    // Tall enough for the whole sheet, which builds its rows lazily.
    usePhoneSurface(tester, logicalSize: Size(width, 2200));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('shows everything the list knows about the task', (tester) async {
    await openDetail(tester, 'Quarterly report');

    final sheet = find.byType(TaskDetailSheet);
    expect(sheet, findsOneWidget);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('Quarterly report'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('WORK-1')),
      findsNothing,
    );
    expect(inSheet('Work'), findsOneWidget);
    expect(inSheet(en.taskDetailStatusOpen), findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, en.taskDetailMarkDone),
      ),
      findsOneWidget,
    );
    expect(inSheet(en.taskDetailDueDateRow), findsOneWidget);
    expect(inSheet('Oct 12, 2026 9:30 AM'), findsOneWidget);
    expect(inSheet('Oct 11, 2026 8:00 AM'), findsOneWidget);
    expect(inSheet(en.priorityHigh), findsOneWidget);
    expect(inSheet(en.taskPercentDone(50)), findsOneWidget);
    expect(inSheet('Every 2 weeks'), findsOneWidget);
    expect(inSheet('1 hour before the due date'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(LabelPill)),
      findsOneWidget,
    );
    expect(inSheet('AE'), findsOneWidget);
    expect(inSheet('Alice Example'), findsOneWidget);
    expect(inSheet('bob'), findsOneWidget);
    expect(inSheet('Numbers & charts'), findsOneWidget);
    expect(inSheet('revenue'), findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.byTooltip(en.taskRemoveFavourite),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a bare task shows its status, no property rows, and offers '
      'a description and each property', (tester) async {
    await openDetail(tester, 'Bare task');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(en.taskDetailStatusOpen)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(en.taskDetailAddDescription),
      ),
      findsOneWidget,
    );
    final addLine = find.descendant(
      of: sheet,
      matching: find.byType(AddAttributeLine),
    );
    expect(addLine, findsOneWidget);
    // In English the due-date row's name reads as the add button does, so
    // its one "Due date" is the button's.
    expect(en.taskDetailDueDateRow, en.taskDetailDueDate);
    for (final name in [en.taskDetailDueDate, en.taskDetailPriority]) {
      expect(
        find.descendant(of: sheet, matching: find.text(name)),
        findsOneWidget,
        reason: name,
      );
      expect(
        find.descendant(
          of: addLine,
          matching: find.widgetWithText(TextButton, name),
        ),
        findsOneWidget,
        reason: name,
      );
    }
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    await openDetail(tester, 'Bare task');

    await tester.tap(find.byTooltip(en.taskDetailClose));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsNothing);
  });

  testWidgets('opens over the tab bar, which it blocks', (tester) async {
    usePhoneSurface(tester);
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text('Bare task'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(find.byType(TaskDetailSheet));
    expect(
      identical(
        ModalRoute.of(sheetContext)!.navigator,
        Navigator.of(sheetContext, rootNavigator: true),
      ),
      isTrue,
    );
    expect(
      tester.getRect(find.byType(AnimatedModalBarrier)).bottom,
      greaterThanOrEqualTo(
        tester.getRect(find.byType(AdaptiveNavigationBar)).bottom,
      ),
    );

    // The sheet's own controls lie over the tab, so a tap there would
    // reach them; nothing of the bar may take it.
    final hit = HitTestResult();
    tester.binding.hitTestInView(
      hit,
      tester.getCenter(find.text(en.tabProjects)),
      tester.view.viewId,
    );
    final bar = tester.renderObject(find.byType(AdaptiveNavigationBar));
    expect(hit.path.where((entry) => entry.target == bar), isEmpty);
    expect(find.byType(ProjectsScreen), findsNothing);
    expect(find.byType(TaskDetailSheet), findsOneWidget);
  });

  testWidgets('is a Cupertino sheet on iOS', (tester) async {
    await openDetail(tester, 'Bare task');

    expect(find.byType(TaskDetailSheet), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(TaskDetailSheet)));
    expect(route, isA<CupertinoSheetRoute<void>>());

    await tester.tap(find.byTooltip(en.taskDetailClose));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("the project's chip leads the header, beside the actions; the "
      'state and the pending note follow the title', (tester) async {
    data.tasks.pendingTaskIds = {1};
    // Room for the chip beside five actions.
    await openDetail(tester, 'Quarterly report', width: 480);

    final sheet = find.byType(TaskDetailSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    final chip = inSheet(find.widgetWithText(ActionChip, 'Work'));
    final title = inSheet(find.text('Quarterly report'));
    expect(chip, findsOneWidget);
    expect(
      tester.getCenter(chip).dy,
      closeTo(tester.getCenter(inSheet(find.byTooltip(en.taskEdit))).dy, 1),
    );
    expect(
      tester.getCenter(chip).dx,
      lessThan(tester.getTopLeft(inSheet(find.byTooltip(en.taskEdit))).dx),
    );
    expect(
      tester.getBottomLeft(chip).dy,
      lessThan(tester.getTopLeft(title).dy),
    );
    for (final text in [en.taskDetailStatusOpen, en.taskNotYetSynced]) {
      expect(
        tester.getTopLeft(inSheet(find.text(text))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(title).dy),
        reason: text,
      );
    }
  });

  group('a project path too long for the header', () {
    // On the test font's square glyphs a phone has room for this one below
    // the actions, but not beside them.
    Future<void> expectOwnLineUncut(WidgetTester tester, String title) async {
      data.projects.all = [
        sampleProject(id: 2, title: 'Personal'),
        sampleProject(id: 3, title: title, parent: 2),
      ];
      data.tasks.all = [
        sampleTask(id: 3, title: 'Clean the kitchen', projectId: 3),
      ];
      await openDetail(tester, 'Clean the kitchen');

      final sheet = find.byType(TaskDetailSheet);
      Finder inSheet(Finder finder) =>
          find.descendant(of: sheet, matching: finder);
      final chip = inSheet(find.widgetWithText(ActionChip, title));
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.descendant(of: chip, matching: find.text(title)),
          matching: find.byType(RichText),
        ),
      );
      expect(label.debugHasOverflowShader, isFalse);
      expect(label.didExceedMaxLines, isFalse);
      final edit = tester.getRect(inSheet(find.byTooltip(en.taskEdit)));
      final close = tester.getRect(inSheet(find.byTooltip(en.taskDetailClose)));
      expect(edit.center.dy, closeTo(close.center.dy, 1));
      final parent = inSheet(find.text('Personal'));
      final taskTitle = inSheet(find.text('Clean the kitchen'));
      for (final part in [parent, chip]) {
        expect(tester.getTopLeft(part).dy, greaterThanOrEqualTo(edit.bottom));
        expect(
          tester.getBottomLeft(part).dy,
          lessThanOrEqualTo(tester.getTopLeft(taskTitle).dy),
        );
      }
      expect(
        tester.getTopLeft(parent).dx,
        closeTo(tester.getTopLeft(taskTitle).dx, 4),
      );
      expect(tester.takeException(), isNull);
    }

    testWidgets('goes on a line of its own below the actions, uncut', (
      tester,
    ) async {
      await expectOwnLineUncut(tester, 'Household chores');
    });

    testWidgets('at 200 % text too', (tester) async {
      useAccessibilityExtremes(tester);
      await expectOwnLineUncut(tester, 'Chores');
    });
  });

  testWidgets('offers Edit and the project of a task not yet sent', (
    tester,
  ) async {
    await data.tasks.createTask(
      const NewTask(projectId: 1, title: 'Just added'),
    );
    await openDetail(tester, 'Just added');

    final sheet = find.byType(TaskDetailSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    expect(inSheet(find.byTooltip(en.taskEdit)), findsOneWidget);
    expect(inSheet(find.widgetWithText(ActionChip, 'Work')), findsOneWidget);
    expect(inSheet(find.textContaining('#0')), findsNothing);
    expect(inSheet(find.textContaining('WORK-0')), findsNothing);
  });

  testWidgets('follows the task to the id the server assigns', (tester) async {
    final localId = await data.tasks.createTask(
      const NewTask(projectId: 1, title: 'Just added'),
    );
    await openDetail(tester, 'Just added');

    data.tasks.remapTask(localId, 77);
    await tester.pumpAndSettle();
    data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id == 77) task.copyWith(title: 'Renamed later') else task,
    ];
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TaskDetailSheet),
        matching: find.text('Renamed later'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('labels, assignees and reminders follow the row after a save', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');
    final sheet = find.byType(TaskDetailSheet);
    Finder inSheet(Finder finder) =>
        find.descendant(of: sheet, matching: finder);
    expect(inSheet(find.byType(LabelPill)), findsNothing);

    // Only the child rows change, as a local save of these fields does.
    data.tasks.all = [
      data.tasks.all.first,
      data.tasks
          .find(2)!
          .copyWith(
            labels: [sampleLabel(id: 3, title: 'Errand')],
            assignees: const [User(id: 7, username: 'alice', name: 'Alice')],
            reminders: const [
              TaskReminder(
                relativePeriod: Duration(days: -1),
                relativeTo: ReminderRelativeTo.dueDate,
              ),
            ],
          ),
    ];
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Errand')), findsOneWidget);
    expect(inSheet(find.text('Alice')), findsOneWidget);
    expect(
      inSheet(
        find.text(en.reminderBefore('1 day', en.reminderReferenceDueDate)),
      ),
      findsOneWidget,
    );

    data.tasks.all = [
      data.tasks.all.first,
      data.tasks
          .find(2)!
          .copyWith(
            labels: const [],
            assignees: const [],
            reminders: const [],
            repeatAfter: const Duration(days: 1),
          ),
    ];
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Errand')), findsNothing);
    expect(inSheet(find.text('Alice')), findsNothing);
    expect(inSheet(find.text(en.repeatEveryDay)), findsOneWidget);
  });

  testWidgets('dates are localized in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await openDetail(tester, 'Quarterly report');

    expect(find.text('12. Okt. 2026 09:30'), findsOneWidget);
    expect(find.text('Alle 2 Wochen'), findsOneWidget);
  });

  testWidgets('the attribute card puts each value beside its name', (
    tester,
  ) async {
    // The test font's names are wider than Roboto's; at 360 they would not
    // leave the value room (task_detail_attribute_names_test.dart measures
    // a phone in Roboto).
    await openDetail(tester, 'Quarterly report', width: 480);

    final name = tester.getRect(find.text(en.taskDetailDueDateRow));
    final value = tester.getRect(find.text('Oct 12, 2026 9:30 AM'));
    expect(value.left, greaterThan(name.right));
    expect(value.center.dy, closeTo(name.center.dy, 1));
  });

  Finder sheetText(String text) => find.descendant(
    of: find.byType(TaskDetailSheet),
    matching: find.text(text),
  );

  bool onOneLine(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(sheetText(text));
    return paragraph.size.height ==
        paragraph.getMinIntrinsicHeight(double.infinity);
  }

  testWidgets('a long German name stays on one line beside its value', (
    tester,
  ) async {
    useLocale(tester, const Locale('de'));
    await openDetail(tester, 'Quarterly report', width: 600);

    expect(onOneLine(tester, de.taskDetailAssignees), isTrue);
    final name = tester.getRect(sheetText(de.taskDetailAssignees));
    final value = tester.getRect(sheetText('Alice Example'));
    expect(value.left, greaterThan(name.right));
  });

  testWidgets('every row puts its value under its name when the longest '
      'name leaves too little room beside it', (tester) async {
    useLocale(tester, const Locale('de'));
    await openDetail(tester, 'Quarterly report', width: 400);

    for (final (label, value) in [
      (de.taskDetailAssignees, 'Alice Example'),
      (de.taskDetailPriority, de.priorityHigh),
    ]) {
      expect(onOneLine(tester, label), isTrue, reason: label);
      expect(
        tester.getRect(sheetText(value)).top,
        greaterThanOrEqualTo(tester.getRect(sheetText(label)).bottom),
        reason: label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 200 % text the attribute card puts each value under its '
      'name', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openDetail(tester, 'Quarterly report');

    final name = tester.getRect(find.text(en.taskDetailDueDateRow));
    final value = tester.getRect(find.text('Oct 12, 2026 9:30 AM'));
    expect(value.top, greaterThanOrEqualTo(name.bottom));
    expect(value.left, closeTo(name.left, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an overdue due date has its own icon and says it is overdue', (
    tester,
  ) async {
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(
        id: 3,
        title: 'Late invoice',
        due: DateTime(2026, 10, 9, 9, 30),
      ),
    ];
    await openDetail(tester, 'Late invoice');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.error_outline)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.event_outlined)),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.text('Oct 9, 2026 9:30 AM')).label,
      contains(en.taskOverdueSemantics('Oct 9, 2026 9:30 AM')),
    );
  });

  testWidgets('a due date still to come keeps the calendar icon', (
    tester,
  ) async {
    await openDetail(tester, 'Quarterly report');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.event_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.byIcon(Icons.error_outline)),
      findsNothing,
    );
    expect(
      tester.getSemantics(find.text('Oct 12, 2026 9:30 AM')).label,
      isNot(contains(en.taskOverdueSemantics('Oct 12, 2026 9:30 AM'))),
    );
  });
}
