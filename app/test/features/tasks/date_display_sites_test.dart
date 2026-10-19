import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../inbox/inbox_samples.dart';
import '../quick_add/presentation/composer_harness.dart';
import 'edit_page_harness.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna');

/// The web's `date_display` and `time_format` where the app shows dates;
/// the formats themselves are pinned in moment_formatter_test.dart.
void main() {
  final now = DateTime(2026, 10, 12, 12);
  const slashed = UserSettings(
    dateDisplay: DateDisplay.dayMonthYearSlashed,
    timeFormat: TimeFormat.twentyFourHour,
  );
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
        due: DateTime(2026, 10, 14, 9, 30),
        start: DateTime(2026, 10, 13, 8),
        reminders: [TaskReminder(reminder: DateTime(2026, 10, 14, 8).toUtc())],
        created: DateTime(2026, 10, 10, 12),
        updated: DateTime(2026, 10, 12, 11),
        createdBy: _anna,
      ),
    ];
    data.details.detailsByTask[1] = const TaskDetails(commentCount: 1);
    data.details.commentsByTask[1] = [
      sampleComment(id: 1, created: DateTime(2026, 10, 11, 7, 15)),
    ];
  });

  Finder inSheet(String text) => find.descendant(
    of: find.byType(TaskDetailSheet),
    matching: find.text(text),
  );

  Future<void> openDetail(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text('Quarterly report'));
    await tester.pumpAndSettle();
  }

  group('never set', () {
    testWidgets("the rows stay relative and the sheet keeps the device's "
        'format', (tester) async {
      await openDetail(tester);

      expect(find.text('in 2 days'), findsOneWidget);
      expect(inSheet('Oct 14, 2026 9:30 AM'), findsOneWidget);
      expect(inSheet('Oct 14, 2026 8:00 AM'), findsOneWidget);
      expect(inSheet(en.taskDetailCreatedBy('2 days ago', 'Anna')), findsOne);
    });
  });

  group('an absolute display', () {
    setUp(() => data.shared.settings = slashed);

    testWidgets('replaces the relative due date of the rows; screen readers '
        'hear the long date', (tester) async {
      final semantics = tester.ensureSemantics();
      usePhoneSurface(tester);
      await pumpSignedInApp(tester, sync: data, now: now);

      expect(find.text('14/10/2026 09:30'), findsOneWidget);
      expect(find.text('in 2 days'), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              en.taskDueSemantics('Wednesday, October 14, 2026 at 09:30'),
            ),
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows on the sheet: dates, absolute reminders, the metadata '
        'line and comments', (tester) async {
      final semantics = tester.ensureSemantics();
      await openDetail(tester);

      expect(inSheet('14/10/2026 09:30'), findsOneWidget);
      expect(inSheet('13/10/2026 08:00'), findsOneWidget);
      expect(inSheet('14/10/2026 08:00'), findsOneWidget);
      expect(
        inSheet(en.taskDetailCreatedBy('10/10/2026 12:00', 'Anna')),
        findsOneWidget,
      );
      expect(inSheet(en.taskDetailUpdated('12/10/2026 11:00')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('Wednesday, October 14, 2026 at 09:30')),
        ),
        findsWidgets,
      );
      expect(
        find.bySemanticsLabel(
          en.taskDetailCreatedBy('Saturday, October 10, 2026 at 12:00', 'Anna'),
        ),
        findsOneWidget,
      );
      // The absolute reminder.
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('Wednesday, October 14, 2026 at 08:00')),
        ),
        findsWidgets,
      );

      await tester.ensureVisible(inSheet(en.taskDetailShowComments));
      await tester.tap(inSheet(en.taskDetailShowComments));
      await tester.pumpAndSettle();
      expect(inSheet('11/10/2026 07:15'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets("shows on the edit page's dates and reminders; screen "
        'readers hear the long date, in the reminder picker too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openEditPageWith(tester, data: data, taskId: 1, now: now);

      expect(find.text('14/10/2026 09:30'), findsOneWidget);
      expect(find.text('13/10/2026 08:00'), findsOneWidget);
      expect(find.text('14/10/2026 08:00'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape('Wednesday, October 14, 2026 at 08:00')),
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip(
          en.taskEditRemoveReminder('Wednesday, October 14, 2026 at 08:00'),
        ),
        findsOneWidget,
      );

      await tapVisible(tester, find.text(en.taskEditAddReminder));
      expect(
        find.descendant(
          of: find.byType(ReminderPicker),
          matching: find.text('13/10/2026 09:30'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ReminderPicker),
          matching: find.bySemanticsLabel(
            RegExp(RegExp.escape('Tuesday, October 13, 2026 at 09:30')),
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows on the new-task sheet: the picked date and the '
        'preview of a date in the text', (tester) async {
      final harness = ComposerHarness()..settings = slashed;
      await harness.open(tester);

      await tester.tap(find.text(en.newTaskPickDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(InputChip, '20/10/2026 12:00'),
        findsOneWidget,
      );

      await typeLine(tester, 'Call mom tomorrow');
      await tester.pumpAndSettle();
      expect(find.textContaining('11/10/2026 '), findsOneWidget);
    });

    testWidgets("screen readers hear the long date of the new-task sheet's "
        'chips', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = ComposerHarness()..settings = slashed;
      await harness.open(tester);

      await typeLine(tester, 'Call mom tomorrow at 9:00');
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          en.quickAddDueSemantics(
            'Sunday, October 11, 2026 at 09:00',
            'in 21 hours',
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows in the inbox', (tester) async {
      data.activity.notifications = [
        inboxNotification(
          id: 1,
          name: 'task.comment',
          created: DateTime(2026, 10, 12, 9, 45),
          payload: {
            'doer': payloadUser(id: 2, username: 'anna', name: 'Anna'),
            'task': payloadTask(id: 1, title: 'Quarterly report'),
            'comment': {'id': 1, 'comment': '<p>Done</p>'},
          },
        ),
      ];
      await pumpSignedInApp(tester, sync: data, now: now);
      await tester.tap(find.byType(InboxButton));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(InboxScreen),
          matching: find.textContaining('12/10/2026 09:45'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('follows a change of the setting at once', (tester) async {
      usePhoneSurface(tester);
      await pumpSignedInApp(tester, sync: data, now: now);
      expect(find.text('14/10/2026 09:30'), findsOneWidget);

      data.shared.settings = const UserSettings(
        dateDisplay: DateDisplay.yearMonthDayDashed,
        timeFormat: TimeFormat.twelveHour,
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-10-14 09:30 AM'), findsOneWidget);
    });
  });

  testWidgets('the relative display keeps the device format on the sheet '
      'and says "just now" within a minute', (tester) async {
    data.shared.settings = const UserSettings(
      dateDisplay: DateDisplay.relative,
    );
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(
        id: 2,
        title: 'Right now',
        due: now.add(const Duration(seconds: 50)),
      ),
    ];
    await openDetail(tester);

    expect(inSheet('Oct 14, 2026 9:30 AM'), findsOneWidget);
    await tester.tap(find.byTooltip(en.taskDetailClose));
    await tester.pumpAndSettle();
    expect(find.text(en.relativeJustNow), findsOneWidget);
  });

  testWidgets('a time format alone changes the clock, not the dates', (
    tester,
  ) async {
    data.shared.settings = const UserSettings(
      timeFormat: TimeFormat.twentyFourHour,
    );
    await openDetail(tester);

    expect(find.text('in 2 days'), findsOneWidget);
    expect(inSheet('Oct 14, 2026 09:30'), findsOneWidget);
  });

  testWidgets('12 hours in German', (tester) async {
    useLocale(tester, const Locale('de'));
    data.shared.settings = const UserSettings(
      timeFormat: TimeFormat.twelveHour,
    );
    await openDetail(tester);

    expect(inSheet('14. Okt. 2026 9:30 AM'), findsOneWidget);
  });

  testWidgets("at 200 % the new-task sheet's picked date wraps instead of "
      'fading out its time', (tester) async {
    useAccessibilityExtremes(tester);
    final harness = ComposerHarness()
      ..settings = const UserSettings(
        dateDisplay: DateDisplay.weekdayDayMonthYear,
        timeFormat: TimeFormat.twentyFourHour,
      );
    await harness.open(tester);

    await typeLine(tester, 'Call mom in 11 days at 14:05');
    await tester.pumpAndSettle();

    final label = find.descendant(
      of: find.byType(InputChip),
      matching: find.text('Wednesday, October 21, 2026 at 14:05'),
    );
    expect(label, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.debugHasOverflowShader, isFalse);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(paragraph.textSize.height),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a written display in German', (tester) async {
    useLocale(tester, const Locale('de'));
    data.shared.settings = const UserSettings(
      dateDisplay: DateDisplay.weekdayDayMonthYear,
      timeFormat: TimeFormat.twentyFourHour,
    );
    await openDetail(tester);

    expect(inSheet('Mittwoch, 14. Oktober 2026 um 09:30'), findsOneWidget);
  });
}
