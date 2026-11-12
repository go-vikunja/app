import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';

import '../../helpers/label_user_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/screen_to_leave.dart';
import '../../helpers/sync_fakes.dart';

/// An editor by name, opened over a context, and a pick it would write.
typedef _Editor = (
  String what,
  Future<void> Function(BuildContext context) open,
  Future<void> Function(WidgetTester tester) pick,
);

void main() {
  // A Saturday at noon: the breakpoint time is 12:00.
  final now = DateTime(2026, 10, 10, 12);
  // Tomorrow, a Sunday.
  final due = DateTime(2026, 10, 11, 9, 30);
  const slashed = DisplaySettings(
    dateDisplay: DateDisplay.dayMonthYearSlashed,
    timeFormat: TimeFormat.twentyFourHour,
  );
  final errand = sampleLabel(id: 1, title: 'Errand');
  final finance = sampleLabel(id: 2, title: 'Finance');

  TaskReminder beforeDue(Duration period) => TaskReminder(
    relativePeriod: -period,
    relativeTo: ReminderRelativeTo.dueDate,
  );
  final dayBefore = beforeDue(const Duration(days: 1));
  final twoHoursBefore = beforeDue(const Duration(hours: 2));
  final threeDaysBefore = beforeDue(const Duration(days: 3));
  final weekBefore = beforeDue(const Duration(days: 7));
  // When "3 days before the due date" fires.
  final atThreeDaysBefore = TaskReminder(
    reminder: DateTime(2026, 10, 8, 9, 30).toUtc(),
  );

  final report = sampleTask(
    id: 2,
    title: 'Report',
    due: due,
    priority: TaskPriority.high,
    labels: [errand],
    reminders: [dayBefore, atThreeDaysBefore],
  );

  late SyncFakes data;
  late List<String> messages;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Bare'),
      report,
      sampleTask(id: 3, title: 'Plan', due: due),
    ];
    messages = [];
  });

  Task task(int id) => data.tasks.find(id)!;

  void replaceRow(int id, Task? Function(Task task) change) =>
      data.tasks.all = [
        for (final other in data.tasks.all)
          if (other.id != id) other else ?change(other),
      ];

  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1200));
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      overrides: [
        labelRepositoryProvider.overrideWithValue(
          FakeLabelRepository(labels: [errand, finance]),
        ),
      ],
    );
    tester.takeAnnouncements();
  }

  BuildContext page(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first);

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet).last, matching: finder);

  List<({String label, String? shown, String? spoken, bool selected})> options(
    WidgetTester tester,
  ) => [
    for (final tile in tester.widgetList<ListTile>(
      inSheet(find.byType(ListTile)),
    ))
      (
        label: (tile.title! as Text).data!,
        shown: (tile.subtitle as Text?)?.data,
        spoken: (tile.subtitle as Text?)?.semanticsLabel,
        selected: tile.selected,
      ),
  ];

  Future<void> tapIn(WidgetTester tester, Finder sheet, String text) async {
    await tester.tap(find.descendant(of: sheet, matching: find.text(text)));
    await tester.pumpAndSettle();
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  List<String> said(WidgetTester tester) => [
    for (final announcement in tester.takeAnnouncements()) announcement.message,
  ];

  String written(String date, String time) => en.momentDateAtTime(date, time);

  // The row keeps the instant a relative reminder fires at, which a picked
  // one has not yet.
  Matcher remindersChange(List<TaskReminder> expected) =>
      predicate<TaskChanges>((change) {
        final reminders = change.reminders;
        return reminders != null &&
            change == TaskChanges(reminders: reminders) &&
            reminders.length == expected.length &&
            [
              for (final (index, reminder) in reminders.indexed)
                sameReminder(reminder, expected[index]),
            ].every((same) => same);
      }, 'a change of the reminders alone to $expected');

  group('due date', () {
    Future<void> open(WidgetTester tester, int id) async {
      unawaited(
        editDueDate(
          page(tester),
          repository: data.tasks,
          task: task(id),
          now: now,
          display: slashed,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers Today, Tomorrow and Next week at the breakpoint time '
        'with their moments, then Pick date; no Clear without a due date', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 1);

      expect(inSheet(find.text(en.taskDetailDueDate)), findsOneWidget);
      expect(options(tester), [
        (
          label: en.shortcutToday,
          shown: '10/10/2026 12:00',
          spoken: written('Saturday, October 10, 2026', '12:00'),
          selected: false,
        ),
        (
          label: en.shortcutTomorrow,
          shown: '11/10/2026 12:00',
          spoken: written('Sunday, October 11, 2026', '12:00'),
          selected: false,
        ),
        (
          label: en.shortcutNextWeek,
          shown: '17/10/2026 12:00',
          spoken: written('Saturday, October 17, 2026', '12:00'),
          selected: false,
        ),
        (label: en.newTaskPickDate, shown: null, spoken: null, selected: false),
      ]);
    });

    testWidgets('keeps the time already set, checks the day it is on and '
        'offers Clear', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);

      expect(
        [
          for (final option in options(tester))
            (option.label, option.shown, option.selected),
        ],
        [
          (en.shortcutToday, '10/10/2026 09:30', false),
          (en.shortcutTomorrow, '11/10/2026 09:30', true),
          (en.shortcutNextWeek, '17/10/2026 09:30', false),
          (en.newTaskPickDate, null, false),
          (en.taskEditClearDueDate, null, false),
        ],
      );
    });

    testWidgets('a shortcut sets the due date and says it', (tester) async {
      await pumpApp(tester);
      await open(tester, 1);

      await tapIn(tester, find.byType(BottomSheet), en.shortcutToday);

      expect(data.tasks.updates, [
        (1, TaskChanges(dueDate: DateChange.set(now.toUtc()))),
      ]);
      expect(said(tester), [
        en.taskDueSemantics(written('Saturday, October 10, 2026', '12:00')),
      ]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Pick date opens the date and the time picker and sets what '
        'they give', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);

      await tapIn(tester, find.byType(BottomSheet), en.newTaskPickDate);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      tester.takeAnnouncements();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, [
        (
          2,
          TaskChanges(
            dueDate: DateChange.set(DateTime(2026, 10, 20, 9, 30).toUtc()),
          ),
        ),
      ]);
      expect(said(tester), [
        en.taskDueSemantics(written('Tuesday, October 20, 2026', '09:30')),
      ]);
    });

    testWidgets('the due date it already has, from a shortcut or the picker, '
        'writes nothing; nor does dismissing', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);
      await tapIn(tester, find.byType(BottomSheet), en.shortcutTomorrow);

      await open(tester, 2);
      await tapIn(tester, find.byType(BottomSheet), en.newTaskPickDate);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await open(tester, 2);
      await dismiss(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(data.tasks.updates, isEmpty);
      expect(said(tester), isEmpty);
    });

    testWidgets('a due date with seconds counts as the minute it shows: the '
        'checked shortcut and that minute picked write nothing', (
      tester,
    ) async {
      data.tasks.all = [
        ...data.tasks.all,
        sampleTask(
          id: 4,
          title: 'Repeat',
          due: DateTime(2026, 10, 11, 9, 30, 12),
        ),
      ];
      await pumpApp(tester);
      await open(tester, 4);
      expect(
        options(tester).where((option) => option.selected).single.label,
        en.shortcutTomorrow,
      );
      await tapIn(tester, find.byType(BottomSheet), en.shortcutTomorrow);

      await open(tester, 4);
      await tapIn(tester, find.byType(BottomSheet), en.newTaskPickDate);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(data.tasks.updates, isEmpty);
      expect(said(tester), isEmpty);

      await open(tester, 4);
      await tapIn(tester, find.byType(BottomSheet), en.shortcutToday);
      expect(data.tasks.updates, [
        (
          4,
          TaskChanges(
            dueDate: DateChange.set(DateTime(2026, 10, 10, 9, 30).toUtc()),
          ),
        ),
      ]);
    });

    testWidgets('Clear due date clears it and says so', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);

      await tapIn(tester, find.byType(BottomSheet), en.taskEditClearDueDate);

      expect(data.tasks.updates, [
        (2, const TaskChanges(dueDate: DateChange.clear())),
      ]);
      expect(said(tester), [en.taskDetailDueDateRemoved]);
    });
  });

  group('priority', () {
    Future<void> open(WidgetTester tester, int id) async {
      unawaited(
        editPriority(page(tester), repository: data.tasks, task: task(id)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists the six levels, Unset included, the current one '
        'checked; a pick sets it and says it', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);

      expect(inSheet(find.text(en.taskDetailPriority)), findsOneWidget);
      expect(
        [for (final option in options(tester)) (option.label, option.selected)],
        [
          (en.priorityUnset, false),
          (en.priorityLow, false),
          (en.priorityMedium, false),
          (en.priorityHigh, true),
          (en.priorityUrgent, false),
          (en.priorityDoNow, false),
        ],
      );

      await tapIn(tester, find.byType(BottomSheet), en.priorityUnset);

      expect(data.tasks.updates, [(2, const TaskChanges(priority: 0))]);
      expect(said(tester), [en.prioritySemantics(en.priorityUnset)]);
    });

    testWidgets('the current level writes nothing', (tester) async {
      await pumpApp(tester);
      await open(tester, 2);

      await tapIn(tester, find.byType(BottomSheet), en.priorityHigh);

      expect(data.tasks.updates, isEmpty);
      expect(said(tester), isEmpty);
    });

    testWidgets('a level on a task without one', (tester) async {
      await pumpApp(tester);
      await open(tester, 1);
      expect(
        options(tester).where((option) => option.selected).single.label,
        en.priorityUnset,
      );

      await tapIn(tester, find.byType(BottomSheet), en.priorityDoNow);

      expect(data.tasks.updates, [(1, const TaskChanges(priority: 5))]);
      expect(said(tester), [en.prioritySemantics(en.priorityDoNow)]);
    });
  });

  group('labels', () {
    Future<void> open(WidgetTester tester) async {
      unawaited(
        editLabels(page(tester), repository: data.tasks, task: task(2)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tick(WidgetTester tester, String title) async {
      await tester.tap(
        find.descendant(
          of: find.byType(LabelPicker),
          matching: find.widgetWithText(CheckboxListTile, title),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Done sends the labels added and removed against those the '
        'picker opened with, and says so', (tester) async {
      await pumpApp(tester);
      await open(tester);

      await tick(tester, 'Finance');
      await tick(tester, 'Errand');
      await tapIn(tester, find.byType(LabelPicker), en.pickerDone);

      expect(data.tasks.updates, [
        (
          2,
          const TaskChanges(
            labels: IdSetChange(added: {2}, removed: {1}),
          ),
        ),
      ]);
      expect(said(tester), [en.taskDetailLabelsChanged]);
    });

    testWidgets('dismissing the picker, or Done without a change, writes '
        'nothing', (tester) async {
      await pumpApp(tester);
      await open(tester);
      await tick(tester, 'Finance');
      await dismiss(tester);

      await open(tester);
      await tick(tester, 'Finance');
      await tick(tester, 'Finance');
      await tapIn(tester, find.byType(LabelPicker), en.pickerDone);

      expect(find.byType(LabelPicker), findsNothing);
      expect(data.tasks.updates, isEmpty);
      expect(said(tester), isEmpty);
    });
  });

  group('add reminder', () {
    Future<void> open(WidgetTester tester, int id) async {
      unawaited(
        addReminder(
          page(tester),
          repository: data.tasks,
          task: task(id),
          now: now,
          showMessage: messages.add,
        ),
      );
      await tester.pumpAndSettle();
    }

    String before(String period) =>
        en.reminderBefore(period, en.reminderReferenceDueDate);

    testWidgets('a preset is added and said', (tester) async {
      await pumpApp(tester);
      await open(tester, 3);

      await tapIn(tester, find.byType(ReminderPicker), before('1 day'));

      expect(data.tasks.updates, [
        (3, TaskChanges(reminders: [dayBefore])),
      ]);
      expect(said(tester), [en.taskDetailReminderAdded]);
      expect(messages, isEmpty);
    });

    testWidgets('joins the reminders the row has once picked, also one '
        'synced in while the picker was open', (tester) async {
      await pumpApp(tester);
      await open(tester, 3);

      replaceRow(3, (task) => task.copyWith(reminders: [weekBefore]));
      await tester.pumpAndSettle();
      await tapIn(tester, find.byType(ReminderPicker), before('1 day'));

      expect(data.tasks.updates, hasLength(1));
      expect(data.tasks.updates.single.$1, 3);
      expect(
        data.tasks.updates.single.$2,
        remindersChange([weekBefore, dayBefore]),
      );
      expect(said(tester), [en.taskDetailReminderAdded]);
    });

    testWidgets('one at the moment of another is refused with a message', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 2);

      await tapIn(tester, find.byType(ReminderPicker), before('3 days'));

      expect(messages, [en.taskDetailReminderSameMoment]);
      expect(data.tasks.updates, isEmpty);
      expect(said(tester), isEmpty);
    });

    testWidgets('the same reminder again is refused with a message', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 2);

      await tapIn(tester, find.byType(ReminderPicker), en.reminderPickerCustom);
      await tapIn(tester, find.byType(ReminderPicker), en.pickerDone);

      expect(messages, [en.taskEditReminderDuplicate]);
      expect(data.tasks.updates, isEmpty);
    });

    testWidgets('dismissing the picker writes nothing', (tester) async {
      await pumpApp(tester);
      await open(tester, 3);

      await dismiss(tester);

      expect(find.byType(ReminderPicker), findsNothing);
      expect(data.tasks.updates, isEmpty);
    });
  });

  group('once picked', () {
    // Each opens on Report and picks something it would write.
    final editors = <_Editor>[
      (
        'priority',
        (context) =>
            editPriority(context, repository: data.tasks, task: task(2)),
        (tester) => tapIn(tester, find.byType(BottomSheet), en.priorityLow),
      ),
      (
        'due date',
        (context) => editDueDate(
          context,
          repository: data.tasks,
          task: task(2),
          now: now,
          display: slashed,
        ),
        (tester) => tapIn(tester, find.byType(BottomSheet), en.shortcutToday),
      ),
      (
        'clear due date',
        (context) => editDueDate(
          context,
          repository: data.tasks,
          task: task(2),
          now: now,
          display: slashed,
        ),
        (tester) =>
            tapIn(tester, find.byType(BottomSheet), en.taskEditClearDueDate),
      ),
      (
        'labels',
        (context) => editLabels(context, repository: data.tasks, task: task(2)),
        (tester) async {
          await tester.tap(
            find.descendant(
              of: find.byType(LabelPicker),
              matching: find.widgetWithText(CheckboxListTile, 'Finance'),
            ),
          );
          await tester.pumpAndSettle();
          await tapIn(tester, find.byType(LabelPicker), en.pickerDone);
        },
      ),
      (
        'reminder',
        (context) => addReminder(
          context,
          repository: data.tasks,
          task: task(2),
          now: now,
          showMessage: messages.add,
        ),
        (tester) => tapIn(
          tester,
          find.byType(ReminderPicker),
          en.reminderBefore('2 hours', en.reminderReferenceDueDate),
        ),
      ),
    ];

    for (final (what, edit, pick) in editors) {
      testWidgets('$what: a task gone by then gets no write and no word', (
        tester,
      ) async {
        await pumpApp(tester);
        unawaited(edit(page(tester)));
        await tester.pumpAndSettle();

        replaceRow(2, (_) => null);
        await tester.pumpAndSettle();
        await pick(tester);

        expect(data.tasks.updates, isEmpty);
        expect(said(tester), isEmpty);
        expect(messages, isEmpty);
      });

      testWidgets('$what: once the screen that asked is gone the choice is '
          'still written and said', (tester) async {
        await pumpApp(tester);
        final screen = await ScreenToLeave.push(tester);
        unawaited(edit(screen.context));
        await tester.pumpAndSettle();
        await screen.leave(tester);

        await pick(tester);

        expect(data.tasks.updates, hasLength(1));
        expect(data.tasks.updates.single.$1, 2);
        expect(said(tester), hasLength(1));
      });
    }

    testWidgets('a refused reminder once the screen that asked is gone '
        'writes nothing and shows no message', (tester) async {
      await pumpApp(tester);
      final screen = await ScreenToLeave.push(tester);
      unawaited(
        addReminder(
          screen.context,
          repository: data.tasks,
          task: task(2),
          now: now,
          showMessage: messages.add,
        ),
      );
      await tester.pumpAndSettle();
      await screen.leave(tester);

      await tapIn(
        tester,
        find.byType(ReminderPicker),
        en.reminderBefore('3 days', en.reminderReferenceDueDate),
      );

      expect(data.tasks.updates, isEmpty);
      expect(messages, isEmpty);
    });

    testWidgets('Pick date once the screen that asked is gone opens no date '
        'picker and writes nothing', (tester) async {
      await pumpApp(tester);
      final screen = await ScreenToLeave.push(tester);
      unawaited(
        editDueDate(
          screen.context,
          repository: data.tasks,
          task: task(2),
          now: now,
          display: slashed,
        ),
      );
      await tester.pumpAndSettle();
      await screen.leave(tester);

      await tapIn(tester, find.byType(BottomSheet), en.newTaskPickDate);

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(data.tasks.updates, isEmpty);
    });
  });

  group('reminders sheet', () {
    Finder sheet() => find.byType(TaskRemindersSheet);
    Finder picker() => find.byType(ReminderPicker);

    String before(String period) =>
        en.reminderBefore(period, en.reminderReferenceDueDate);
    // How the reminders row and its remove button name the absolute one.
    const absolute = 'Oct 8, 2026 9:30 AM';

    Future<void> open(WidgetTester tester) async {
      unawaited(editReminders(page(tester), repository: data.tasks, taskId: 2));
      await tester.pumpAndSettle();
    }

    // A relative reminder opens in the custom form.
    Future<void> toPresets(WidgetTester tester) async {
      await tester.tap(
        find.descendant(of: picker(), matching: find.byTooltip('Back')),
      );
      await tester.pumpAndSettle();
    }

    Future<void> remove(WidgetTester tester, String reminder) async {
      await tester.tap(
        find.descendant(
          of: sheet(),
          matching: find.byTooltip(en.taskEditRemoveReminder(reminder)),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<TaskChanges> changes() => [
      for (final (id, change) in data.tasks.updates)
        if (id == 2) change,
    ];

    testWidgets('edit, remove and add each write the whole list at once and '
        'say so; the sheet stays', (tester) async {
      await pumpApp(tester);
      await open(tester);
      expect(
        find.descendant(
          of: sheet(),
          matching: find.text(en.taskDetailReminders),
        ),
        findsOneWidget,
      );

      await tapIn(tester, sheet(), before('1 day'));
      await toPresets(tester);
      expect(picker(), findsOneWidget);
      await tapIn(tester, picker(), before('2 hours'));
      expect(changes(), [
        remindersChange([twoHoursBefore, atThreeDaysBefore]),
      ]);
      expect(said(tester), [en.taskDetailReminderChanged]);
      expect(
        find.descendant(of: sheet(), matching: find.text(before('2 hours'))),
        findsOneWidget,
      );

      await remove(tester, absolute);
      expect(changes().last, remindersChange([twoHoursBefore]));
      expect(said(tester), [en.taskDetailReminderRemoved]);

      await tapIn(tester, sheet(), en.taskEditAddReminder);
      await tapIn(tester, picker(), before('3 days'));
      expect(
        changes().last,
        remindersChange([twoHoursBefore, threeDaysBefore]),
      );
      expect(said(tester), [en.taskDetailReminderAdded]);
      expect(changes(), hasLength(3));
      expect(sheet(), findsOneWidget);

      await tapIn(tester, sheet(), en.pickerDone);
      expect(sheet(), findsNothing);
    });

    testWidgets('an edit that keeps the reminder as it was writes nothing', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester);

      await tapIn(tester, sheet(), before('1 day'));
      await tapIn(tester, picker(), en.pickerDone);

      expect(picker(), findsNothing);
      expect(changes(), isEmpty);
      expect(said(tester), isEmpty);
    });

    testWidgets('a reminder edited onto the moment of the one it replaces is '
        'kept', (tester) async {
      await pumpApp(tester);
      await open(tester);

      await tapIn(tester, sheet(), absolute);
      await tapIn(tester, picker(), before('3 days'));

      expect(changes(), [
        remindersChange([dayBefore, threeDaysBefore]),
      ]);
    });

    testWidgets('the same reminder twice or two at one moment are refused '
        'under the title and said, without a write; the next change clears '
        'the refusal', (tester) async {
      await pumpApp(tester);
      await open(tester);

      await tapIn(tester, sheet(), en.taskEditAddReminder);
      await tapIn(tester, picker(), en.reminderPickerCustom);
      await tapIn(tester, picker(), en.pickerDone);
      expect(
        find.descendant(
          of: sheet(),
          matching: find.text(en.taskEditReminderDuplicate),
        ),
        findsOneWidget,
      );
      expect(said(tester), [en.taskEditReminderDuplicate]);

      await tapIn(tester, sheet(), en.taskEditAddReminder);
      await tapIn(tester, picker(), before('3 days'));
      expect(
        find.descendant(
          of: sheet(),
          matching: find.text(en.taskDetailReminderSameMoment),
        ),
        findsOneWidget,
      );
      expect(find.text(en.taskEditReminderDuplicate), findsNothing);
      expect(said(tester), [en.taskDetailReminderSameMoment]);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: sheet(),
                matching: find.text(en.taskDetailReminderSameMoment),
              ),
            )
            .style
            ?.color,
        Theme.of(tester.element(sheet())).colorScheme.error,
      );

      await tapIn(tester, sheet(), before('1 day'));
      await toPresets(tester);
      await tapIn(tester, picker(), before('3 days'));
      expect(said(tester), [en.taskDetailReminderSameMoment]);
      expect(changes(), isEmpty);

      await remove(tester, before('1 day'));
      expect(changes(), [
        remindersChange([atThreeDaysBefore]),
      ]);
      expect(find.text(en.taskDetailReminderSameMoment), findsNothing);
    });

    testWidgets('an edit starts from the row as it is once picked: the '
        'reminder is replaced where it is now, or added when it is gone', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester);

      await tapIn(tester, sheet(), before('1 day'));
      await toPresets(tester);
      data.tasks.all = [
        for (final other in data.tasks.all)
          if (other.id == 2)
            other.copyWith(
              reminders: [atThreeDaysBefore, dayBefore, weekBefore],
            )
          else
            other,
      ];
      await tester.pumpAndSettle();
      await tapIn(tester, picker(), before('2 hours'));
      expect(
        changes().last,
        remindersChange([atThreeDaysBefore, twoHoursBefore, weekBefore]),
      );

      await tapIn(tester, sheet(), before('2 hours'));
      await toPresets(tester);
      data.tasks.all = [
        for (final other in data.tasks.all)
          if (other.id == 2)
            other.copyWith(reminders: [atThreeDaysBefore])
          else
            other,
      ];
      await tester.pumpAndSettle();
      await tapIn(tester, picker(), before('1 day'));
      expect(changes().last, remindersChange([atThreeDaysBefore, dayBefore]));
    });

    testWidgets('taps wait for the write in flight', (tester) async {
      await pumpApp(tester);
      await open(tester);
      final writing = Completer<void>();
      data.tasks.beforeWrite = () => writing.future;

      await remove(tester, before('1 day'));
      await remove(tester, absolute);
      writing.complete();
      await tester.pumpAndSettle();

      expect(changes(), [
        remindersChange([atThreeDaysBefore]),
      ]);
      expect(said(tester), [en.taskDetailReminderRemoved]);
    });

    testWidgets('closes when the task is gone, also under a picker', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester);
      data.tasks.all = [
        for (final other in data.tasks.all)
          if (other.id != 2) other,
      ];
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);

      data.tasks.all = [...data.tasks.all, report];
      await open(tester);
      await tapIn(tester, sheet(), en.taskEditAddReminder);
      data.tasks.all = [
        for (final other in data.tasks.all)
          if (other.id != 2) other,
      ];
      await tester.pumpAndSettle();
      expect(sheet(), findsNothing);
      expect(picker(), findsOneWidget);
      await tapIn(tester, picker(), before('2 hours'));

      expect(picker(), findsNothing);
      expect(data.tasks.updates, isEmpty);
    });
  });

  group('the add row', () {
    late List<String> tapped;

    Future<void> pumpLine(
      WidgetTester tester,
      AddAttributeLine Function() line, {
      Locale locale = const Locale('en'),
    }) async {
      tapped = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: Card(child: line())),
        ),
      );
    }

    AddAttributeLine all() => AddAttributeLine(
      onDueDate: () => tapped.add('due'),
      onPriority: () => tapped.add('priority'),
      onReminder: () => tapped.add('reminder'),
      onLabel: () => tapped.add('label'),
    );

    testWidgets('has a plus for each property it is given, in order, each '
        'read with its whole action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpLine(tester, all);

      final shown = [
        en.taskDetailDueDate,
        en.taskDetailPriority,
        en.taskDetailAddLineReminder,
        en.taskDetailAddLineLabel,
      ];
      final spoken = [
        en.taskDetailAddDueDate,
        en.taskDetailAddPriority,
        en.taskEditAddReminder,
        en.taskEditAddLabel,
      ];
      final buttons = find.byType(TextButton);
      expect(buttons, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        final button = buttons.at(i);
        expect(
          find.descendant(of: button, matching: find.text(shown[i])),
          findsOneWidget,
        );
        expect(
          find.descendant(of: button, matching: find.byIcon(Icons.add)),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(button),
          isSemantics(label: spoken[i], isButton: true, hasTapAction: true),
        );
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await tester.tap(button);
      }
      expect(tapped, ['due', 'priority', 'reminder', 'label']);
      semantics.dispose();
    });

    testWidgets('leaves out what it is not given, and is empty without '
        'anything', (tester) async {
      await pumpLine(
        tester,
        () => AddAttributeLine(
          onPriority: () => tapped.add('priority'),
          onLabel: () => tapped.add('label'),
        ),
      );
      expect(find.byType(TextButton), findsNWidgets(2));
      expect(find.text(en.taskDetailPriority), findsOneWidget);
      expect(find.text(en.taskDetailAddLineLabel), findsOneWidget);
      expect(find.text(en.taskDetailDueDate), findsNothing);
      expect(find.text(en.taskDetailAddLineReminder), findsNothing);

      await pumpLine(tester, AddAttributeLine.new);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.getSize(find.byType(AddAttributeLine)), Size.zero);
    });

    testWidgets('wraps at 200 % text on 320 dp, in English and German', (
      tester,
    ) async {
      usePhoneSurface(tester, logicalSize: const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final locale in const [Locale('en'), Locale('de')]) {
        await pumpLine(tester, all, locale: locale);

        expect(tester.takeException(), isNull);
        final buttons = [
          for (var i = 0; i < 4; i++)
            tester.getRect(find.byType(TextButton).at(i)),
        ];
        for (final button in buttons) {
          expect(button.left, greaterThanOrEqualTo(0));
          expect(button.right, lessThanOrEqualTo(320));
          expect(button.height, greaterThanOrEqualTo(48));
        }
        expect(buttons.last.top, greaterThan(buttons.first.top));
      }
    });

    test('each spoken label holds the text it shows', () {
      for (final l10n in [en, de]) {
        for (final (shown, spoken) in [
          (l10n.taskDetailDueDate, l10n.taskDetailAddDueDate),
          (l10n.taskDetailPriority, l10n.taskDetailAddPriority),
          (l10n.taskDetailAddLineReminder, l10n.taskEditAddReminder),
          (l10n.taskDetailAddLineLabel, l10n.taskEditAddLabel),
        ]) {
          expect(
            spoken.toLowerCase(),
            contains(shown.toLowerCase()),
            reason: l10n.localeName,
          );
        }
      }
    });
  });
}
