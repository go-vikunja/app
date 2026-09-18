import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/repeat_after_unit.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/color_picker_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_delete_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_save_dialog.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_controllers.dart';
import '../../../helpers/fake_repositories.dart';
import '../../../helpers/plugin_mocks.dart';
import '../../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late ControllerCalls calls;
  late FakeOutcome outcome;
  late TestRepositories repos;

  setUp(() {
    mockPlatformPlugins();
    calls = ControllerCalls();
    outcome = FakeOutcome();
    repos = TestRepositories();
  });

  /// Pushes the edit page onto a host route, the way the app reaches it: the
  /// page pops itself on save and delete.
  Future<void> pumpPage(WidgetTester tester, Task task) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Task?>(
                  builder: (_) => TaskEditPage(task: task),
                ),
              ),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
      overrides: [
        ...repos.overrides,
        currentUserOverride(buildUser()),
        taskPageOverride(buildTaskPageModel([task]), calls, outcome),
      ],
    );
    await tapAndSettle(tester, find.text('open editor'));
  }

  Finder titleField() => find.widgetWithText(TextFormField, 'Write the report');

  /// The label autocomplete's own text field, which sits among several others.
  Finder labelField() => find.descendant(
    of: find.byType(Autocomplete<String>),
    matching: find.byType(TextFormField),
  );

  group('rendering', () {
    testWidgets('prefills the title', (tester) async {
      await pumpPage(tester, buildTask(title: 'Write the report', priority: 0));

      expect(find.text(l10n.editTaskTitle), findsOneWidget);
      expect(find.text('Write the report'), findsOneWidget);
    });

    testWidgets('shows the description', (tester) async {
      await pumpPage(
        tester,
        buildTask(description: '<p>All the detail</p>', priority: 0),
      );

      expect(
        find.textContaining('All the detail', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('says so when there is no description', (tester) async {
      await pumpPage(tester, buildTask(description: '', priority: 0));

      expect(
        find.textContaining(l10n.noDescription, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('offers the three date fields', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      expect(find.text(l10n.dueDateLabel), findsOneWidget);
      expect(find.text(l10n.startDateLabel), findsOneWidget);
      expect(find.text(l10n.endDateLabel), findsOneWidget);
    });

    testWidgets('prefills the repeat interval and its unit', (tester) async {
      await pumpPage(
        tester,
        buildTask(repeatAfter: const Duration(days: 14), priority: 0),
      );

      expect(find.text('2'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<RepeatAfterUnit>>(
              find.byType(DropdownButtonFormField<RepeatAfterUnit>),
            )
            .initialValue,
        RepeatAfterUnit.weeks,
      );
    });

    testWidgets('prefills the priority', (tester) async {
      await pumpPage(tester, buildTask(priority: 3));

      expect(find.text(l10n.priorityHigh), findsOneWidget);
    });

    testWidgets('lists the existing labels', (tester) async {
      await pumpPage(
        tester,
        buildTask(
          priority: 0,
          labels: [
            buildLabel(id: 1, title: 'Bug'),
            buildLabel(id: 2, title: 'UI'),
          ],
        ),
      );

      expect(find.byType(LabelWidget), findsNWidgets(2));
      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('UI'), findsOneWidget);
    });

    testWidgets('lists the existing reminders', (tester) async {
      await pumpPage(
        tester,
        buildTask(
          priority: 0,
          reminderDates: [buildReminder(DateTime.utc(2030, 1, 1, 9))],
        ),
      );

      expect(find.text(l10n.reminder), findsOneWidget);
    });

    testWidgets('lists the attachments', (tester) async {
      await pumpPage(
        tester,
        buildTask(
          priority: 0,
          attachments: [buildAttachment(fileName: 'notes.txt')],
        ),
      );

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('says the colour is unset for an uncoloured task', (
      tester,
    ) async {
      await pumpPage(tester, buildTask(priority: 0, color: null));

      expect(find.text(l10n.none), findsOneWidget);
    });

    testWidgets('shows the hex value of a coloured task', (tester) async {
      await pumpPage(
        tester,
        buildTask(priority: 0, color: const Color(0xFF112233)),
      );

      expect(find.textContaining('#'), findsOneWidget);
    });
  });

  group('editing fields', () {
    testWidgets('typing a new title is saved', (tester) async {
      await pumpPage(tester, buildTask(title: 'Write the report', priority: 0));

      await enterTextAndSettle(tester, titleField(), 'Renamed');
      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(calls.updatedTasks.single.title, 'Renamed');
    });

    testWidgets('changing the priority is saved', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byType(DropdownButtonFormField<String>));
      await tapAndSettle(tester, find.text(l10n.priorityUrgent).last);
      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(calls.updatedTasks.single.priority, 4);
    });

    testWidgets('changing the repeat interval is saved', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextFormField, '0'),
        '3',
      );
      await tapAndSettle(
        tester,
        find.byType(DropdownButtonFormField<RepeatAfterUnit>),
      );
      await tapAndSettle(tester, find.text(l10n.repeatUnitDays).last);
      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(calls.updatedTasks.single.repeatAfter, const Duration(days: 3));
    });

    testWidgets('a non-numeric repeat interval counts as zero', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextFormField, '0'),
        'abc',
      );
      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(calls.updatedTasks.single.repeatAfter, Duration.zero);
    });
  });

  group('the colour picker', () {
    testWidgets('the colour button opens the picker', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.text(l10n.setColor));

      expect(find.byType(ColorPickerDialog), findsOneWidget);
    });

    testWidgets('confirming a colour shows it on the page', (tester) async {
      await pumpPage(
        tester,
        buildTask(priority: 0, color: const Color(0xFF00FF00)),
      );

      await tapAndSettle(tester, find.text(l10n.setColor));
      await tapAndSettle(tester, find.text(l10n.ok));

      expect(find.textContaining('#'), findsOneWidget);
    });

    testWidgets('resetting to black clears the colour', (tester) async {
      await pumpPage(
        tester,
        buildTask(priority: 0, color: const Color(0xFF00FF00)),
      );

      await tapAndSettle(tester, find.text(l10n.setColor));
      await tapAndSettle(tester, find.text(l10n.reset));
      await tapAndSettle(tester, find.text(l10n.ok));

      expect(find.text(l10n.none), findsOneWidget);
    });

    testWidgets('cancelling leaves the colour alone', (tester) async {
      await pumpPage(
        tester,
        buildTask(priority: 0, color: const Color(0xFF00FF00)),
      );

      await tapAndSettle(tester, find.text(l10n.setColor));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(find.textContaining('#'), findsOneWidget);
    });
  });

  group('labels', () {
    testWidgets('removing a label drops it from the list', (tester) async {
      await pumpPage(
        tester,
        buildTask(priority: 0, labels: [buildLabel(id: 1, title: 'Bug')]),
      );

      await tapAndSettle(tester, find.byIcon(Icons.cancel));

      expect(find.byType(LabelWidget), findsNothing);
    });

    testWidgets('the add button creates a label from the typed name', (
      tester,
    ) async {
      repos.label.onCreate = (label) =>
          ok(buildLabel(id: 9, title: label.title));
      await pumpPage(tester, buildTask(priority: 0));

      await enterTextAndSettle(tester, labelField(), 'Regression');
      await tapAndSettle(tester, find.byIcon(Icons.add));

      expect(repos.label.createCalls.single.title, 'Regression');
      expect(find.text('Regression'), findsWidgets);
    });

    testWidgets('the add button does nothing for an empty name', (
      tester,
    ) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.add));

      expect(repos.label.createCalls, isEmpty);
    });

    testWidgets('saving sends the label set to the api', (tester) async {
      final label = buildLabel(id: 1, title: 'Bug');
      await pumpPage(tester, buildTask(priority: 0, labels: [label]));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(repos.labelBulk.updateCalls.single.single.id, 1);
    });

    testWidgets('a failed label save reports the error', (tester) async {
      repos.labelBulk.onUpdate = (_, _) => err<List<Label>>();
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(find.text(l10n.taskSaveError), findsOneWidget);
      expect(calls.called('updateTask'), isFalse);
    });
  });

  group('reminders', () {
    testWidgets('the add-reminder row opens a date picker', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.text(l10n.addReminder));

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('cancelling the date picker adds no reminder', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.text(l10n.addReminder));
      await tapAndSettle(tester, find.text('Cancel'));

      expect(find.text(l10n.reminder), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('the save button saves the task', (tester) async {
      await pumpPage(tester, buildTask(id: 12, priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(calls.updatedTasks.single.id, 12);
    });

    testWidgets('a successful save confirms with a snackbar', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(find.text(l10n.taskUpdatedSuccess), findsOneWidget);
    });

    testWidgets('a failed save reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(find.text(l10n.taskSaveError), findsOneWidget);
    });

    testWidgets('a successful save closes the page', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.save));

      expect(find.byType(TaskEditPage), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('the delete action asks for confirmation', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.delete));

      expect(find.byType(TaskDeleteDialog), findsOneWidget);
    });

    testWidgets('confirming deletes the task', (tester) async {
      await pumpPage(tester, buildTask(id: 12, priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.delete));
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(calls.deletedTaskIds, [12]);
    });

    testWidgets('a successful delete closes the page', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.delete));
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(find.byType(TaskEditPage), findsNothing);
    });

    testWidgets('a failed delete reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.delete));
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(find.text(l10n.taskDeleteError), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpPage(tester, buildTask(priority: 0));

      await tapAndSettle(tester, find.byIcon(Icons.delete));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.deletedTaskIds, isEmpty);
      expect(find.byType(TaskEditPage), findsOneWidget);
    });
  });

  group('leaving with unsaved changes', () {
    testWidgets('backing out after an edit asks to confirm', (tester) async {
      await pumpPage(tester, buildTask(title: 'Write the report', priority: 0));

      await enterTextAndSettle(tester, titleField(), 'Renamed');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(TaskSaveDialog), findsOneWidget);
    });

    testWidgets('choosing Dismiss leaves the page', (tester) async {
      await pumpPage(tester, buildTask(title: 'Write the report', priority: 0));

      await enterTextAndSettle(tester, titleField(), 'Renamed');
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text(l10n.dismiss));

      expect(find.byType(TaskEditPage), findsNothing);
      expect(calls.called('updateTask'), isFalse);
    });

    testWidgets('choosing Keep editing stays on the page', (tester) async {
      await pumpPage(tester, buildTask(title: 'Write the report', priority: 0));

      await enterTextAndSettle(tester, titleField(), 'Renamed');
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text(l10n.keepEditing));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });

    testWidgets('backing out without edits leaves straight away', (
      tester,
    ) async {
      await pumpPage(tester, buildTask(priority: 0));

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(TaskSaveDialog), findsNothing);
      expect(find.byType(TaskEditPage), findsNothing);
    });
  });

  group('attachments', () {
    testWidgets('the download button asks the repository for the file', (
      tester,
    ) async {
      await pumpPage(
        tester,
        buildTask(
          priority: 0,
          attachments: [buildAttachment(fileName: 'notes.txt')],
        ),
      );

      await tester.tap(find.byIcon(Icons.download));
      await tester.pump();

      expect(repos.task.downloadCalls.single.file.name, 'notes.txt');
    });
  });
}
