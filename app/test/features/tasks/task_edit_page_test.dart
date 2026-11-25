import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/tasks/application/color_palette.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/editor_bridge_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  // A Saturday at noon: the breakpoint time for a date-only pick is 12:00.
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 2, title: 'Personal'),
      sampleProject(id: 3, title: 'Old', archived: true),
    ];
    data.tasks.all = [
      sampleTask(
        id: 1,
        title: 'Quarterly report',
        identifier: 'WORK-1',
        due: DateTime(2026, 10, 12, 9, 30),
        priority: TaskPriority.high,
        percentDone: 0.5,
        repeatAfter: const Duration(days: 14),
      ),
      sampleTask(id: 2, title: 'Bare task'),
    ];
  });

  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  String location(WidgetTester tester) => routerOf(tester).state.uri.toString();

  /// What the page popped with, once it did.
  late Future<bool?> popped;

  Future<void> openEditPage(WidgetTester tester, int id) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2200));
    await pumpSignedInApp(tester, sync: data, now: now);
    popped = routerOf(tester).push<bool>(AppRoutes.taskEdit(id));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder titleField() => find.widgetWithText(TextField, en.taskEditTitleLabel);

  Finder saveButton() => find.widgetWithText(TextButton, en.taskEditSave);

  bool saveEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(saveButton()).onPressed != null;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  Future<void> pressBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  group('entry', () {
    Future<void> openDetail(WidgetTester tester, String title) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      await pumpSignedInApp(tester, sync: data, now: now);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }

    testWidgets("the sheet's Edit button opens the page over the sheet, "
        'which Back returns to', (tester) async {
      await openDetail(tester, 'Bare task');

      await tester.tap(find.byTooltip(en.taskEdit));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(location(tester), AppRoutes.taskEdit(2));
      expect(find.byType(AdaptiveNavigationBar), findsNothing);
      expect(
        tester.widget<TextField>(titleField()).controller?.text,
        'Bare task',
      );

      await pressBack(tester);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(find.text(en.taskEditSaved), findsNothing);
    });

    testWidgets('Save returns to the sheet, which shows the saved values and '
        'says Saved', (tester) async {
      await openDetail(tester, 'Bare task');
      await tester.tap(find.byTooltip(en.taskEdit));
      await tester.pumpAndSettle();

      await tester.enterText(titleField(), 'Bare task, renamed');
      await tester.pumpAndSettle();
      await save(tester);

      expect(find.byType(TaskEditPage), findsNothing);
      final sheet = find.byType(TaskDetailSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Bare task, renamed')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text(en.taskEditSaved)),
        findsOneWidget,
      );
    });

    testWidgets("a tap on the sheet's progress row opens the page at the "
        'progress', (tester) async {
      await openDetail(tester, 'Quarterly report');

      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(TaskDetailSheet),
          matching: find.text(en.taskDetailProgress),
        ),
      );

      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(
        location(tester),
        AppRoutes.taskEdit(1, field: TaskEditField.progress),
      );
    });

    testWidgets('tapping the title in the sheet opens the page too', (
      tester,
    ) async {
      await openDetail(tester, 'Bare task');

      await tester.tap(
        find.descendant(
          of: find.byType(TaskDetailSheet),
          matching: find.text('Bare task'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    testWidgets('an unknown task shows the not-found state without Save', (
      tester,
    ) async {
      await openEditPage(tester, 999);

      expect(find.text(en.taskEditGoneTitle), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('saving', () {
    testWidgets('sends only the changed fields and pops with true', (
      tester,
    ) async {
      await openEditPage(tester, 1);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(titleField(), 'Quarterly report Q4');
      await tapVisible(tester, find.text(en.priorityUrgent));
      expect(saveEnabled(tester), isTrue);
      await save(tester);

      expect(data.tasks.updates, [
        (1, const TaskChanges(title: 'Quarterly report Q4', priority: 4)),
      ]);
      expect(data.tasks.writes, ['update 1']);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(location(tester), AppRoutes.overview);
      expect(await popped, isTrue);
      expect(find.text('Quarterly report Q4'), findsOneWidget);
    });

    testWidgets('the priority row starts with Unset, which clears the '
        'priority', (tester) async {
      await openEditPage(tester, 1);
      final chips = find.descendant(
        of: find.byType(TaskEditPage),
        matching: find.byType(ChoiceChip),
      );
      final labels = [
        for (final chip in tester.widgetList<ChoiceChip>(chips))
          if (chip.label case Text(:final data?)) data,
      ];
      expect(labels.sublist(labels.indexOf(en.priorityUnset)).take(6), [
        en.priorityUnset,
        en.priorityLow,
        en.priorityMedium,
        en.priorityHigh,
        en.priorityUrgent,
        en.priorityDoNow,
      ]);
      final unset = find.ancestor(
        of: find.text(en.priorityUnset),
        matching: find.byType(ChoiceChip),
      );
      final row = find.ancestor(
        of: unset,
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        tester.widget<SingleChildScrollView>(row.first).scrollDirection,
        Axis.horizontal,
      );

      await tapVisible(tester, unset);
      await save(tester);
      expect(data.tasks.updates.single.$2, const TaskChanges(priority: 0));
    });

    testWidgets('an empty title disables Save and says why', (tester) async {
      await openEditPage(tester, 1);

      await tester.enterText(titleField(), '   ');
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditTitleRequired), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(titleField(), 'Back');
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditTitleRequired), findsNothing);
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a title edited back to its value leaves nothing to save', (
      tester,
    ) async {
      await openEditPage(tester, 1);

      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isTrue);
      await tester.enterText(titleField(), 'Quarterly report');
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('uses the id a queued create got meanwhile', (tester) async {
      final localId = await data.tasks.createTask(
        const NewTask(projectId: 1, title: 'Draft'),
      );
      await openEditPage(tester, localId);

      await tester.enterText(titleField(), 'Draft, refined');
      await tester.pumpAndSettle();
      data.tasks.remapTask(localId, 42);
      await tester.pumpAndSettle();
      await save(tester);

      expect(data.tasks.updates.single.$1, 42);
      expect(data.tasks.find(42)?.title, 'Draft, refined');
    });
  });

  group('unsaved changes', () {
    testWidgets('a save the device cannot store stays on the page: it says '
        'so, Save works again and back still asks', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Quarterly report Q4');
      await tester.pumpAndSettle();
      data.tasks.beforeWrite = () async =>
          throw const FileSystemException('No space left on device');

      await save(tester);

      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(find.text(en.localChangeFailed), findsOneWidget);
      expect(find.text(en.taskEditSaved), findsNothing);
      expect(saveEnabled(tester), isTrue);
      expect(tester.takeException(), isNull);

      await pressBack(tester);
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();

      data.tasks.beforeWrite = null;
      await save(tester);

      expect(find.byType(TaskEditPage), findsNothing);
      expect(find.text('Quarterly report Q4'), findsOneWidget);
      expect(await popped, isTrue);
      expect(find.text(en.localChangeFailed), findsNothing);
    });

    testWidgets('back leaves at once while nothing changed', (tester) async {
      await openEditPage(tester, 1);

      await pressBack(tester);

      expect(find.byType(TaskEditPage), findsNothing);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
    });

    testWidgets('a title stored with whitespace around it is no change, and '
        'a save of another field leaves it as the server has it', (
      tester,
    ) async {
      data.tasks.all = [sampleTask(id: 3, title: ' Bare task\n')];
      await openEditPage(tester, 3);
      expect(saveEnabled(tester), isFalse);

      await pressBack(tester);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(find.byType(TaskEditPage), findsNothing);

      popped = routerOf(tester).push<bool>(AppRoutes.taskEdit(3));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(en.priorityUrgent));
      await save(tester);
      expect(data.tasks.updates, [(3, const TaskChanges(priority: 4))]);
    });

    testWidgets('back asks, Keep editing stays, Discard leaves unsaved', (
      tester,
    ) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();

      await pressBack(tester);
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(find.text(en.taskEditDiscardBody), findsOneWidget);

      await tester.tap(find.text(en.taskEditKeepEditing));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(
        tester.widget<TextField>(titleField()).controller?.text,
        'Changed',
      );

      await pressBack(tester);
      await tester.tap(find.text(en.taskEditDiscard));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditPage), findsNothing);
      expect(data.tasks.updates, isEmpty);
      expect(find.text('Quarterly report'), findsOneWidget);
    });

    testWidgets('once the description was saved here, the dialog says that '
        'only the other edits are lost', (tester) async {
      final bridges = FakeEditorBridges();
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await pumpSignedInApp(
        tester,
        sync: data,
        now: now,
        overrides: [bridges.override],
      );
      unawaited(routerOf(tester).push(AppRoutes.taskEdit(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.taskDetailDescription));
      await tester.pumpAndSettle();
      bridges.last.edit('<p>Only numbers</p>');
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(DescriptionEditorPage),
          matching: find.widgetWithText(TextButton, en.taskEditSave),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DescriptionEditorPage), findsNothing);

      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();
      await pressBack(tester);

      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(find.text(en.taskEditDiscardBodyDescriptionSaved), findsOneWidget);
      expect(find.text(en.taskEditDiscardBody), findsNothing);
    });

    testWidgets('the system back is guarded the same way', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    void removeTask(int id) => data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id != id) task,
    ];

    testWidgets('a task that goes while the page is open shows the not-found '
        'state, and back leaves without asking', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();

      removeTask(1);
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditGoneTitle), findsOneWidget);
      expect(find.text(en.taskEditGoneBody), findsOneWidget);
      expect(titleField(), findsNothing);
      expect(saveEnabled(tester), isFalse);

      await pressBack(tester);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(await popped, isNull);
      expect(data.tasks.updates, isEmpty);
    });

    testWidgets('a task that comes back shows the form again with the edits '
        'made before it went', (tester) async {
      final kept = data.tasks.find(1)!;
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();
      removeTask(1);
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditGoneTitle), findsOneWidget);

      data.tasks.all = [...data.tasks.all, kept];
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditGoneTitle), findsNothing);
      expect(
        tester.widget<TextField>(titleField()).controller?.text,
        'Changed',
      );
      expect(saveEnabled(tester), isTrue);
      await pressBack(tester);
      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
    });

    testWidgets('a save that finds the task gone stays on the page without '
        'Saved, shows the not-found state, and the system back leaves '
        'without asking', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();
      data.tasks.beforeWrite = () async => removeTask(1);

      await save(tester);

      expect(find.byType(TaskEditPage), findsOneWidget);
      expect(find.text(en.taskEditGoneTitle), findsOneWidget);
      expect(find.text(en.taskEditSaved), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(await popped, isNull);
    });

    testWidgets('the dialog is a Cupertino alert on iOS', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final discard = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, en.taskEditDiscard),
      );
      expect(discard.isDestructiveAction, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('dates', () {
    Finder chipOf(Finder text) =>
        find.ancestor(of: text, matching: find.byType(ChoiceChip));

    bool selected(WidgetTester tester, Finder text) =>
        tester.widget<ChoiceChip>(chipOf(text)).selected;

    testWidgets("each date has the sheet's shortcuts and Pick date…, and no "
        'other shortcut', (tester) async {
      await openEditPage(tester, 2);

      for (final label in [
        en.shortcutToday,
        en.shortcutTomorrow,
        en.shortcutNextWeek,
        en.newTaskPickDate,
      ]) {
        expect(find.text(label), findsNWidgets(3));
      }
      for (final label in [
        en.shortcutNextMonday,
        en.shortcutThisWeekend,
        en.shortcutEndOfMonth,
        en.shortcutInAMonth,
      ]) {
        expect(find.text(label), findsNothing);
      }
      for (final heading in [
        en.taskDetailDueDate,
        en.taskDetailStartDate,
        en.taskDetailEndDate,
      ]) {
        expect(find.text(heading), findsOneWidget);
      }
    });

    testWidgets('a shortcut that is not chosen shows its day, the chosen one '
        'the time instead', (tester) async {
      await openEditPage(tester, 2);
      final tomorrow = find.text(en.shortcutTomorrow).first;
      String chipText() => [
        for (final text in tester.widgetList<Text>(
          find.descendant(of: chipOf(tomorrow), matching: find.byType(Text)),
        ))
          text.data,
      ].join();

      expect(chipText(), en.shortcutOnDay(en.shortcutTomorrow, 'Sun, Oct 11'));
      expect(
        chipText(),
        isNot(contains(en.shortcutAtTime(en.shortcutTomorrow, '12:00 PM'))),
      );
      await tapVisible(tester, tomorrow);

      expect(
        find.text(en.shortcutAtTime(en.shortcutTomorrow, '12:00 PM')),
        findsOneWidget,
      );
      expect(
        find.text(en.shortcutOnDay(en.shortcutNextWeek, 'Sat, Oct 17')),
        findsNothing,
        reason: 'the day is a lighter run of its own',
      );
      expect(find.text(' · Sat, Oct 17'), findsNWidgets(3));
    });

    testWidgets('a shortcut on a task without a time uses the breakpoint '
        'time and reads out its day', (tester) async {
      await openEditPage(tester, 2);

      final tomorrow = find.text(en.shortcutTomorrow).first;
      expect(
        tester.getSemantics(tomorrow).label,
        en.shortcutFieldSemantics(
          en.taskDetailDueDate,
          en.shortcutTomorrow,
          'Sun, Oct 11',
        ),
      );
      await tapVisible(tester, tomorrow);

      final chosen = find.text(
        en.shortcutAtTime(en.shortcutTomorrow, '12:00 PM'),
      );
      expect(selected(tester, chosen), isTrue);
      expect(selected(tester, find.text(en.shortcutToday).first), isFalse);
      expect(
        tester.getSemantics(chosen).label,
        en.shortcutFieldSemantics(
          en.taskDetailDueDate,
          en.shortcutAtTime(en.shortcutTomorrow, '12:00 PM'),
          'Sun, Oct 11',
        ),
      );

      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          dueDate: DateChange.set(DateTime(2026, 10, 11, 12).toUtc()),
        ),
      );
    });

    testWidgets('a date on no shortcut shows as a chip of its own, and a '
        'shortcut keeps its time', (tester) async {
      await openEditPage(tester, 1);
      expect(find.text('Oct 12, 2026 9:30 AM'), findsOneWidget);

      await tapVisible(tester, find.text(en.shortcutNextWeek).first);

      expect(find.text('Oct 12, 2026 9:30 AM'), findsNothing);
      expect(
        selected(
          tester,
          find.text(en.shortcutAtTime(en.shortcutNextWeek, '9:30 AM')),
        ),
        isTrue,
      );
      await save(tester);
      expect(
        data.tasks.updates.single.$2.dueDate,
        DateChange.set(DateTime(2026, 10, 17, 9, 30).toUtc()),
      );
    });

    testWidgets('tapping the chosen shortcut again clears the date', (
      tester,
    ) async {
      data.tasks.all = [
        sampleTask(id: 4, title: 'Soon', due: DateTime(2026, 10, 11, 8)),
      ];
      await openEditPage(tester, 4);
      final chosen = find.text(
        en.shortcutAtTime(en.shortcutTomorrow, '8:00 AM'),
      );
      expect(selected(tester, chosen), isTrue);

      await tapVisible(tester, chosen);

      expect(chosen, findsNothing);
      expect(selected(tester, find.text(en.shortcutTomorrow).first), isFalse);
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(dueDate: DateChange.clear()),
      );
    });

    testWidgets("the other date's delete button clears the date", (
      tester,
    ) async {
      await openEditPage(tester, 1);

      await tapVisible(tester, find.byTooltip(en.taskEditClearDueDate));

      expect(find.text('Oct 12, 2026 9:30 AM'), findsNothing);
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(dueDate: DateChange.clear()),
      );
    });

    testWidgets('Pick date… opens the date picker, then the time picker', (
      tester,
    ) async {
      await openEditPage(tester, 1);

      await tapVisible(tester, find.text(en.newTaskPickDate).first);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 15, 2026 9:30 AM'), findsOneWidget);
    });

    testWidgets("a chip on an unset date takes the user's default due time", (
      tester,
    ) async {
      data.shared.settings = const UserSettings(
        defaultDueTime: ClockTime(17, 45),
      );
      await openEditPage(tester, 1);

      await tapVisible(tester, find.text(en.shortcutToday).at(1));
      await save(tester);

      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          startDate: DateChange.set(DateTime(2026, 10, 10, 17, 45).toUtc()),
        ),
      );
    });

    testWidgets("each date's chips name their date, so that the same "
        'shortcut under the three dates differs', (tester) async {
      final semantics = tester.ensureSemantics();
      await openEditPage(tester, 2);

      final tomorrow = find.text(en.shortcutTomorrow);
      expect(tomorrow, findsNWidgets(3));
      expect(
        [for (var i = 0; i < 3; i++) tester.getSemantics(tomorrow.at(i)).label],
        [
          for (final field in [
            en.taskDetailDueDate,
            en.taskDetailStartDate,
            en.taskDetailEndDate,
          ])
            en.shortcutFieldSemantics(
              field,
              en.shortcutTomorrow,
              'Sun, Oct 11',
            ),
        ],
      );
      semantics.dispose();
    });

    testWidgets('Pick date… and a date on no shortcut name their date too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openEditPage(tester, 1);

      final pick = find.text(en.newTaskPickDate);
      expect(pick, findsNWidgets(3));
      expect(
        [for (var i = 0; i < 3; i++) tester.getSemantics(pick.at(i)).label],
        [
          for (final field in [
            en.taskDetailDueDate,
            en.taskDetailStartDate,
            en.taskDetailEndDate,
          ])
            en.dateFieldChipSemantics(field, en.newTaskPickDate),
        ],
      );
      expect(
        tester.getSemantics(find.text('Oct 12, 2026 9:30 AM')).label,
        startsWith('${en.taskDetailDueDate}: '),
      );
      semantics.dispose();
    });

    testWidgets('a start date set by chip and an end date cleared go '
        'together', (tester) async {
      await openEditPage(tester, 1);

      await tapVisible(tester, find.text(en.shortcutToday).at(1));
      await save(tester);

      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          startDate: DateChange.set(DateTime(2026, 10, 10, 12).toUtc()),
        ),
      );
    });

    testWidgets('a chip is dated at the tap: past midnight Today sets the new '
        'day before the chips have turned over', (tester) async {
      var clock = DateTime(2026, 10, 10, 23, 59, 30);
      usePhoneSurface(tester, logicalSize: const Size(360, 2200));
      await pumpSignedInApp(
        tester,
        sync: data,
        overrides: [clockProvider.overrideWithValue(() => clock)],
      );
      popped = routerOf(tester).push<bool>(AppRoutes.taskEdit(2));
      await tester.pumpAndSettle();

      clock = DateTime(2026, 10, 11, 0, 0, 10);
      await tapVisible(tester, find.text(en.shortcutToday).first);
      expect(
        selected(
          tester,
          find.text(en.shortcutAtTime(en.shortcutToday, '9:00 AM')),
        ),
        isTrue,
      );
      await save(tester);

      expect(
        data.tasks.updates.single.$2,
        TaskChanges(dueDate: DateChange.set(DateTime(2026, 10, 11, 9).toUtc())),
      );
    });
  });

  group('the layout of the New task sheet', () {
    testWidgets('the fields have icon headings, in the order title, '
        'project, due date and priority', (tester) async {
      await openEditPage(tester, 1);

      double top(Finder finder) => tester.getRect(finder).top;
      final title = titleField();
      final project = find.byType(ProjectField);
      final due = find.text(en.taskDetailDueDate);
      final priority = find.text(en.taskDetailPriority);
      expect(top(title), lessThan(top(project)));
      expect(top(project), lessThan(top(due)));
      expect(top(due), lessThan(top(priority)));
      for (final (heading, icon) in [
        (en.taskDetailDueDate, Icons.calendar_today_outlined),
        (en.taskDetailPriority, Icons.flag_outlined),
        (en.taskDetailLabels, Icons.label_outline),
        (en.taskDetailAssignees, Icons.people_outline),
        (en.taskDetailReminders, Icons.alarm),
        (en.taskEditRepeat, Icons.repeat),
        (en.taskDetailStartDate, Icons.play_arrow_outlined),
        (en.taskDetailEndDate, Icons.stop_outlined),
        (en.taskDetailProgress, Icons.percent),
        (en.taskEditColour, Icons.palette_outlined),
      ]) {
        final row = find.ancestor(
          of: find.text(heading),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: row.first, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: heading,
        );
        expect(
          tester
              .getSemantics(find.text(heading))
              .getSemanticsData()
              .headingLevel,
          2,
          reason: heading,
        );
      }
    });

    for (final (field, heading, atTop) in [
      (TaskEditField.startDate, 'Start date', false),
      (TaskEditField.endDate, 'End date', false),
      (TaskEditField.progress, 'Progress', false),
      (TaskEditField.repeat, 'Repeat', true),
      (TaskEditField.assignees, 'Assignees', true),
    ]) {
      testWidgets('opened at ${field.name}, it scrolls to that field', (
        tester,
      ) async {
        usePhoneSurface(tester);
        await pumpSignedInApp(tester, sync: data, now: now);
        unawaited(routerOf(tester).push(AppRoutes.taskEdit(1, field: field)));
        await tester.pumpAndSettle();

        final list = find
            .descendant(
              of: find.byType(TaskEditPage),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(tester.state<ScrollableState>(list).position.pixels, isPositive);
        final shown = find.text(heading).hitTestable();
        expect(shown, findsOneWidget);
        if (atTop) {
          expect(
            tester.getRect(shown).top - tester.getRect(list).top,
            lessThan(48),
          );
        }
      });
    }
  });

  group('properties', () {
    testWidgets('the slider changes the percent done in steps of 10', (
      tester,
    ) async {
      await openEditPage(tester, 2);
      expect(find.text(en.taskPercentDone(0)), findsOneWidget);

      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();

      expect(find.text(en.taskPercentDone(50)), findsOneWidget);
      await save(tester);
      expect(data.tasks.updates.single.$2, const TaskChanges(percentDone: 0.5));
    });

    testWidgets('progress is read once: the slider is named Progress and '
        'says the percent as its value', (tester) async {
      final semantics = tester.ensureSemantics();
      await openEditPage(tester, 1);

      final slider = tester.getSemantics(find.byType(Slider));
      final data = slider.getSemanticsData();
      expect(data.label, en.taskDetailProgress);
      expect(data.value, en.taskPercentDone(50));
      expect(data.flagsCollection.isSlider, isTrue);
      final percent = tester.getSemantics(find.text(en.taskPercentDone(50)));
      expect(percent, isNot(same(slider)));
      expect(
        percent.getSemanticsData().label,
        isNot(contains(en.taskPercentDone(50))),
      );
      semantics.dispose();
    });

    testWidgets('a colour swatch sets the colour, No colour clears it', (
      tester,
    ) async {
      await openEditPage(tester, 2);

      await tester.tap(find.bySemanticsLabel(en.colorNameBlue));
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(hexColor: '0072b2'),
      );
      expect(data.tasks.find(2)?.hexColor, '0072b2');

      unawaited(routerOf(tester).push(AppRoutes.taskEdit(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(en.taskEditNoColour));
      await tester.pumpAndSettle();
      await save(tester);
      expect(data.tasks.updates.last.$2, const TaskChanges(hexColor: ''));
    });

    testWidgets('a custom colour of the task is offered next to the '
        'Okabe–Ito colours', (tester) async {
      data.tasks.all = [
        sampleTask(id: 5, title: 'Teal').copyWith(hexColor: '008080'),
      ];
      await openEditPage(tester, 5);

      for (final label in [
        for (final hex in okabeItoColors) colorSwatchLabel(en, hex),
        en.taskEditColourSemantics('#008080'),
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(
        find.bySemanticsLabel(en.taskEditColourSemantics('#1973ff')),
        findsNothing,
      );
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a custom colour of the task can be chosen again after '
        'trying another', (tester) async {
      data.tasks.all = [
        sampleTask(id: 5, title: 'Teal').copyWith(hexColor: '008080'),
      ];
      await openEditPage(tester, 5);

      await tester.tap(find.bySemanticsLabel(en.colorNameOrange));
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isTrue);
      await tester.tap(
        find.bySemanticsLabel(en.taskEditColourSemantics('#008080')),
      );
      await tester.pumpAndSettle();

      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a preset sets the repeat, Never removes it', (tester) async {
      await openEditPage(tester, 1);

      await tester.tap(find.text(en.repeatPresetThirtyDays));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, en.repeatAmountLabel),
            )
            .controller
            ?.text,
        '30',
      );
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(repeatAfter: Duration(seconds: 2592000)),
      );

      unawaited(routerOf(tester).push(AppRoutes.taskEdit(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.repeatModeNone));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, en.repeatAmountLabel),
        findsNothing,
      );
      await save(tester);
      expect(
        data.tasks.updates.last.$2,
        const TaskChanges(repeatAfter: Duration.zero),
      );
    });

    testWidgets('an amount of 0 blocks saving with a message', (tester) async {
      await openEditPage(tester, 1);
      final amount = find.widgetWithText(TextField, en.repeatAmountLabel);
      expect(tester.widget<TextField>(amount).controller?.text, '2');
      expect(find.text(en.repeatUnitWeeks), findsOneWidget);

      await tester.enterText(amount, '0');
      await tester.pumpAndSettle();

      expect(find.text(en.repeatAmountInvalid), findsOneWidget);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(amount, '3');
      await tester.tap(find.text(en.repeatUnitDays));
      await tapVisible(tester, find.text(en.repeatModeFromCompletion));
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(
          repeatAfter: Duration(days: 3),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      );
    });

    testWidgets('the repeat offers Never, an interval and the same day '
        'every month; only the interval has the presets and counts from '
        'when the task is done', (tester) async {
      await openEditPage(tester, 2);
      Finder fromDone() =>
          find.widgetWithText(SwitchListTile, en.repeatModeFromCompletion);

      expect(find.text(en.repeatModeNone), findsOneWidget);
      expect(find.text(en.repeatModeMonthly), findsOneWidget);
      expect(en.repeatModeMonthly, 'Same day every month');
      expect(find.text(en.repeatPresetThirtyDays), findsNothing);
      expect(fromDone(), findsNothing);

      await tapVisible(tester, find.text(en.repeatModeMonthly));
      expect(find.text(en.repeatPresetThirtyDays), findsNothing);
      expect(fromDone(), findsNothing);

      await tapVisible(tester, find.text(en.repeatModeEvery));
      expect(find.text(en.repeatPresetThirtyDays), findsOneWidget);
      expect(tester.widget<SwitchListTile>(fromDone()).value, isFalse);

      await tapVisible(tester, fromDone());
      await tapVisible(tester, find.text(en.repeatPresetWeekly));
      expect(tester.widget<SwitchListTile>(fromDone()).value, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text(en.repeatModeEvery),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(
          repeatAfter: Duration(days: 7),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      );
    });

    testWidgets('the project picker lists the tree without archived '
        'projects and moves the task', (tester) async {
      data.projects.all = [
        sampleProject(id: 1, title: 'Work'),
        sampleProject(id: 2, title: 'Personal', hexColor: '008080'),
        sampleProject(id: 3, title: 'Old', archived: true),
      ];
      String fieldMark() => tester
          .widget<ProjectIcon>(
            find.descendant(
              of: find.byType(ProjectField),
              matching: find.byType(ProjectIcon),
            ),
          )
          .hexColor;
      await openEditPage(tester, 1);
      expect(find.widgetWithText(ProjectField, 'Work'), findsOneWidget);
      expect(fieldMark(), '');

      await tester.tap(find.byType(ProjectField));
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditProjectPickerTitle), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ProjectField, 'Personal'), findsOneWidget);
      expect(fieldMark(), '008080');
      await save(tester);
      expect(data.tasks.updates.single.$2, const TaskChanges(projectId: 2));
    });

    testWidgets('the project picker is a Cupertino sheet with the same '
        'tree on iOS', (tester) async {
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 4, title: 'Backlog', parent: 1),
        sampleProject(id: 5, title: 'Backlog', parent: 2),
      ];
      await openEditPage(tester, 1);

      await tester.tap(find.byType(ProjectField));
      await tester.pumpAndSettle();

      final title = find.text(en.taskEditProjectPickerTitle);
      expect(title, findsOneWidget);
      expect(
        ModalRoute.of(tester.element(title)),
        isA<CupertinoSheetRoute<Project?>>(),
      );
      expect(find.text('Old'), findsNothing);
      // The same name under two parents is told apart by its indent.
      final picker = find.ancestor(of: title, matching: find.byType(ListView));
      Finder inPicker(String text) =>
          find.descendant(of: picker, matching: find.text(text));
      expect(inPicker('Backlog'), findsNWidgets(2));
      expect(
        tester.getTopLeft(inPicker('Backlog').first).dx,
        greaterThan(tester.getTopLeft(inPicker('Work')).dx),
      );
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ProjectField, 'Personal'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a project whose title another shares shows its parent', (
      tester,
    ) async {
      data.projects.all = [
        ...data.projects.all,
        sampleProject(id: 4, title: 'Backlog', parent: 1),
        sampleProject(id: 5, title: 'Backlog', parent: 2),
      ];
      data.tasks.all = [sampleTask(id: 6, title: 'Later', projectId: 5)];
      await openEditPage(tester, 6);

      expect(
        find.widgetWithText(ProjectField, 'Personal › Backlog'),
        findsOneWidget,
      );
    });

    testWidgets('every control meets the Android tap target size', (
      tester,
    ) async {
      await openEditPage(tester, 2);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await openEditPage(tester, 1);

    expect(find.text(de.taskEditTitle), findsOneWidget);
    expect(find.text(de.shortcutTomorrow), findsNWidgets(3));
    expect(find.text(de.repeatModeMonthly), findsOneWidget);
    expect(find.text('12. Okt. 2026 09:30'), findsOneWidget);
    expect(find.text(de.taskEditAddLabel), findsOneWidget);
    expect(find.text(de.taskEditAssign), findsOneWidget);
    expect(find.text(de.taskEditAddReminder), findsOneWidget);
  });

  testWidgets('Return confirms the title instead of adding a line', (
    tester,
  ) async {
    await openEditPage(tester, 1);

    final field = tester.widget<TextField>(titleField());
    expect(field.keyboardType, TextInputType.text);
    expect(field.textInputAction, TextInputAction.done);
  });

  testWidgets('at 200 % text scale in dark mode the form still works', (
    tester,
  ) async {
    useAccessibilityExtremes(tester);
    await openEditPage(tester, 1);

    await tester.enterText(titleField(), 'Changed');
    await tester.pumpAndSettle();
    await save(tester);

    expect(data.tasks.updates.single.$2, const TaskChanges(title: 'Changed'));
    expect(tester.takeException(), isNull);
  });
}
