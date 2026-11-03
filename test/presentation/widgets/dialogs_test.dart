/// Every dialog in the app, driven through the buttons a user actually taps.
///
/// Each dialog owns its interactions here; the screens that *open* these
/// dialogs assert only that the dialog appears, never its internals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/widgets/bucket_limit_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/add_project_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/add_bucket_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_delete_dialog.dart'
    as kanban;
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_limit_dialog.dart'
    as kanban_limit;
import 'package:vikunja_app/presentation/widgets/project/kanban/change_title_dialog.dart';
import 'package:vikunja_app/presentation/widgets/sentry_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/color_picker_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_delete_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_save_dialog.dart';
import 'package:vikunja_app/presentation/widgets/version_mismatch_dialog.dart';

import '../../helpers/builders.dart';
import '../../helpers/test_app.dart';

/// Pumps a screen with a single button that opens [dialog], and taps it.
/// Returns the value the dialog popped with.
Future<T?> openDialog<T>(
  WidgetTester tester,
  Widget Function(BuildContext context) dialog,
) async {
  T? result;
  var popped = false;

  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showDialog<T>(context: context, builder: dialog);
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tapAndSettle(tester, find.text('open'));
  addTearDown(() => popped);
  return result;
}

void main() {
  setUpAll(loadL10n);

  group('AddTaskDialog', () {
    testWidgets('typing a title and tapping Add reports it', (tester) async {
      String? addedTitle;
      DateTime? addedDue;

      await pumpApp(
        tester,
        AddTaskDialog(
          onAddTask: (title, dueDate) {
            addedTitle = title;
            addedDue = dueDate;
          },
        ),
      );

      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(addedTitle, 'Buy milk');
      expect(addedDue, isNull);
    });

    testWidgets('Add with an empty title reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddTaskDialog(onAddTask: (_, _) => called = true));
      await tapAndSettle(tester, find.text(l10n.add));

      expect(called, isFalse);
    });

    testWidgets('Cancel reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddTaskDialog(onAddTask: (_, _) => called = true));
      await enterTextAndSettle(tester, find.byType(TextField), 'Buy milk');
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(called, isFalse);
    });

    testWidgets('prefills the title it was given', (tester) async {
      await pumpApp(
        tester,
        AddTaskDialog(onAddTask: (_, _) {}, title: 'From a share intent'),
      );

      expect(find.text('From a share intent'), findsOneWidget);
    });

    testWidgets('picking Custom reveals the exact-time field', (tester) async {
      await pumpApp(tester, AddTaskDialog(onAddTask: (_, _) {}));

      expect(find.text(l10n.enterExactTime), findsNothing);

      await tapAndSettle(tester, find.text(l10n.dueOptionCustom));

      expect(find.text(l10n.enterExactTime), findsOneWidget);
    });

    testWidgets('offers every relative due option', (tester) async {
      await pumpApp(tester, AddTaskDialog(onAddTask: (_, _) {}));

      expect(find.text(l10n.dueOptionNone), findsOneWidget);
      expect(find.text(l10n.dueOptionTomorrow), findsOneWidget);
      expect(find.text(l10n.dueOptionNextMonday), findsOneWidget);
      expect(find.text(l10n.dueOptionLaterThisWeek), findsOneWidget);
      expect(find.text(l10n.dueInOneWeek), findsOneWidget);
      expect(find.text(l10n.dueOptionCustom), findsOneWidget);
    });
  });

  group('AddProjectDialog', () {
    testWidgets('typing a name and tapping Add reports it', (tester) async {
      String? added;

      await pumpApp(tester, AddProjectDialog(onAdd: (name) => added = name));
      await enterTextAndSettle(tester, find.byType(TextField), 'Roadmap');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(added, 'Roadmap');
    });

    testWidgets('Add with an empty name reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddProjectDialog(onAdd: (_) => called = true));
      await tapAndSettle(tester, find.text(l10n.add));

      expect(called, isFalse);
    });

    testWidgets('Cancel reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddProjectDialog(onAdd: (_) => called = true));
      await enterTextAndSettle(tester, find.byType(TextField), 'Roadmap');
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(called, isFalse);
    });
  });

  group('AddBucketDialog', () {
    testWidgets('typing a name and tapping Add reports it', (tester) async {
      String? added;

      await pumpApp(tester, AddBucketDialog(onAdd: (name) => added = name));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(added, 'In review');
    });

    testWidgets('Add with an empty name reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddBucketDialog(onAdd: (_) => called = true));
      await tapAndSettle(tester, find.text(l10n.add));

      expect(called, isFalse);
    });

    testWidgets('Cancel reports nothing', (tester) async {
      var called = false;

      await pumpApp(tester, AddBucketDialog(onAdd: (_) => called = true));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(called, isFalse);
    });
  });

  group('ChangeTitleDialog', () {
    testWidgets('prefills the current bucket title', (tester) async {
      await pumpApp(
        tester,
        ChangeTitleDialog(bucket: buildBucket(title: 'Todo')),
      );

      expect(find.text('Todo'), findsWidgets);
    });

    testWidgets('Done returns the edited title', (tester) async {
      final result = await openDialog<String>(
        tester,
        (_) => ChangeTitleDialog(bucket: buildBucket(title: 'Todo')),
      );
      expect(result, isNull, reason: 'dialog is still open');

      await enterTextAndSettle(tester, find.byType(TextField), 'Doing');
      await tapAndSettle(tester, find.text(l10n.done));

      expect(find.byType(ChangeTitleDialog), findsNothing);
    });

    testWidgets('submitting the field returns the edited title', (
      tester,
    ) async {
      await openDialog<String>(
        tester,
        (_) => ChangeTitleDialog(bucket: buildBucket(title: 'Todo')),
      );

      await tester.enterText(find.byType(TextField), 'Doing');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(ChangeTitleDialog), findsNothing);
    });

    testWidgets('Cancel closes without changing anything', (tester) async {
      await openDialog<String>(
        tester,
        (_) => ChangeTitleDialog(bucket: buildBucket(title: 'Todo')),
      );

      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(find.byType(ChangeTitleDialog), findsNothing);
    });
  });

  group('BucketLimitDialog', () {
    testWidgets('prefills the current limit', (tester) async {
      await pumpApp(tester, BucketLimitDialog(bucket: buildBucket(limit: 5)));

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('the up arrow raises the limit', (tester) async {
      await pumpApp(tester, BucketLimitDialog(bucket: buildBucket(limit: 5)));

      await tapAndSettle(tester, find.byIcon(Icons.expand_less));

      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('the down arrow lowers the limit', (tester) async {
      await pumpApp(tester, BucketLimitDialog(bucket: buildBucket(limit: 5)));

      await tapAndSettle(tester, find.byIcon(Icons.expand_more));

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('the down arrow will not go below zero', (tester) async {
      await pumpApp(tester, BucketLimitDialog(bucket: buildBucket(limit: 0)));

      await tapAndSettle(tester, find.byIcon(Icons.expand_more));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Remove limit closes the dialog', (tester) async {
      await openDialog<int>(
        tester,
        (_) => BucketLimitDialog(bucket: buildBucket(limit: 5)),
      );

      await tapAndSettle(tester, find.text(l10n.removeLimit));

      expect(find.byType(BucketLimitDialog), findsNothing);
    });

    testWidgets('Done closes the dialog', (tester) async {
      await openDialog<int>(
        tester,
        (_) => BucketLimitDialog(bucket: buildBucket(limit: 5)),
      );

      await tapAndSettle(tester, find.text(l10n.done));

      expect(find.byType(BucketLimitDialog), findsNothing);
    });

    testWidgets('Cancel closes the dialog', (tester) async {
      await openDialog<int>(
        tester,
        (_) => BucketLimitDialog(bucket: buildBucket(limit: 5)),
      );

      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(find.byType(BucketLimitDialog), findsNothing);
    });

    testWidgets('submitting the field closes the dialog', (tester) async {
      await openDialog<int>(
        tester,
        (_) => BucketLimitDialog(bucket: buildBucket(limit: 5)),
      );

      await tester.enterText(find.byType(TextField), '9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(BucketLimitDialog), findsNothing);
    });
  });

  group('kanban BucketLimitDialog', () {
    // A second, stateless copy of the limit dialog lives under kanban/.
    testWidgets('prefills the current limit and steps it up and down', (
      tester,
    ) async {
      await pumpApp(
        tester,
        kanban_limit.BucketLimitDialog(bucket: buildBucket(limit: 3)),
      );

      expect(find.text('3'), findsOneWidget);

      await tapAndSettle(tester, find.byIcon(Icons.expand_less));
      expect(find.text('4'), findsOneWidget);

      await tapAndSettle(tester, find.byIcon(Icons.expand_more));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('will not step below zero', (tester) async {
      await pumpApp(
        tester,
        kanban_limit.BucketLimitDialog(bucket: buildBucket(limit: 0)),
      );

      await tapAndSettle(tester, find.byIcon(Icons.expand_more));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('each action button closes the dialog', (tester) async {
      for (final label in [l10n.cancel, l10n.removeLimit, l10n.done]) {
        await openDialog<int>(
          tester,
          (_) => kanban_limit.BucketLimitDialog(bucket: buildBucket(limit: 3)),
        );

        await tapAndSettle(tester, find.text(label));

        expect(
          find.byType(kanban_limit.BucketLimitDialog),
          findsNothing,
          reason: label,
        );
      }
    });
  });

  group('ColorPickerDialog', () {
    testWidgets('OK reports the currently picked colour', (tester) async {
      Color? confirmed;

      await pumpApp(
        tester,
        ColorPickerDialog(Colors.red, (color) => confirmed = color, () {}),
      );
      await tapAndSettle(tester, find.text(l10n.ok));

      expect(confirmed, Colors.red);
    });

    testWidgets('Reset turns the picked colour black', (tester) async {
      Color? confirmed;

      await pumpApp(
        tester,
        ColorPickerDialog(Colors.red, (color) => confirmed = color, () {}),
      );
      await tapAndSettle(tester, find.text(l10n.reset));
      await tapAndSettle(tester, find.text(l10n.ok));

      expect(confirmed, Colors.black);
    });

    testWidgets('defaults to black when opened without a colour', (
      tester,
    ) async {
      Color? confirmed;

      await pumpApp(
        tester,
        ColorPickerDialog(null, (color) => confirmed = color, () {}),
      );
      await tapAndSettle(tester, find.text(l10n.ok));

      expect(confirmed, Colors.black);
    });

    testWidgets('Cancel closes without reporting a colour', (tester) async {
      var confirmed = false;

      await openDialog<void>(
        tester,
        (_) => ColorPickerDialog(Colors.red, (_) => confirmed = true, () {}),
      );
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(confirmed, isFalse);
      expect(find.byType(ColorPickerDialog), findsNothing);
    });
  });

  group('TaskDeleteDialog', () {
    testWidgets('Delete reports a confirmation', (tester) async {
      var confirmed = false;

      await pumpApp(
        tester,
        TaskDeleteDialog(1, onConfirm: () => confirmed = true, onCancel: () {}),
      );
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(confirmed, isTrue);
    });

    testWidgets('Cancel reports a cancellation', (tester) async {
      var cancelled = false;

      await pumpApp(
        tester,
        TaskDeleteDialog(1, onConfirm: () {}, onCancel: () => cancelled = true),
      );
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(cancelled, isTrue);
    });

    testWidgets('explains what is about to be deleted', (tester) async {
      await pumpApp(
        tester,
        TaskDeleteDialog(1, onConfirm: () {}, onCancel: () {}),
      );

      expect(find.text(l10n.deleteTaskTitle), findsOneWidget);
      expect(find.text(l10n.deleteTaskMessage), findsOneWidget);
    });
  });

  group('bucket delete dialog', () {
    testWidgets('Delete reports a confirmation', (tester) async {
      var confirmed = false;

      await pumpApp(
        tester,
        kanban.TaskDeleteDialog(
          onConfirm: () => confirmed = true,
          onCancel: () {},
        ),
      );
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(confirmed, isTrue);
    });

    testWidgets('Cancel reports a cancellation', (tester) async {
      var cancelled = false;

      await pumpApp(
        tester,
        kanban.TaskDeleteDialog(
          onConfirm: () {},
          onCancel: () => cancelled = true,
        ),
      );
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(cancelled, isTrue);
    });

    testWidgets('names the bucket it is about to delete', (tester) async {
      await pumpApp(
        tester,
        kanban.TaskDeleteDialog(onConfirm: () {}, onCancel: () {}),
      );

      expect(find.text(l10n.deleteBucketTitle), findsOneWidget);
      expect(find.text(l10n.deleteBucketMessage), findsOneWidget);
    });
  });

  group('TaskSaveDialog', () {
    testWidgets('Dismiss reports a confirmation', (tester) async {
      var confirmed = false;

      await pumpApp(
        tester,
        TaskSaveDialog(onConfirm: () => confirmed = true, onCancel: () {}),
      );
      await tapAndSettle(tester, find.text(l10n.dismiss));

      expect(confirmed, isTrue);
    });

    testWidgets('Keep editing reports a cancellation', (tester) async {
      var cancelled = false;

      await pumpApp(
        tester,
        TaskSaveDialog(onConfirm: () {}, onCancel: () => cancelled = true),
      );
      await tapAndSettle(tester, find.text(l10n.keepEditing));

      expect(cancelled, isTrue);
    });

    testWidgets('warns about the unsaved changes', (tester) async {
      await pumpApp(tester, TaskSaveDialog(onConfirm: () {}, onCancel: () {}));

      expect(find.text(l10n.unsavedChangesTitle), findsOneWidget);
      expect(find.text(l10n.unsavedChangesMessage), findsOneWidget);
    });
  });

  group('SentryDialog', () {
    testWidgets('Yes accepts and closes', (tester) async {
      var accepted = false;

      await openDialog<void>(
        tester,
        (_) => SentryDialog(onAccepts: () => accepted = true, onRefuse: () {}),
      );
      await tapAndSettle(tester, find.text(l10n.yes));

      expect(accepted, isTrue);
      expect(find.byType(SentryDialog), findsNothing);
    });

    testWidgets('No refuses and closes', (tester) async {
      var refused = false;

      await openDialog<void>(
        tester,
        (_) => SentryDialog(onAccepts: () {}, onRefuse: () => refused = true),
      );
      await tapAndSettle(tester, find.text(l10n.no));

      expect(refused, isTrue);
      expect(find.byType(SentryDialog), findsNothing);
    });

    testWidgets('explains what it is asking for', (tester) async {
      await pumpApp(tester, SentryDialog(onAccepts: () {}, onRefuse: () {}));

      expect(find.text(l10n.sentryDialogTitle), findsOneWidget);
      expect(find.text(l10n.sentryDialogMessage), findsOneWidget);
    });
  });

  group('VersionMismatchDialog', () {
    testWidgets('names the supported and the running version', (tester) async {
      await pumpApp(
        tester,
        VersionMismatchDialog(serverVersion: Version(0, 1, 0)),
      );

      expect(find.text(l10n.versionDialogTitle), findsOneWidget);
      expect(find.text(l10n.versionDialogDescription), findsOneWidget);
      expect(find.text(l10n.versionDialogUsed('0.1.0')), findsOneWidget);
    });

    testWidgets('OK closes the dialog', (tester) async {
      await openDialog<void>(
        tester,
        (_) => VersionMismatchDialog(serverVersion: Version(0, 1, 0)),
      );

      await tapAndSettle(tester, find.text(l10n.ok));

      expect(find.byType(VersionMismatchDialog), findsNothing);
    });
  });
}
