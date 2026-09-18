/// Task list rows, the action menu and the detail bottom sheet — every tap,
/// checkbox and menu entry a user can reach on a task.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/pages/task/task_comments_page.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_actions.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task_bottom_sheet.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  group('TaskActions in menu mode', () {
    testWidgets('shows an overflow button, not inline icons', (tester) async {
      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () {},
          variant: TaskActionsVariant.menu,
        ),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('opening the menu offers Comments and Edit', (tester) async {
      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () {},
          variant: TaskActionsVariant.menu,
        ),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));

      expect(find.text(l10n.comments), findsOneWidget);
      expect(find.text(l10n.edit), findsOneWidget);
    });

    testWidgets('choosing Edit fires onEdit', (tester) async {
      var edited = false;

      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () => edited = true,
          variant: TaskActionsVariant.menu,
        ),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.edit));

      expect(edited, isTrue);
    });

    testWidgets('choosing Comments opens the comments page', (tester) async {
      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(id: 12, title: 'Ship it'),
          onEdit: () {},
          variant: TaskActionsVariant.menu,
        ),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.comments));

      expect(find.byType(TaskCommentsPage), findsOneWidget);
      expect(find.text('Ship it'), findsOneWidget);
    });
  });

  group('TaskActions in icons mode', () {
    testWidgets('shows inline comment and edit icons', (tester) async {
      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () {},
          variant: TaskActionsVariant.icons,
        ),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.comment), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('tapping edit fires onEdit', (tester) async {
      var edited = false;

      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () => edited = true,
          variant: TaskActionsVariant.icons,
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(edited, isTrue);
    });

    testWidgets('tapping comment opens the comments page', (tester) async {
      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(id: 12, title: 'Ship it'),
          onEdit: () {},
          variant: TaskActionsVariant.icons,
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.comment));

      expect(find.byType(TaskCommentsPage), findsOneWidget);
    });

    testWidgets('runs onBeforeAction before editing', (tester) async {
      final order = <String>[];

      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () => order.add('edit'),
          variant: TaskActionsVariant.icons,
          onBeforeAction: () => order.add('before'),
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(order, ['before', 'edit']);
    });

    testWidgets('runs onBeforeAction before opening comments', (tester) async {
      var ranBefore = false;

      await pumpApp(
        tester,
        TaskActions(
          task: buildTask(),
          onEdit: () {},
          variant: TaskActionsVariant.icons,
          onBeforeAction: () => ranBefore = true,
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.comment));

      expect(ranBefore, isTrue);
    });
  });

  group('TaskListItem', () {
    Widget item(
      Task task, {
      VoidCallback? onTap,
      VoidCallback? onEdit,
      void Function(bool)? onCheckedChanged,
    }) => TaskListItem(
      task: task,
      onTap: onTap ?? () {},
      onEdit: onEdit ?? () {},
      onCheckedChanged: onCheckedChanged ?? (_) {},
    );

    testWidgets('shows the task title', (tester) async {
      await pumpApp(
        tester,
        item(buildTask(title: 'Write the report')),
        inScaffold: true,
      );

      expect(find.text('Write the report'), findsOneWidget);
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;

      await pumpApp(
        tester,
        item(buildTask(), onTap: () => tapped = true),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byType(ListTile));

      expect(tapped, isTrue);
    });

    testWidgets('ticking the checkbox reports the new value', (tester) async {
      bool? reported;

      await pumpApp(
        tester,
        item(
          buildTask(done: false),
          onCheckedChanged: (value) => reported = value,
        ),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byType(Checkbox));

      expect(reported, isTrue);
    });

    testWidgets('reflects a done task as ticked', (tester) async {
      await pumpApp(tester, item(buildTask(done: true)), inScaffold: true);

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('editing from the row menu fires onEdit', (tester) async {
      var edited = false;

      await pumpApp(
        tester,
        item(buildTask(), onEdit: () => edited = true),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.edit));

      expect(edited, isTrue);
    });

    testWidgets('shows the project name when there is nothing else to show', (
      tester,
    ) async {
      await pumpApp(
        tester,
        item(buildTask(project: buildProject(title: 'Roadmap'))),
        inScaffold: true,
      );

      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('shows a due date card alongside the project name', (
      tester,
    ) async {
      await pumpApp(
        tester,
        item(
          buildTask(
            dueDate: DateTime.now().add(const Duration(days: 1)),
            project: buildProject(title: 'Roadmap'),
          ),
        ),
        inScaffold: true,
      );

      expect(find.byType(DueDateCard), findsOneWidget);
      expect(find.text('Roadmap'), findsOneWidget);
    });

    testWidgets('shows a priority badge for a prioritised task', (
      tester,
    ) async {
      await pumpApp(tester, item(buildTask(priority: 3)), inScaffold: true);

      expect(find.byType(PriorityBatch), findsOneWidget);
    });

    testWidgets('shows no priority badge for the unset priority', (
      tester,
    ) async {
      await pumpApp(tester, item(buildTask(priority: 0)), inScaffold: true);

      expect(find.byType(PriorityBatch), findsNothing);
    });

    testWidgets('shows no subtitle for a bare task', (tester) async {
      await pumpApp(
        tester,
        item(buildTask(priority: null, project: null)),
        inScaffold: true,
      );

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });
  });

  group('ProjectTaskListItem', () {
    Widget item(
      Task task, {
      VoidCallback? onTap,
      VoidCallback? onEdit,
      void Function(bool)? onCheckedChanged,
    }) => ProjectTaskListItem(
      task: task,
      onTap: onTap ?? () {},
      onEdit: onEdit ?? () {},
      onCheckedChanged: onCheckedChanged ?? (_) {},
    );

    testWidgets('shows the task title', (tester) async {
      await pumpApp(
        tester,
        item(buildTask(title: 'Write the report')),
        inScaffold: true,
      );

      expect(find.text('Write the report'), findsOneWidget);
    });

    testWidgets('tapping the row fires onTap', (tester) async {
      var tapped = false;

      await pumpApp(
        tester,
        item(buildTask(), onTap: () => tapped = true),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byType(ListTile));

      expect(tapped, isTrue);
    });

    testWidgets('ticking the checkbox reports the new value', (tester) async {
      bool? reported;

      await pumpApp(
        tester,
        item(buildTask(), onCheckedChanged: (value) => reported = value),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byType(Checkbox));

      expect(reported, isTrue);
    });

    testWidgets('editing from the row menu fires onEdit', (tester) async {
      var edited = false;

      await pumpApp(
        tester,
        item(buildTask(), onEdit: () => edited = true),
        inScaffold: true,
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.edit));

      expect(edited, isTrue);
    });

    testWidgets('shows due date and priority in the subtitle', (tester) async {
      await pumpApp(
        tester,
        item(
          buildTask(
            dueDate: DateTime.now().add(const Duration(days: 1)),
            priority: 4,
          ),
        ),
        inScaffold: true,
      );

      expect(find.byType(DueDateCard), findsOneWidget);
      expect(find.byType(PriorityBatch), findsOneWidget);
    });

    testWidgets('omits the subtitle when there is nothing to show', (
      tester,
    ) async {
      await pumpApp(
        tester,
        item(buildTask(priority: null, dueDate: null)),
        inScaffold: true,
      );

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    // Unlike TaskListItem, the project row never shows its own project name.
    testWidgets('never shows the project name', (tester) async {
      await pumpApp(
        tester,
        item(buildTask(project: buildProject(title: 'Roadmap'))),
        inScaffold: true,
      );

      expect(find.text('Roadmap'), findsNothing);
    });
  });

  group('TaskBottomSheet', () {
    Widget sheet(Task task, {VoidCallback? onEdit}) =>
        TaskBottomSheet(task: task, onEdit: onEdit ?? () {});

    testWidgets('shows the task title and description', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(title: 'Ship it', description: '<p>All of it</p>')),
        inScaffold: true,
      );

      expect(find.text('Ship it'), findsOneWidget);
      expect(find.text(l10n.description), findsOneWidget);
      // HtmlWidget renders into a RichText, so the finder has to look inside.
      expect(
        find.textContaining('All of it', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is no description', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(description: '')),
        inScaffold: true,
      );

      expect(
        find.textContaining(l10n.noDescription, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows the labels', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(labels: [buildLabel(title: 'Bug')])),
        inScaffold: true,
      );

      expect(find.byType(LabelWidget), findsOneWidget);
    });

    testWidgets('shows the due, start and end dates when set', (tester) async {
      final date = DateTime.utc(2030, 5, 6, 7, 8);

      await pumpApp(
        tester,
        sheet(buildTask(dueDate: date, startDate: date, endDate: date)),
        inScaffold: true,
      );

      expect(find.text(date.toLocal().formatShort()), findsNWidgets(3));
    });

    testWidgets('says so when the dates are unset', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(dueDate: null, startDate: null, endDate: null)),
        inScaffold: true,
      );

      expect(find.text(l10n.noDueDate), findsOneWidget);
      expect(find.text(l10n.noStartDate), findsOneWidget);
      expect(find.text(l10n.noEndDate), findsOneWidget);
    });

    testWidgets('lists the reminders', (tester) async {
      await pumpApp(
        tester,
        sheet(
          buildTask(
            reminderDates: [
              buildReminder(DateTime.utc(2030, 1, 1, 9)),
              buildReminder(DateTime.utc(2030, 1, 2, 9)),
            ],
          ),
        ),
        inScaffold: true,
      );

      expect(find.byIcon(Icons.share_arrival_time_outlined), findsNWidgets(2));
    });

    testWidgets('names the priority', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(priority: 4, percentDone: 0.5)),
        inScaffold: true,
      );

      expect(find.text(l10n.priorityUrgent), findsOneWidget);
    });

    testWidgets('names every priority level it can be given', (tester) async {
      for (final (priority, label) in [
        (0, l10n.priorityUnset),
        (1, l10n.priorityLow),
        (2, l10n.priorityMedium),
        (3, l10n.priorityHigh),
        (4, l10n.priorityUrgent),
        (5, l10n.priorityDoNow),
      ]) {
        // percentDone is set so the progress row cannot also read "Unset".
        await pumpApp(
          tester,
          sheet(buildTask(priority: priority, percentDone: 0.5)),
          inScaffold: true,
        );

        expect(find.text(label), findsOneWidget, reason: 'priority $priority');
      }
    });

    testWidgets('says so when the priority is unset', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(priority: null, percentDone: 0.5)),
        inScaffold: true,
      );

      expect(find.text(l10n.noPriority), findsOneWidget);
    });

    testWidgets('shows progress as a percentage', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(percentDone: 0.25)),
        inScaffold: true,
      );

      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('says so when progress is unset', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(percentDone: null)),
        inScaffold: true,
      );

      expect(find.text(l10n.percentUnset), findsOneWidget);
    });

    testWidgets('tapping edit fires onEdit', (tester) async {
      var edited = false;

      await pumpApp(
        tester,
        sheet(buildTask(), onEdit: () => edited = true),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.edit));

      expect(edited, isTrue);
    });

    testWidgets('tapping comment opens the comments page', (tester) async {
      await pumpApp(
        tester,
        sheet(buildTask(id: 12, title: 'Ship it')),
        inScaffold: true,
      );
      await tapAndSettle(tester, find.byIcon(Icons.comment));

      expect(find.byType(TaskCommentsPage), findsOneWidget);
    });
  });
}
