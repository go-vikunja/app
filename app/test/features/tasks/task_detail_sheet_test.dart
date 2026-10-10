import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

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
    expect(
      inSheet(en.taskDetailIdentifierInProject('WORK-1', 'Work')),
      findsOneWidget,
    );
    final done = tester.widget<CheckboxListTile>(
      find.descendant(of: sheet, matching: find.byType(CheckboxListTile)),
    );
    expect(done.value, isFalse);
    expect(inSheet(en.taskDone), findsOneWidget);
    expect(inSheet(en.taskDetailDueDate), findsOneWidget);
    expect(inSheet('Oct 12, 2026 9:30 AM'), findsOneWidget);
    expect(inSheet('Oct 11, 2026 8:00 AM'), findsOneWidget);
    expect(inSheet(en.priorityHigh), findsNWidgets(2));
    expect(inSheet(en.taskPercentDone(50)), findsOneWidget);
    expect(inSheet('Every 2 weeks'), findsOneWidget);
    expect(inSheet('1 hour before the due date'), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.byType(LabelChip)),
      findsOneWidget,
    );
    expect(inSheet('AE'), findsOneWidget);
    expect(inSheet('Alice Example'), findsOneWidget);
    expect(inSheet('bob'), findsOneWidget);
    expect(inSheet('Numbers & charts\n• revenue'), findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.byTooltip(en.taskRemoveFavourite),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a bare task shows only its status and no description', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');

    final sheet = find.byType(TaskDetailSheet);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(en.taskDetailIdentifierInProject('#2', 'Work')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(en.taskDetailNoDescription),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(en.taskDetailDueDate)),
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

    await tester.tap(find.text(en.tabProjects), warnIfMissed: false);
    await tester.pumpAndSettle();
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

  testWidgets('dates are localized in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await openDetail(tester, 'Quarterly report');

    expect(find.text('12. Okt. 2026 09:30'), findsOneWidget);
    expect(find.text('Alle 2 Wochen'), findsOneWidget);
  });
}
