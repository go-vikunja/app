import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/common/presentation/list_section_header.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../accounts/accounts_harness.dart';

void main() {
  // A Tuesday.
  final now = DateTime(2026, 10, 13, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work', hexColor: '1973ff'),
      sampleProject(id: 3, title: 'Old', archived: true),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Pay the bill', due: DateTime(2026, 10, 12, 10)),
      sampleTask(id: 2, title: 'Earlier today', due: DateTime(2026, 10, 13, 9)),
      sampleTask(id: 3, title: 'Call mum', due: DateTime(2026, 10, 13, 18)),
      sampleTask(id: 4, title: 'Water plants', due: DateTime(2026, 10, 14, 9)),
      sampleTask(id: 5, title: 'Write report', due: DateTime(2026, 10, 16, 9)),
      sampleTask(id: 6, title: 'Plan trip', due: DateTime(2026, 10, 25)),
      sampleTask(id: 7, title: 'Someday'),
      sampleTask(
        id: 8,
        title: 'Already done',
        due: DateTime(2026, 10, 14),
        done: true,
      ),
      sampleTask(
        id: 9,
        title: 'Archived',
        projectId: 3,
        due: DateTime(2026, 10, 14),
      ),
    ];
    data.tasks.archivedProjectIds = {3};
  });

  Future<void> pumpUpcoming(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, en.tabUpcoming);
  }

  List<String> sectionTitles(WidgetTester tester) => [
    for (final header in tester.widgetList<ListSectionHeader>(
      find.byType(ListSectionHeader),
    ))
      header.title,
  ];

  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TaskRow>(find.byType(TaskRow)))
      row.task.title,
  ];

  // The item's text sits under an IgnorePointer; the item itself takes taps.
  Future<void> toggleMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is CheckedPopupMenuItem,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openRangeSheet(WidgetTester tester) async {
    await tester.tap(find.text(en.rangeNext7Days));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the next seven days by day below the pinned overdue '
      "tasks, with each task's project", (tester) async {
    await pumpUpcoming(tester);

    expect(find.byType(UpcomingScreen), findsOneWidget);
    expect(find.text(en.rangeNext7Days), findsOneWidget);
    expect(find.text('Oct 13 – Oct 20'), findsOneWidget);
    expect(sectionTitles(tester), [
      en.sectionOverdue,
      en.sectionToday,
      en.sectionTomorrow,
      'Fri, Oct 16',
    ]);
    expect(rowTitles(tester), [
      'Pay the bill',
      'Earlier today',
      'Call mum',
      'Water plants',
      'Write report',
    ]);
    expect(find.text('#3 · Work'), findsOneWidget);
    expect(data.listPreferences.saves, isEmpty);
  });

  testWidgets('the range button reads as one button with the range', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpUpcoming(tester);

    final node = tester.getSemantics(find.byType(OutlinedButton));
    expect(
      node.label,
      en.upcomingRangeSemantics(en.rangeNext7Days, 'Oct 13 – Oct 20'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('the overflow toggles the overdue and the undated tasks, '
      'saved for the account', (tester) async {
    await pumpUpcoming(tester);

    await toggleMenuItem(tester, en.upcomingShowWithoutDate);
    expect(sectionTitles(tester).last, en.sectionNoDueDate);
    expect(rowTitles(tester).last, 'Someday');
    expect(data.listPreferences.upcoming.showWithoutDueDate, isTrue);

    await toggleMenuItem(tester, en.upcomingShowOverdue);
    // From now on: the task due this morning is neither overdue nor in it.
    expect(sectionTitles(tester).first, en.sectionToday);
    expect(rowTitles(tester), isNot(contains('Earlier today')));
    expect(rowTitles(tester), isNot(contains('Pay the bill')));
    expect(data.listPreferences.upcoming.showOverdue, isFalse);
    expect(data.listPreferences.saves, ['upcoming', 'upcoming']);

    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
    final items = tester
        .widgetList<CheckedPopupMenuItem<Object>>(
          find.byWidgetPredicate((widget) => widget is CheckedPopupMenuItem),
        )
        .map((item) => item.checked);
    expect(items, [false, true]);
  });

  testWidgets('the range sheet lists the web presets and picks one', (
    tester,
  ) async {
    await pumpUpcoming(tester);
    await openRangeSheet(tester);

    final sheet = find.byType(DraggableScrollableSheet);
    expect(find.text(en.upcomingSelectRange), findsOneWidget);
    for (final label in [
      en.rangeToday,
      en.rangeLastWeek,
      en.rangeRestOfThisWeek,
      en.rangeNext30Days,
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.text(en.upcomingRangeCustomEntry),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(en.upcomingRangeCustomEntry), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(en.rangeThisMonth),
      -100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(en.rangeThisMonth));
    await tester.pumpAndSettle();

    expect(data.listPreferences.upcoming.preset, DateRangePreset.thisMonth);
    expect(find.text(en.rangeThisMonth), findsOneWidget);
    expect(find.text('Oct 1 – Oct 31'), findsOneWidget);
    expect(rowTitles(tester), contains('Plan trip'));
    // Overdue tasks stay pinned above and are not repeated in their day.
    expect(
      rowTitles(tester).where((title) => title == 'Pay the bill'),
      hasLength(1),
    );
    expect(sectionTitles(tester).first, en.sectionOverdue);
  });

  testWidgets('a stored range opens as it was left', (tester) async {
    data.listPreferences.setUpcoming(
      const UpcomingPreferences(preset: DateRangePreset.tomorrow),
    );
    await pumpUpcoming(tester);

    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.text(en.rangeTomorrow),
      ),
      findsOneWidget,
    );
    expect(find.text('Oct 14'), findsOneWidget);
    expect(sectionTitles(tester), [en.sectionOverdue, en.sectionTomorrow]);
    expect(rowTitles(tester), [
      'Pay the bill',
      'Earlier today',
      'Water plants',
    ]);
  });

  testWidgets('a custom range comes from the date pickers', (tester) async {
    await pumpUpcoming(tester);
    await openRangeSheet(tester);
    await tester.scrollUntilVisible(
      find.text(en.upcomingRangeCustomEntry),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(en.upcomingRangeCustomEntry));
    await tester.pumpAndSettle();

    // The first day, then the last, each starting on the current range's.
    expect(find.text(en.upcomingRangeFrom), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(en.upcomingRangeTo), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final saved = data.listPreferences.upcoming;
    expect(saved.preset, isNull);
    expect(saved.customFrom, DateTime(2026, 10, 13));
    expect(saved.customTo, DateTime(2026, 10, 20));
    expect(find.text(en.upcomingRangeCustom), findsOneWidget);
    expect(find.text('Oct 13 – Oct 20'), findsOneWidget);
    // Whole days now: the task due this morning is back in Today.
    expect(sectionTitles(tester).take(2), [en.sectionOverdue, en.sectionToday]);
  });

  testWidgets('on iOS the custom range comes from date wheels', (tester) async {
    await pumpUpcoming(tester);
    await openRangeSheet(tester);
    await tester.scrollUntilVisible(
      find.text(en.upcomingRangeCustomEntry),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(en.upcomingRangeCustomEntry));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    // Each end shows its day, the one the wheel does not show included.
    expect(find.text('Oct 13'), findsOneWidget);
    expect(find.text('Oct 20'), findsOneWidget);
    await tester.tap(find.text(en.upcomingRangeTo));
    await tester.pumpAndSettle();
    expect(find.text('Oct 13'), findsOneWidget);
    await tester.tap(find.text(en.pickerDone));
    await tester.pumpAndSettle();

    final saved = data.listPreferences.upcoming;
    expect(saved.preset, isNull);
    expect(saved.customFrom, DateTime(2026, 10, 13));
    expect(saved.customTo, DateTime(2026, 10, 20));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('without tasks in the range says there is nothing to do', (
    tester,
  ) async {
    data.tasks.all = [
      sampleTask(
        id: 6,
        title: 'Plan trip',
        due: now.add(const Duration(days: 30)),
      ),
    ];
    await pumpUpcoming(tester);

    expect(find.text(en.upcomingEmptyTitle), findsOneWidget);
    expect(find.byType(TaskRow), findsNothing);
  });

  testWidgets('a task marked done stays until its snackbar hides', (
    tester,
  ) async {
    await pumpUpcoming(tester);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TaskRow, 'Call mum'),
        matching: find.byTooltip(en.taskMarkDone),
      ),
    );
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true']);
    expect(
      tester.widget<Text>(find.text('Call mum')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(sectionTitles(tester), contains(en.sectionToday));

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    expect(find.text('Call mum'), findsNothing);
    expect(sectionTitles(tester), isNot(contains(en.sectionToday)));
  });

  testWidgets('pull to refresh syncs', (tester) async {
    await pumpUpcoming(tester);

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(data.engine.refreshCalls, 1);
  });

  testWidgets('in German', (tester) async {
    useLocale(tester, const Locale('de'));
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
    await pumpSignedInApp(tester, sync: data, now: now);
    await openTab(tester, de.tabUpcoming);

    expect(find.text(de.rangeNext7Days), findsOneWidget);
    expect(sectionTitles(tester).take(3), [
      de.sectionOverdue,
      de.sectionToday,
      de.sectionTomorrow,
    ]);
  });

  testWidgets('an account switch shows the other account with its own range', (
    tester,
  ) async {
    final accounts = ThreeAccounts();
    await accounts.seed(withCarol: false);
    final tomorrow = accounts.now.add(const Duration(days: 1));
    accounts.aliceData.tasks.all = [
      sampleTask(id: 1, title: 'Alice task', due: tomorrow),
    ];
    accounts.aliceData.listPreferences.setUpcoming(
      const UpcomingPreferences(preset: DateRangePreset.next30Days),
    );
    accounts.bobData.tasks.all = [
      sampleTask(id: 1, title: 'Bob task', due: tomorrow),
    ];
    await accounts.pump(tester);
    await openTab(tester, en.tabUpcoming);
    expect(find.text('Alice task'), findsOneWidget);
    expect(find.text(en.rangeNext30Days), findsOneWidget);

    await containerOf(tester)
        .read(accountSwitcherProvider)
        .switchTo(accounts.bob.id);
    await tester.pumpAndSettle();
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      AppRoutes.overview,
    );

    await openTab(tester, en.tabUpcoming);
    expect(find.text('Bob task'), findsOneWidget);
    expect(find.text('Alice task'), findsNothing);
    expect(find.text(en.rangeNext7Days), findsOneWidget);
  });
}
