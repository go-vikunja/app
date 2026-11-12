import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/common/presentation/announce.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/attribute_editors.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/reminder_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/related_tasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/relation_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relations/subtasks_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_meta.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';

import '../../helpers/announcer_region.dart';
import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/label_user_fakes.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  // A Saturday at noon, the breakpoint time.
  final now = DateTime(2026, 10, 10, 12);
  final errand = sampleLabel(id: 1, title: 'Errand');
  final finance = sampleLabel(id: 2, title: 'Finance');
  const dayBefore = TaskReminder(
    relativePeriod: Duration(days: -1),
    relativeTo: ReminderRelativeTo.dueDate,
  );
  final dayBeforeText = en.reminderBefore('1 day', en.reminderReferenceDueDate);

  Task everything(int id, String title, {int projectId = 1}) => sampleTask(
    id: id,
    title: title,
    projectId: projectId,
    due: DateTime(2026, 10, 12, 9, 30),
    start: DateTime(2026, 10, 11, 8),
    priority: TaskPriority.high,
    reminders: const [dayBefore],
    labels: [errand],
  );

  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(
        id: 1,
        title: 'Work',
        views: [sampleListView(id: 10, projectId: 1)],
      ),
      sampleProject(
        id: 2,
        title: 'Shared',
        views: [sampleListView(id: 20, projectId: 2)],
      ).copyWith(maxPermission: Permission.read),
      sampleProject(
        id: 3,
        title: 'Old',
        archived: true,
        views: [sampleListView(id: 30, projectId: 3)],
      ),
    ];
    data.tasks.all = [
      everything(1, 'Report'),
      sampleTask(id: 2, title: 'Bare'),
      everything(3, 'Read me', projectId: 2),
      sampleTask(
        id: 4,
        title: 'Kept',
        projectId: 3,
        priority: TaskPriority.low,
        relatedTasks: {
          TaskRelationKind.subtask: [
            sampleTask(id: 5, title: 'Kept sub', projectId: 3),
          ],
        },
      ),
      sampleTask(id: 5, title: 'Kept sub', projectId: 3),
      sampleTask(
        id: 6,
        title: 'Parent',
        relatedTasks: {
          TaskRelationKind.subtask: [
            sampleTask(id: 5, title: 'Kept sub', projectId: 3),
            sampleTask(id: 7, title: 'Work sub'),
          ],
        },
      ),
      sampleTask(id: 7, title: 'Work sub'),
    ];
    data.tasks.knownLabels[finance.id] = finance;
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 1600),
  }) async {
    usePhoneSurface(tester, logicalSize: size);
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

  Future<void> openDetail(WidgetTester tester, Task task) async {
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: task));
    await tester.pumpAndSettle();
  }

  Future<void> openStored(WidgetTester tester, int id) =>
      openDetail(tester, data.tasks.find(id)!);

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  Finder addLine() => inSheet(find.byType(AddAttributeLine));

  Finder addButton(String text) => find.descendant(
    of: addLine(),
    matching: find.widgetWithText(TextButton, text),
  );

  /// The option sheet, picker or reminders sheet over the detail.
  Finder over(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet).last, matching: finder);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> said(WidgetTester tester) => [
    for (final announcement in tester.takeAnnouncements()) announcement.message,
  ];

  group('a task the user may change', () {
    testWidgets('each row opens its editor, which queues one change and '
        'leaves the sheet open', (tester) async {
      await pumpApp(tester);
      await openStored(tester, 1);

      await tap(tester, inSheet(find.text(en.taskDetailPriority)));
      expect(over(find.text(en.priorityUrgent)), findsOneWidget);
      await tap(tester, over(find.text(en.priorityUrgent)));
      expect(data.tasks.updates, [
        (1, TaskChanges(priority: TaskPriority.urgent.value)),
      ]);
      expect(inSheet(find.text(en.priorityUrgent)), findsOneWidget);

      await tap(tester, inSheet(find.text(dayBeforeText)));
      expect(find.byType(TaskRemindersSheet), findsOneWidget);
      await tap(
        tester,
        over(find.byTooltip(en.taskEditRemoveReminder(dayBeforeText))),
      );
      await tap(tester, over(find.text(en.pickerDone)));
      expect(data.tasks.updates, hasLength(2));
      expect(data.tasks.updates.last.$1, 1);
      expect(data.tasks.updates.last.$2.reminders, isEmpty);

      await tap(tester, inSheet(find.byTooltip(en.taskDetailChangeLabels)));
      expect(find.byType(LabelPicker), findsOneWidget);
      await tap(
        tester,
        find.descendant(
          of: find.byType(LabelPicker),
          matching: find.widgetWithText(CheckboxListTile, 'Finance'),
        ),
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(LabelPicker),
          matching: find.text(en.pickerDone),
        ),
      );
      expect(data.tasks.updates.last, (
        1,
        const TaskChanges(labels: IdSetChange(added: {2})),
      ));

      await tap(tester, inSheet(find.text(en.taskDetailDueDateRow)));
      await tap(tester, over(find.text(en.taskEditClearDueDate)));
      expect(data.tasks.updates.last, (
        1,
        const TaskChanges(dueDate: DateChange.clear()),
      ));
      expect(data.tasks.updates, hasLength(4));
      expect(find.byType(TaskDetailSheet), findsOneWidget);
    });

    testWidgets('a bare task gets a card of its own with a plus for each '
        'property, each of which sets it', (tester) async {
      await pumpApp(tester);
      await openStored(tester, 2);

      for (final text in [
        en.taskDetailDueDate,
        en.taskDetailPriority,
        en.taskDetailAddLineReminder,
        en.taskDetailAddLineLabel,
      ]) {
        expect(addButton(text), findsOneWidget, reason: text);
      }

      await tap(tester, addButton(en.taskDetailDueDate));
      await tap(tester, over(find.text(en.shortcutToday)));
      expect(data.tasks.updates.last, (
        2,
        TaskChanges(dueDate: DateChange.set(now.toUtc())),
      ));
      expect(addButton(en.taskDetailDueDate), findsNothing);
      expect(inSheet(find.text(en.taskDetailDueDateRow)), findsOneWidget);

      await tap(tester, addButton(en.taskDetailPriority));
      await tap(tester, over(find.text(en.priorityUrgent)));
      expect(data.tasks.updates.last, (
        2,
        TaskChanges(priority: TaskPriority.urgent.value),
      ));

      await tap(tester, addButton(en.taskDetailAddLineReminder));
      expect(find.byType(ReminderPicker), findsOneWidget);
      await tap(
        tester,
        find.descendant(
          of: find.byType(ReminderPicker),
          matching: find.text(dayBeforeText),
        ),
      );
      expect(data.tasks.updates.last, (
        2,
        const TaskChanges(reminders: [dayBefore]),
      ));

      await tap(tester, addButton(en.taskDetailAddLineLabel));
      await tap(
        tester,
        find.descendant(
          of: find.byType(LabelPicker),
          matching: find.widgetWithText(CheckboxListTile, 'Errand'),
        ),
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(LabelPicker),
          matching: find.text(en.pickerDone),
        ),
      );
      expect(data.tasks.updates.last, (
        2,
        const TaskChanges(labels: IdSetChange(added: {1})),
      ));

      expect(data.tasks.updates, hasLength(4));
      expect(addLine(), findsNothing);
      expect(inSheet(find.byType(LabelPill)), findsOneWidget);
    });

    testWidgets('the due date, priority and reminder rows are buttons with '
        'their hints, labels have a button of their own, the other rows '
        'stay text', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);
      await openStored(tester, 1);

      for (final (name, hint) in [
        (en.taskDetailDueDateRow, en.taskDetailChangeDueDate),
        (en.taskDetailPriority, en.taskDetailChangePriority),
        (en.taskDetailReminders, en.taskDetailEditReminders),
      ]) {
        final row = tester.getSemantics(inSheet(find.text(name)));
        expect(row.label, contains(name), reason: name);
        expect(
          row,
          isSemantics(isButton: true, hasTapAction: true, onTapHint: hint),
          reason: name,
        );
      }
      expect(
        tester.getSemantics(inSheet(find.text(en.taskDetailStartDate))),
        isSemantics(isButton: false, hasTapAction: false),
      );
      final changeLabels = inSheet(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == en.taskDetailChangeLabels,
        ),
      );
      expect(changeLabels, findsOneWidget);
      // Not the pencil of the header's Edit task.
      expect(
        tester.widget<IconButton>(changeLabels).icon,
        isA<Icon>().having(
          (icon) => icon.icon,
          'icon',
          Icons.new_label_outlined,
        ),
      );
      final size = tester.getSize(changeLabels);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(inSheet(find.byType(LabelPill))).center.dy,
        moreOrLessEquals(tester.getRect(changeLabels).center.dy, epsilon: 0.5),
      );
      // The pill still opens the label's tasks.
      expect(
        tester.widget<LabelPill>(inSheet(find.byType(LabelPill))).onTap,
        isNotNull,
      );
      semantics.dispose();
    });

    for (final platformAnnounces in [true, false]) {
      testWidgets(
        platformAnnounces
            ? 'a change is said once where the platform announces'
            : 'a change is said once where it cannot, as on Android',
        (tester) async {
          if (!platformAnnounces) useLiveRegionAnnouncements(tester);
          await pumpApp(tester);
          await openStored(tester, 1);
          await tap(tester, inSheet(find.text(en.taskDetailPriority)));

          final spoken = SpokenCount(
            tester,
            en.prioritySemantics(en.priorityUrgent),
          );
          await tester.tap(over(find.text(en.priorityUrgent)));
          await spoken.frames();

          expect(spoken.times, 1);
          expect(spoken.byAnnouncerRegion, platformAnnounces ? 0 : 1);
          await tester.pump(AnnouncerHost.clearAfter);
        },
      );
    }

    testWidgets('at 200 % text the rows still open their editors and the '
        'plus buttons wrap inside the card', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: const Size(360, 2400));
      await openStored(tester, 2);

      expect(tester.takeException(), isNull);
      final buttons = [
        for (final text in [
          en.taskDetailDueDate,
          en.taskDetailPriority,
          en.taskDetailAddLineReminder,
          en.taskDetailAddLineLabel,
        ])
          tester.getRect(addButton(text)),
      ];
      final card = tester.getRect(addLine());
      for (final button in buttons) {
        expect(button.left, greaterThanOrEqualTo(card.left));
        expect(button.right, lessThanOrEqualTo(card.right));
        expect(button.height, greaterThanOrEqualTo(48));
      }
      expect(buttons.last.top, greaterThan(buttons.first.top));

      await tap(tester, addButton(en.taskDetailPriority));
      await tap(tester, over(find.text(en.priorityLow)));
      expect(data.tasks.updates.last, (
        2,
        TaskChanges(priority: TaskPriority.low.value),
      ));

      await tap(tester, inSheet(find.text(en.taskDetailPriority)));
      expect(over(find.text(en.priorityUrgent)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('after an editor the keyboard stays down, even when the '
      'comment field had the focus', (tester) async {
    data.details.detailsByTask[1] = const TaskDetails(
      maxPermission: Permission.write,
    );
    await pumpApp(tester);
    await openStored(tester, 1);
    final field = inSheet(
      find.descendant(
        of: find.byType(CommentComposer),
        matching: find.byType(TextField),
      ),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tap(tester, inSheet(find.text(en.taskDetailPriority)));
    await tap(tester, over(find.text(en.priorityUrgent)));

    expect(data.tasks.updates, hasLength(1));
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isNot(true));
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('the keyboard focus comes back to the row that opened an '
      'editor, after a pick or Escape', (tester) async {
    await pumpApp(tester);
    await openStored(tester, 1);

    Future<FocusNode> openFrom(String row) async {
      final node = Focus.of(tester.element(inSheet(find.text(row))))
        ..requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      return node;
    }

    final priority = await openFrom(en.taskDetailPriority);
    await tap(tester, over(find.text(en.priorityUrgent)));
    expect(data.tasks.updates, hasLength(1));
    expect(priority.hasPrimaryFocus, isTrue);

    final due = await openFrom(en.taskDetailDueDateRow);
    expect(over(find.text(en.taskEditClearDueDate)), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(over(find.text(en.taskEditClearDueDate)), findsNothing);
    expect(due.hasPrimaryFocus, isTrue);
  });

  testWidgets('in a project the user may only read, no row is a button and '
      'nothing is offered to add', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await openStored(tester, 3);

    for (final name in [
      en.taskDetailDueDateRow,
      en.taskDetailPriority,
      en.taskDetailReminders,
    ]) {
      expect(
        tester.getSemantics(inSheet(find.text(name))),
        isSemantics(isButton: false, hasTapAction: false),
        reason: name,
      );
    }
    expect(addLine(), findsNothing);
    expect(inSheet(find.byTooltip(en.taskDetailChangeLabels)), findsNothing);

    await tester.tap(inSheet(find.text(en.taskDetailPriority)));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(data.tasks.updates, isEmpty);
    semantics.dispose();
  });

  testWidgets('in an archived project the sheet only shows the task: no '
      'Done, Edit, star, title tap, plus buttons, subtasks or relations', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await openStored(tester, 4);

    expect(inSheet(find.text(en.taskDetailMarkDone)), findsNothing);
    expect(inSheet(find.byTooltip(en.taskEdit)), findsNothing);
    expect(
      tester
          .widget<FavouriteButton>(inSheet(find.byType(FavouriteButton)))
          .onChanged,
      isNull,
    );
    expect(
      tester.getSemantics(inSheet(find.text('Kept'))),
      isSemantics(isHeader: true, isButton: false, hasTapAction: false),
    );
    expect(addLine(), findsNothing);
    expect(
      tester.getSemantics(inSheet(find.text(en.taskDetailPriority))),
      isSemantics(isButton: false, hasTapAction: false),
    );
    final subtasks = tester.widget<SubtasksSection>(
      inSheet(find.byType(SubtasksSection)),
    );
    expect(subtasks.onAdd, isNull);
    expect(subtasks.onRemove, isNull);
    final control = tester.widget<TaskDoneControl>(
      find.descendant(
        of: inSheet(find.widgetWithText(RelationRow, 'Kept sub')),
        matching: find.byType(TaskDoneControl),
      ),
    );
    expect(control.onChanged, isNull);
    expect(control.readOnly, isTrue);
    final related = tester.widget<RelatedTasksSection>(
      inSheet(find.byType(RelatedTasksSection)),
    );
    expect(related.onAdd, isNull);
    expect(related.onRemove, isNull);
    semantics.dispose();
  });

  testWidgets('a subtask in an archived project gets no checkbox under a '
      'task the user may change', (tester) async {
    await pumpApp(tester);
    await openStored(tester, 6);

    TaskDoneControl controlOf(String title) => tester.widget<TaskDoneControl>(
      find.descendant(
        of: inSheet(find.widgetWithText(RelationRow, title)),
        matching: find.byType(TaskDoneControl),
      ),
    );
    expect(controlOf('Kept sub').onChanged, isNull);
    expect(controlOf('Kept sub').readOnly, isTrue);
    expect(controlOf('Work sub').onChanged, isNotNull);
    expect(controlOf('Work sub').readOnly, isFalse);
  });

  testWidgets('a task this device has no row of offers nothing to change in '
      'place, whose change would be dropped', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);
    await openDetail(tester, everything(99, 'From the server'));

    expect(inSheet(find.text('From the server')), findsWidgets);
    expect(addLine(), findsNothing);
    expect(inSheet(find.byTooltip(en.taskDetailChangeLabels)), findsNothing);
    expect(
      tester.getSemantics(inSheet(find.text(en.taskDetailPriority))),
      isSemantics(isButton: false, hasTapAction: false),
    );
    semantics.dispose();
  });

  testWidgets('a link-share guest with write permission edits in place', (
    tester,
  ) async {
    final auth = AuthFakes();
    data.projects.all = [];
    data.tasks.all = [
      sampleTask(id: 4, title: 'Water the plants', projectId: guestProjectId),
    ];
    data.details.detailsByTask[4] = const TaskDetails(
      maxPermission: Permission.write,
    );
    usePhoneSurface(tester, logicalSize: const Size(400, 1600));
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      permission: Permission.write,
    );
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(guestProjectId));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water the plants'));
    await tester.pumpAndSettle();

    await tap(tester, addButton(en.taskDetailPriority));
    await tap(tester, over(find.text(en.priorityHigh)));

    expect(data.tasks.updates, [
      (4, TaskChanges(priority: TaskPriority.high.value)),
    ]);
    expect(inSheet(find.text(en.priorityHigh)), findsOneWidget);
  });

  final pane = find.byType(TaskDetailPane);

  Future<void> openInPane(WidgetTester tester) async {
    useWindow(tester, androidTabletLandscape);
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
    containerOf(tester).read(appRouterProvider).go(AppRoutes.project(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TaskRow, 'Report'));
    await tester.pumpAndSettle();
    expect(pane, findsOneWidget);
    tester.takeAnnouncements();
  }

  testWidgets('in the pane, an editor opens over the shell and the pane '
      'stays', (tester) async {
    await openInPane(tester);

    await tap(
      tester,
      find.descendant(of: pane, matching: find.text(en.taskDetailPriority)),
    );
    final options = find.byType(BottomSheet);
    expect(options, findsOneWidget);
    expect(find.descendant(of: pane, matching: options), findsNothing);
    expect(pane, findsOneWidget);

    await tap(tester, over(find.text(en.priorityDoNow)));
    expect(data.tasks.updates, [
      (1, TaskChanges(priority: TaskPriority.doNow.value)),
    ]);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.descendant(of: pane, matching: find.text(en.priorityDoNow)),
      findsOneWidget,
    );
    expect(said(tester), [en.prioritySemantics(en.priorityDoNow)]);
  });

  testWidgets('in the pane the keyboard focus comes back to the row after '
      'a pick', (tester) async {
    await openInPane(tester);
    final row = Focus.of(
      tester.element(
        find.descendant(of: pane, matching: find.text(en.taskDetailPriority)),
      ),
    )..requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tap(tester, over(find.text(en.priorityUrgent)));

    expect(data.tasks.updates, hasLength(1));
    expect(row.hasPrimaryFocus, isTrue);
  });

  testWidgets('a pick made after the window lost the room for the pane is '
      'still written, and the sheet that takes over shows it', (tester) async {
    await openInPane(tester);
    await tap(
      tester,
      find.descendant(of: pane, matching: find.text(en.taskDetailPriority)),
    );

    useWindow(tester, androidTabletPortrait);
    await tester.pumpAndSettle();
    expect(pane, findsNothing);
    expect(over(find.text(en.priorityUrgent)), findsOneWidget);
    await tap(tester, over(find.text(en.priorityUrgent)));

    expect(data.tasks.updates, [
      (1, TaskChanges(priority: TaskPriority.urgent.value)),
    ]);
    expect(said(tester), [en.prioritySemantics(en.priorityUrgent)]);
    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(inSheet(find.text(en.priorityUrgent)), findsOneWidget);
  });
}
