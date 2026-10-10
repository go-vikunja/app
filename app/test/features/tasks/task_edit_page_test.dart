import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' hide RepeatMode;
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

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

  Future<void> openEditPage(WidgetTester tester, int id) async {
    // Tall enough for the whole form, which the list builds lazily.
    usePhoneSurface(tester, logicalSize: const Size(360, 2200));
    await pumpSignedInApp(tester, sync: data, now: now);
    unawaited(routerOf(tester).push(AppRoutes.taskEdit(id)));
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

    testWidgets("the sheet's Edit button closes it and opens the page over "
        'the shell', (tester) async {
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
    testWidgets('sends only the changed fields, pops and confirms', (
      tester,
    ) async {
      await openEditPage(tester, 1);
      expect(saveEnabled(tester), isFalse);

      await tester.enterText(titleField(), 'Quarterly report Q4');
      await tester.tap(find.text(en.priorityUrgent));
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isTrue);
      await save(tester);

      expect(data.tasks.updates, [
        (1, const TaskChanges(title: 'Quarterly report Q4', priority: 4)),
      ]);
      expect(data.tasks.writes, ['update 1']);
      expect(find.byType(TaskEditPage), findsNothing);
      expect(location(tester), AppRoutes.overview);
      expect(find.text(en.taskEditSaved), findsOneWidget);
      expect(find.text('Quarterly report Q4'), findsOneWidget);
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
    testWidgets('back leaves at once while nothing changed', (tester) async {
      await openEditPage(tester, 1);

      await pressBack(tester);

      expect(find.byType(TaskEditPage), findsNothing);
      expect(find.text(en.taskEditDiscardTitle), findsNothing);
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

    testWidgets('the system back is guarded the same way', (tester) async {
      await openEditPage(tester, 1);
      await tester.enterText(titleField(), 'Changed');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDiscardTitle), findsOneWidget);
      expect(find.byType(TaskEditPage), findsOneWidget);
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
    Finder dueRow() => find.widgetWithText(ListTile, en.taskDetailDueDate);

    testWidgets('a shortcut on a task without a time uses the breakpoint '
        'time and reads out its day', (tester) async {
      await openEditPage(tester, 2);
      expect(find.text(en.taskEditDateNotSet), findsNWidgets(3));

      final tomorrow = find.text(en.shortcutTomorrow).first;
      expect(
        tester.getSemantics(tomorrow).label,
        en.shortcutSemantics(en.shortcutTomorrow, 'Sun, Oct 11'),
      );
      await tester.tap(tomorrow);
      await tester.pumpAndSettle();

      expect(find.text('Oct 11, 2026 12:00 PM'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(of: tomorrow, matching: find.byType(ChoiceChip)),
            )
            .selected,
        isTrue,
      );

      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          dueDate: DateChange.set(DateTime(2026, 10, 11, 12).toUtc()),
        ),
      );
    });

    testWidgets('a shortcut keeps the time already set', (tester) async {
      await openEditPage(tester, 1);

      await tester.ensureVisible(find.text(en.shortcutNextWeek).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.shortcutNextWeek).first);
      await tester.pumpAndSettle();

      expect(find.text('Oct 17, 2026 9:30 AM'), findsOneWidget);
      await save(tester);
      expect(
        data.tasks.updates.single.$2.dueDate,
        DateChange.set(DateTime(2026, 10, 17, 9, 30).toUtc()),
      );
    });

    testWidgets('tapping the selected shortcut again clears the date', (
      tester,
    ) async {
      await openEditPage(tester, 1);
      final nextMonday = find.text(en.shortcutNextMonday).first;
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(of: nextMonday, matching: find.byType(ChoiceChip)),
            )
            .selected,
        isTrue,
      );

      await tester.ensureVisible(nextMonday);
      await tester.pumpAndSettle();
      await tester.tap(nextMonday);
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDateNotSet), findsNWidgets(3));
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(dueDate: DateChange.clear()),
      );
    });

    testWidgets('Clear removes the date', (tester) async {
      await openEditPage(tester, 1);

      await tester.tap(find.byTooltip(en.taskEditClearDueDate));
      await tester.pumpAndSettle();

      expect(find.text(en.taskEditDateNotSet), findsNWidgets(3));
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(dueDate: DateChange.clear()),
      );
    });

    testWidgets('the row opens the date picker, then the time picker', (
      tester,
    ) async {
      await openEditPage(tester, 1);

      await tester.tap(dueRow());
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Oct 15, 2026 9:30 AM'), findsOneWidget);
    });

    testWidgets('a start date set by chip and an end date cleared go '
        'together', (tester) async {
      await openEditPage(tester, 1);

      await tester.tap(find.text(en.shortcutToday).at(1));
      await tester.pumpAndSettle();
      await save(tester);

      expect(
        data.tasks.updates.single.$2,
        TaskChanges(
          startDate: DateChange.set(DateTime(2026, 10, 10, 12).toUtc()),
        ),
      );
    });
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

    testWidgets('a colour swatch sets the colour, No colour clears it', (
      tester,
    ) async {
      await openEditPage(tester, 2);

      await tester.tap(
        find.bySemanticsLabel(en.taskEditColourSemantics('#1973ff')),
      );
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(hexColor: '1973ff'),
      );
      expect(data.tasks.find(2)?.hexColor, '1973ff');

      unawaited(routerOf(tester).push(AppRoutes.taskEdit(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(en.taskEditNoColour));
      await tester.pumpAndSettle();
      await save(tester);
      expect(data.tasks.updates.last.$2, const TaskChanges(hexColor: ''));
    });

    testWidgets('a custom colour of the task is offered next to the defaults', (
      tester,
    ) async {
      data.tasks.all = [
        sampleTask(id: 5, title: 'Teal').copyWith(hexColor: '008080'),
      ];
      await openEditPage(tester, 5);

      expect(
        find.bySemanticsLabel(en.taskEditColourSemantics('#008080')),
        findsOneWidget,
      );
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
      await tester.tap(find.text(en.repeatModeFromCompletion));
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        data.tasks.updates.single.$2,
        const TaskChanges(
          repeatAfter: Duration(days: 3),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      );
    });

    testWidgets('the project picker lists the tree without archived '
        'projects and moves the task', (tester) async {
      await openEditPage(tester, 1);
      expect(find.widgetWithText(ListTile, 'Work'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, en.taskEditProject));
      await tester.pumpAndSettle();
      expect(find.text(en.taskEditProjectPickerTitle), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Personal'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(ListTile, en.taskEditProject));
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
      expect(find.widgetWithText(ListTile, 'Personal'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
