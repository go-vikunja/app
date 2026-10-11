import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import 'edit_page_harness.dart';

void main() {
  // A Saturday at noon: the breakpoint time is 12:00.
  final now = DateTime(2026, 10, 10, 12);
  final due = DateTime(2026, 10, 12, 9, 30);
  final start = DateTime(2026, 10, 11, 8);
  final end = DateTime(2026, 10, 14, 17);
  late SyncFakes data;

  TaskReminder relative(Duration period, ReminderRelativeTo to) =>
      TaskReminder(relativePeriod: period, relativeTo: to);

  String before(String period, String reference) =>
      en.reminderBefore(period, reference);

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
  });

  Future<void> openTask(WidgetTester tester, Task task) async {
    data.tasks.all = [task];
    await openEditPageWith(tester, data: data, taskId: task.id, now: now);
  }

  Finder sheet() => find.byType(ReminderPicker);

  Finder inSheet(Finder finder) =>
      find.descendant(of: sheet(), matching: finder);

  Future<void> openAddSheet(WidgetTester tester) =>
      tapVisible(tester, find.text(en.taskEditAddReminder));

  Finder amountField() =>
      find.widgetWithText(TextField, en.reminderAmountLabel);

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(inSheet(find.widgetWithText(ChoiceChip, label)))
      .selected;

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(inSheet(find.widgetWithText(ChoiceChip, label)));
    await tester.pumpAndSettle();
  }

  bool sheetDoneEnabled(WidgetTester tester) =>
      tester
          .widget<TextButton>(
            inSheet(find.widgetWithText(TextButton, en.pickerDone)),
          )
          .onPressed !=
      null;

  group('presets', () {
    testWidgets('are relative to the due date when the task has one', (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(id: 1, title: 'Report', due: due, start: start),
      );
      await openAddSheet(tester);

      final dueRef = en.reminderReferenceDueDate;
      for (final text in [
        en.reminderAtReference(dueRef),
        before('2 hours', dueRef),
        before('1 day', dueRef),
        before('3 days', dueRef),
        before('1 week', dueRef),
        before('30 days', dueRef),
      ]) {
        expect(inSheet(find.text(text)), findsOneWidget, reason: text);
      }
      expect(inSheet(find.text('Oct 11, 2026 9:30 AM')), findsOneWidget);

      await tester.tap(inSheet(find.text(before('1 day', dueRef))));
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(find.text(before('1 day', dueRef)), findsOneWidget);
      // The row tells when it fires with the draft's due date.
      expect(find.text('Oct 11, 2026 9:30 AM'), findsOneWidget);

      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          reminders: [
            relative(const Duration(days: -1), ReminderRelativeTo.dueDate),
          ],
        ),
      );
    });

    testWidgets('fall back to the start date, then the end date', (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(id: 1, title: 'Report', start: start, end: end),
      );
      await openAddSheet(tester);
      expect(
        inSheet(find.text(before('2 hours', en.reminderReferenceStartDate))),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(en.taskEditClearStartDate));
      await tester.pumpAndSettle();
      await openAddSheet(tester);
      expect(
        inSheet(find.text(before('2 hours', en.reminderReferenceEndDate))),
        findsOneWidget,
      );
    });

    testWidgets('are not offered without any date', (tester) async {
      await openTask(tester, sampleTask(id: 1, title: 'Report'));
      await openAddSheet(tester);

      expect(inSheet(find.text(en.reminderPickerNoDateHint)), findsOneWidget);
      expect(inSheet(find.byIcon(Icons.alarm)), findsNothing);
      expect(inSheet(find.text(en.reminderPickerCustom)), findsOneWidget);
      expect(inSheet(find.text(en.reminderPickerDateTime)), findsOneWidget);
    });

    testWidgets('one already in the list is marked and inert', (tester) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [
            TaskReminder(
              reminder: DateTime.utc(2026, 10, 11, 7, 30),
              relativePeriod: const Duration(days: -1),
              relativeTo: ReminderRelativeTo.dueDate,
            ),
          ],
        ),
      );
      await openAddSheet(tester);

      final existing = inSheet(
        find.widgetWithText(
          ListTile,
          before('1 day', en.reminderReferenceDueDate),
        ),
      );
      expect(tester.widget<ListTile>(existing).selected, isTrue);
      expect(
        tester.getSemantics(existing),
        isSemantics(
          label:
              '${before('1 day', en.reminderReferenceDueDate)}\n'
              'Oct 11, 2026 9:30 AM\n${en.reminderPickerAlreadySet}',
          isSelected: true,
          hasTapAction: false,
        ),
      );
      await tester.tap(existing, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(sheet(), findsOneWidget);
      expect(find.text(en.taskEditReminderDuplicate), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text(before('1 day', en.reminderReferenceDueDate)),
        findsOneWidget,
      );
      expect(editSaveEnabled(tester), isFalse);
    });
  });

  group('custom', () {
    testWidgets('validates the amount and converts to signed seconds', (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(id: 1, title: 'Report', due: due, start: start),
      );
      await openAddSheet(tester);
      await tester.tap(inSheet(find.text(en.reminderPickerCustom)));
      await tester.pumpAndSettle();

      expect(find.text(en.reminderPickerCustomTitle), findsOneWidget);
      expect(tester.widget<TextField>(amountField()).controller?.text, '1');
      expect(chipSelected(tester, en.reminderUnitDays), isTrue);
      expect(chipSelected(tester, en.reminderDirectionBefore), isTrue);
      expect(chipSelected(tester, en.reminderRelativeToDueDate), isTrue);
      expect(
        inSheet(
          find.text(en.reminderRelativeToUnset(en.reminderRelativeToEndDate)),
        ),
        findsOneWidget,
      );

      await tester.enterText(amountField(), '');
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.reminderAmountInvalid)), findsOneWidget);
      expect(sheetDoneEnabled(tester), isFalse);

      await tester.enterText(amountField(), '-5');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amountField()).controller?.text, '5');

      await tester.enterText(amountField(), '90');
      await tapChip(tester, en.reminderUnitMinutes);
      await tapChip(tester, en.reminderDirectionAfter);
      await tapChip(tester, en.reminderRelativeToStartDate);
      expect(
        inSheet(
          find.text(
            en.reminderAfter('90 minutes', en.reminderReferenceStartDate),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(inSheet(find.widgetWithText(TextButton, en.pickerDone)));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(
        find.text(
          en.reminderAfter('90 minutes', en.reminderReferenceStartDate),
        ),
        findsOneWidget,
      );
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          reminders: [
            relative(
              const Duration(seconds: 5400),
              ReminderRelativeTo.startDate,
            ),
          ],
        ),
      );
    });

    testWidgets('0 means on the date', (tester) async {
      await openTask(tester, sampleTask(id: 1, title: 'Report', due: due));
      await openAddSheet(tester);
      await tester.tap(inSheet(find.text(en.reminderPickerCustom)));
      await tester.pumpAndSettle();

      await tester.enterText(amountField(), '0');
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.reminderAmountInvalid)), findsNothing);
      await tester.tap(inSheet(find.widgetWithText(TextButton, en.pickerDone)));
      await tester.pumpAndSettle();

      expect(
        find.text(en.reminderAtReference(en.reminderReferenceDueDate)),
        findsOneWidget,
      );
    });

    testWidgets('editing a reminder after the date keeps "after" and the '
        'largest unit', (tester) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          end: end,
          reminders: [
            relative(const Duration(days: 2), ReminderRelativeTo.dueDate),
            relative(const Duration(days: -14), ReminderRelativeTo.endDate),
            relative(const Duration(minutes: -90), ReminderRelativeTo.dueDate),
          ],
        ),
      );
      final afterDue = en.reminderAfter('2 days', en.reminderReferenceDueDate);

      await tapVisible(tester, find.text(afterDue));
      expect(find.text(en.reminderPickerCustomTitle), findsOneWidget);
      expect(tester.widget<TextField>(amountField()).controller?.text, '2');
      expect(chipSelected(tester, en.reminderUnitDays), isTrue);
      expect(chipSelected(tester, en.reminderDirectionAfter), isTrue);
      expect(chipSelected(tester, en.reminderDirectionBefore), isFalse);
      expect(chipSelected(tester, en.reminderRelativeToDueDate), isTrue);
      expect(find.text(en.taskEditEditReminder), findsNothing);

      // Unchanged and confirmed: the same list, nothing to save.
      await tester.tap(inSheet(find.widgetWithText(TextButton, en.pickerDone)));
      await tester.pumpAndSettle();
      expect(editSaveEnabled(tester), isFalse);

      await tapVisible(
        tester,
        find.text(before('2 weeks', en.reminderReferenceEndDate)),
      );
      expect(tester.widget<TextField>(amountField()).controller?.text, '2');
      expect(chipSelected(tester, en.reminderUnitWeeks), isTrue);
      expect(chipSelected(tester, en.reminderDirectionBefore), isTrue);
      expect(chipSelected(tester, en.reminderRelativeToEndDate), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.text(before('90 minutes', en.reminderReferenceDueDate)),
      );
      expect(tester.widget<TextField>(amountField()).controller?.text, '90');
      expect(chipSelected(tester, en.reminderUnitMinutes), isTrue);

      await tester.enterText(amountField(), '3');
      await tapChip(tester, en.reminderUnitHours);
      await tester.tap(inSheet(find.widgetWithText(TextButton, en.pickerDone)));
      await tester.pumpAndSettle();
      await saveEdits(tester);
      expect(data.tasks.updates.single.$2.reminders, [
        relative(const Duration(days: 2), ReminderRelativeTo.dueDate),
        relative(const Duration(days: -14), ReminderRelativeTo.endDate),
        relative(const Duration(hours: -3), ReminderRelativeTo.dueDate),
      ]);
    });

    testWidgets('back returns to the presets', (tester) async {
      await openTask(tester, sampleTask(id: 1, title: 'Report', due: due));
      await openAddSheet(tester);
      await tester.tap(inSheet(find.text(en.reminderPickerCustom)));
      await tester.pumpAndSettle();

      await tester.tap(inSheet(find.byTooltip('Back')));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.reminderPickerCustom)), findsOneWidget);
      expect(
        inSheet(find.text(before('3 days', en.reminderReferenceDueDate))),
        findsOneWidget,
      );
    });
  });

  group('absolute', () {
    testWidgets('picks tomorrow at the breakpoint time by default', (
      tester,
    ) async {
      await openTask(tester, sampleTask(id: 1, title: 'Report'));
      await openAddSheet(tester);

      await tester.tap(inSheet(find.text(en.reminderPickerDateTime)));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(sheet(), findsNothing);
      expect(find.text('Oct 11, 2026 12:00 PM'), findsOneWidget);
      await saveEdits(tester);
      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          reminders: [
            TaskReminder(reminder: DateTime(2026, 10, 11, 12).toUtc()),
          ],
        ),
      );
    });

    testWidgets("editing one keeps its instant as the picker's start", (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          reminders: [
            TaskReminder(reminder: DateTime(2026, 10, 20, 9, 15).toUtc()),
          ],
        ),
      );

      await tapVisible(tester, find.text('Oct 20, 2026 9:15 AM'));
      expect(find.text(en.taskEditEditReminder), findsOneWidget);
      await tester.tap(inSheet(find.text(en.reminderPickerDateTime)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('22'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 22, 2026 9:15 AM'), findsOneWidget);
      expect(find.text('Oct 20, 2026 9:15 AM'), findsNothing);
      await saveEdits(tester);
      expect(data.tasks.updates.single.$2.reminders, [
        TaskReminder(reminder: DateTime(2026, 10, 22, 9, 15).toUtc()),
      ]);
    });

    testWidgets('is a Cupertino wheel on iOS', (tester) async {
      await openTask(tester, sampleTask(id: 1, title: 'Report'));
      await openAddSheet(tester);
      expect(
        ModalRoute.of(tester.element(sheet())),
        isA<CupertinoSheetRoute<TaskReminder>>(),
      );

      await tester.tap(inSheet(find.text(en.reminderPickerDateTime)));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text(en.pickerDone).last);
      await tester.pumpAndSettle();

      expect(find.text('Oct 11, 2026 12:00 PM'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('rows', () {
    testWidgets('warn when the date a reminder refers to is not set', (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [
            relative(const Duration(hours: -1), ReminderRelativeTo.startDate),
            relative(const Duration(hours: -2), ReminderRelativeTo.dueDate),
          ],
        ),
      );

      expect(find.text(en.reminderStartDateNotSet), findsOneWidget);
      expect(find.text('Oct 12, 2026 7:30 AM'), findsOneWidget);

      await tester.tap(find.byTooltip(en.taskEditClearDueDate));
      await tester.pumpAndSettle();
      expect(find.text(en.reminderDueDateNotSet), findsOneWidget);
      expect(find.text('Oct 12, 2026 7:30 AM'), findsNothing);
    });

    testWidgets('tell screen readers that a tap edits the reminder', (
      tester,
    ) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [
            relative(const Duration(hours: -2), ReminderRelativeTo.dueDate),
          ],
        ),
      );

      final text = before('2 hours', en.reminderReferenceDueDate);
      expect(
        tester.getSemantics(find.widgetWithText(ListTile, text)),
        isSemantics(
          label: '$text\nOct 12, 2026 7:30 AM',
          isButton: true,
          hasTapAction: true,
          onTapHint: en.taskEditEditReminder,
        ),
      );
    });

    testWidgets('warn when reminders fall on the same moment', (tester) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [
            relative(Duration.zero, ReminderRelativeTo.dueDate),
            relative(const Duration(days: -1), ReminderRelativeTo.dueDate),
          ],
        ),
      );
      expect(find.text(en.taskEditRemindersCoincide), findsNothing);

      await tester.tap(find.byTooltip(en.taskEditClearDueDate));
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditRemindersCoincide), findsOneWidget);
    });

    testWidgets('the remove button takes a reminder out, and Save sends the '
        'rest', (tester) async {
      final absolute = TaskReminder(reminder: DateTime.utc(2026, 10, 20, 7));
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [
            relative(const Duration(hours: -2), ReminderRelativeTo.dueDate),
            absolute,
          ],
        ),
      );
      final text = before('2 hours', en.reminderReferenceDueDate);
      final remove = find.byTooltip(en.taskEditRemoveReminder(text));
      expect(
        tester.getSemantics(remove),
        isSemantics(isButton: true, hasTapAction: true),
      );

      await tapVisible(tester, remove);
      expect(find.text(text), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();

      await saveEdits(tester);
      expect(data.tasks.updates.single.$2, TaskChanges(reminders: [absolute]));
    });

    testWidgets('removing the last one sends an empty list', (tester) async {
      await openTask(
        tester,
        sampleTask(
          id: 1,
          title: 'Report',
          due: due,
          reminders: [relative(Duration.zero, ReminderRelativeTo.dueDate)],
        ),
      );

      await tapVisible(
        tester,
        find.byTooltip(
          en.taskEditRemoveReminder(
            en.reminderAtReference(en.reminderReferenceDueDate),
          ),
        ),
      );
      await saveEdits(tester);

      expect(data.tasks.updates.single.$2, const TaskChanges(reminders: []));
    });
  });

  testWidgets('the sections order and their controls meet the tap target '
      'and label guidelines', (tester) async {
    await openTask(
      tester,
      sampleTask(
        id: 1,
        title: 'Report',
        due: due,
        labels: [sampleLabel(id: 1, title: 'Finance', hexColor: '1973ff')],
        assignees: const [User(id: 7, username: 'alice')],
        reminders: [
          relative(const Duration(hours: -2), ReminderRelativeTo.dueDate),
          relative(const Duration(hours: -2), ReminderRelativeTo.endDate),
        ],
      ),
    );

    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    final order = [
      en.taskEditTitleLabel,
      en.taskEditProject,
      en.taskDetailLabels,
      en.taskDetailAssignees,
      en.taskDetailDueDate,
      en.taskDetailStartDate,
      en.taskDetailEndDate,
      en.taskDetailReminders,
      en.taskDetailPriority,
      en.taskDetailProgress,
      en.taskEditColour,
      en.taskEditRepeat,
    ];
    for (var i = 1; i < order.length; i++) {
      expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('the sheet meets the tap target and label guidelines', (
    tester,
  ) async {
    await openTask(tester, sampleTask(id: 1, title: 'Report', due: due));
    await openAddSheet(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(inSheet(find.text(en.reminderPickerCustom)));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
