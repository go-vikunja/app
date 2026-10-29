import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
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

  Future<void> openDetail(WidgetTester tester, String title) async {
    // Tall enough for the whole sheet, which builds its rows lazily.
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
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
    expect(inSheet('WORK-1'), findsOneWidget);
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

  testWidgets('a bare task shows only its status and offers a description', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('WORK-2')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(en.taskDetailAddDescription),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(en.taskDetailDueDateRow)),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(en.taskDetailPriority)),
      findsNothing,
    );
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

  testWidgets('offers Edit and hides the identifier of a task not yet sent', (
    tester,
  ) async {
    await data.tasks.createTask(
      const NewTask(projectId: 1, title: 'Just added'),
    );
    await openDetail(tester, 'Just added');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(of: sheet, matching: find.byTooltip(en.taskEdit)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Work')),
      findsOneWidget,
    );
    expect(find.descendant(of: sheet, matching: find.text('#0')), findsNothing);
    expect(
      find.descendant(of: sheet, matching: find.text('WORK-0')),
      findsNothing,
    );
  });

  testWidgets('follows the task to the id the server assigns', (tester) async {
    final localId = await data.tasks.createTask(
      const NewTask(projectId: 1, title: 'Just added'),
    );
    await openDetail(tester, 'Just added');

    // The fake keeps index 0; the identifier line appears once the id is
    // the server's.
    data.tasks.remapTask(localId, 77);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TaskDetailSheet),
        matching: find.text('WORK-0'),
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
    expect(inSheet(find.text(en.repeatEveryDays(1))), findsOneWidget);
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
    await openDetail(tester, 'Quarterly report');

    final name = tester.getRect(find.text(en.taskDetailDueDateRow));
    final value = tester.getRect(find.text('Oct 12, 2026 9:30 AM'));
    expect(value.left, greaterThan(name.right));
    expect(value.center.dy, closeTo(name.center.dy, 1));
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
