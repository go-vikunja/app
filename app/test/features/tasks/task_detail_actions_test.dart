import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_write_feedback.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_feedback.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Quarterly report', favorite: true),
      sampleTask(id: 2, title: 'Bare task'),
    ];
  });

  Future<void> openDetail(
    WidgetTester tester,
    String title, {
    ServerConnection? connection,
  }) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now, connection: connection);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder matching) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: matching);

  Future<void> openMenu(WidgetTester tester, String label) async {
    // The comment field below the list leaves it less room in large text.
    await tester.scrollUntilVisible(
      inSheet(find.byTooltip(label)),
      -200,
      scrollable: inSheet(find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.byTooltip(label)));
    await tester.pumpAndSettle();
  }

  testWidgets('Mark as done marks the task done, the sheet follows the row '
      'and offers Undo; Mark as not done reopens it and takes the Undo '
      'away', (tester) async {
    await openDetail(tester, 'Bare task');
    Finder markDone() =>
        inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone));
    Finder markNotDone() =>
        inSheet(find.widgetWithText(OutlinedButton, en.taskDetailMarkNotDone));
    expect(inSheet(find.text(en.taskDetailStatusOpen)), findsOneWidget);
    final doneSize = tester.getSize(markDone());
    final labelSize = tester
        .renderObject<RenderParagraph>(
          inSheet(find.text(en.taskDetailMarkDone)),
        )
        .text
        .style
        ?.fontSize;

    await tester.tap(markDone());
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 2 true']);
    expect(markDone(), findsNothing);
    expect(markNotDone(), findsOneWidget);
    expect(tester.getSize(markNotDone()), doneSize);
    expect(
      tester
          .renderObject<RenderParagraph>(
            inSheet(find.text(en.taskDetailMarkNotDone)),
          )
          .text
          .style
          ?.fontSize,
      labelSize,
    );
    expect(inSheet(find.text(en.taskDone)), findsOneWidget);
    final title = tester.widget<Text>(inSheet(find.text('Bare task')));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(
      inSheet(find.textContaining(en.taskDetailDoneWhen(''))),
      findsOneWidget,
    );
    // In the sheet's own messenger: the screen's sits behind the sheet.
    expect(inSheet(find.text(en.taskMarkedDone)), findsOneWidget);
    expect(inSheet(find.text(en.undo)), findsOneWidget);

    await tester.tap(markNotDone());
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 2 true', 'setDone 2 false']);
    expect(markDone(), findsOneWidget);
    expect(inSheet(find.text(en.taskDetailStatusOpen)), findsOneWidget);
    expect(
      inSheet(find.textContaining(en.taskDetailDoneWhen(''))),
      findsNothing,
    );
    expect(find.text(en.taskMarkedDone), findsNothing);
  });

  testWidgets('Undo in the sheet gives a repeating task the dates and '
      'reminders it had before the server moved them on', (tester) async {
    final due = DateTime.utc(2026, 10, 10, 18);
    final reminder = TaskReminder(reminder: DateTime.utc(2026, 10, 10, 17));
    data.tasks.all = [
      ...data.tasks.all,
      sampleTask(
        id: 3,
        title: 'Water the plants',
        due: due,
        reminders: [reminder],
        repeatAfter: const Duration(days: 1),
      ),
    ];
    await openDetail(tester, 'Water the plants');

    await tester.tap(
      inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
    );
    await tester.pumpAndSettle();
    expect(inSheet(find.text(en.taskMarkedDone)), findsOneWidget);
    // The server's answer: the next occurrence, open again.
    data.tasks.all = [
      for (final task in data.tasks.all)
        if (task.id == 3)
          task.copyWith(
            done: false,
            doneAt: null,
            dueDate: due.add(const Duration(days: 1)),
            reminders: [TaskReminder(reminder: DateTime.utc(2026, 10, 11, 17))],
          )
        else
          task,
    ];
    await tester.pump();

    await tester.tap(inSheet(find.text(en.undo)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setDone 3 true', 'undoDone 3']);
    final undone = data.tasks.find(3)!;
    expect(undone.done, isFalse);
    expect(undone.dueDate, due);
    expect(undone.reminders, [reminder]);
    expect(find.text(en.taskMarkedDone), findsNothing);
  });

  testWidgets('a sheet closed while its Undo is up hands the Undo to the '
      'screen below; one closed after it went shows none', (tester) async {
    await openDetail(tester, 'Bare task');
    Future<void> markDoneAndClose({Duration wait = Duration.zero}) async {
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
      );
      await tester.pumpAndSettle();
      expect(inSheet(find.text(en.taskMarkedDone)), findsOneWidget);
      await tester.pump(wait);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.byTooltip(en.taskDetailClose)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailSheet), findsNothing);
    }

    await markDoneAndClose(wait: const Duration(seconds: 1));

    expect(find.text(en.taskMarkedDone), findsOneWidget);
    await tester.tap(find.text(en.undo));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 2 true', 'undoDone 2']);
    expect(data.tasks.find(2)!.done, isFalse);

    await tester.pump(markedDoneSnackBarDuration);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bare task'));
    await tester.pumpAndSettle();
    await markDoneAndClose(wait: markedDoneSnackBarDuration);

    expect(find.text(en.taskMarkedDone), findsNothing);
  });

  testWidgets('a sheet an account switch closes while its Undo is up hands '
      "it to none of the next account's screens", (tester) async {
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    data.accounts[bob.id] = AccountDataFakes(now: now);
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
    await tester.tap(find.text('Bare task'));
    await tester.pumpAndSettle();
    await tester.tap(
      inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
    );
    await tester.pumpAndSettle();
    expect(inSheet(find.text(en.taskMarkedDone)), findsOneWidget);

    await containerOf(tester).read(accountRegistryProvider).setActive(bob.id);
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(find.text(en.taskMarkedDone), findsNothing);
  });

  testWidgets('an Undo handed below before a switch from outside reaches the '
      "providers goes with the switch, so it cannot undo in the next account's "
      'screens', (tester) async {
    final auth = AuthFakes();
    final bob = await auth.seedAccount(
      oauthServer230(),
      tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
      activate: false,
    );
    data.accounts[bob.id] = AccountDataFakes(now: now);
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, auth: auth, now: now);
    await tester.tap(find.text('Bare task'));
    await tester.pumpAndSettle();
    await tester.tap(
      inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
    );
    await tester.pumpAndSettle();
    final opener = containerOf(tester).read(taskOpenerProvider);
    // The switch's first step closes the sheet, which hands its Undo below
    // while the previous account is still active.
    expect(await popPagesOverShell(opener.router), LeaveOutcome.left);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(find.text(en.taskMarkedDone), findsOneWidget);

    final switched = opener.activate(bob.id);
    await tester.pumpAndSettle();

    expect(await switched, isTrue);
    expect(find.text(en.taskMarkedDone), findsNothing);
    expect(find.text(en.undo), findsNothing);
  });

  group('a change the device cannot store', () {
    setUp(() {
      data.tasks.beforeWrite = () async =>
          throw const FileSystemException('No space left on device');
    });

    testWidgets('Mark as done says so in the sheet, without Marked as '
        'done', (tester) async {
      await openDetail(tester, 'Bare task');

      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['setDone 2 true']);
      expect(inSheet(find.text(en.localChangeFailed)), findsOneWidget);
      expect(find.text(en.taskMarkedDone), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Undo says so in the sheet and leaves the task done', (
      tester,
    ) async {
      final failure = data.tasks.beforeWrite;
      data.tasks.beforeWrite = null;
      await openDetail(tester, 'Bare task');
      await tester.tap(
        inSheet(find.widgetWithText(FilledButton, en.taskDetailMarkDone)),
      );
      await tester.pumpAndSettle();
      data.tasks.beforeWrite = failure;

      await tester.tap(inSheet(find.text(en.undo)));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['setDone 2 true', 'undoDone 2']);
      expect(data.tasks.find(2)!.done, isTrue);
      expect(inSheet(find.text(en.localChangeFailed)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Delete keeps the sheet open and says so', (tester) async {
      await openDetail(tester, 'Bare task');

      await openMenu(tester, en.moreActions);
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.taskDeleteDialogConfirm));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailSheet), findsOneWidget);
      expect(inSheet(find.text(en.localChangeFailed)), findsOneWidget);
      expect(find.text(en.taskDeleted), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the star says so', (tester) async {
      await openDetail(tester, 'Bare task');

      await tester.tap(inSheet(find.byTooltip(en.taskAddFavourite)));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.localChangeFailed)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the star toggles the favourite from the sheet', (tester) async {
    await openDetail(tester, 'Bare task');

    await tester.tap(inSheet(find.byTooltip(en.taskAddFavourite)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['setFavorite 2 true']);
    expect(inSheet(find.byTooltip(en.taskRemoveFavourite)), findsOneWidget);
    expect(data.tasks.find(2)?.isFavorite, isTrue);
  });

  testWidgets('Delete asks first, then closes the sheet and confirms', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');

    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();

    expect(find.text(en.taskDeleteDialogTitle), findsOneWidget);
    expect(find.text(en.taskDeleteDialogBody('Bare task')), findsOneWidget);
    expect(data.tasks.writes, isEmpty);

    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(data.tasks.writes, ['delete 2']);
    expect(find.text(en.taskDeleted), findsOneWidget);
    expect(find.text('Bare task'), findsNothing);
    expect(find.text('Quarterly report'), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the task and the sheet', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');

    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskDeleteDialogCancel));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(data.tasks.writes, isEmpty);
    expect(find.text(en.taskDeleted), findsNothing);
  });

  testWidgets('a task a sync removed while the sheet is open offers no '
      'change: Done, Edit, the star, relations and Delete are off', (
    tester,
  ) async {
    await openDetail(tester, 'Quarterly report');
    data.tasks.all = [sampleTask(id: 2, title: 'Bare task')];
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);
    final done = inSheet(
      find.widgetWithText(FilledButton, en.taskDetailMarkDone),
    );
    expect(tester.widget<FilledButton>(done).onPressed, isNull);
    IconButton button(String tooltip) => tester.widget<IconButton>(
      find.ancestor(
        of: inSheet(find.byTooltip(tooltip)),
        matching: find.byType(IconButton),
      ),
    );
    expect(button(en.taskEdit).onPressed, isNull);
    expect(button(en.taskRemoveFavourite).onPressed, isNull);
    expect(inSheet(find.text(en.taskDetailAddRelation)), findsNothing);
    if (inSheet(find.byTooltip(en.moreActions)).evaluate().isNotEmpty) {
      await openMenu(tester, en.moreActions);
    }
    expect(find.text(en.taskDelete), findsNothing);
    expect(find.text(en.taskDuplicate), findsNothing);
    expect(data.tasks.writes, isEmpty);
  });

  testWidgets('a delete confirmed after the task went says so, keeps the '
      'sheet and claims no delete', (tester) async {
    await openDetail(tester, 'Bare task');
    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    data.tasks.deletion = TaskDeletion.none;

    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailSheet), findsOneWidget);
    expect(inSheet(find.text(en.taskDeleteGone)), findsOneWidget);
    expect(find.text(en.taskDeleted), findsNothing);
    expect(find.text(en.undo), findsNothing);
  });

  testWidgets('the delete dialog marks the destructive action on Android', (
    tester,
  ) async {
    await openDetail(tester, 'Bare task');
    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();

    final confirmFinder = find.widgetWithText(
      TextButton,
      en.taskDeleteDialogConfirm,
    );
    final confirm = tester.widget<TextButton>(confirmFinder);
    expect(
      confirm.style?.foregroundColor?.resolve({}),
      Theme.of(tester.element(confirmFinder)).colorScheme.error,
    );
  });

  testWidgets('the delete dialog is a Cupertino alert on iOS', (tester) async {
    await openDetail(tester, 'Bare task');
    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    final confirm = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, en.taskDeleteDialogConfirm),
    );
    expect(confirm.isDestructiveAction, isTrue);

    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailSheet), findsNothing);
    expect(data.tasks.writes, ['delete 2']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a queued change is marked in the sheet', (tester) async {
    data.tasks.pendingTaskIds = {2};
    await openDetail(tester, 'Bare task');

    expect(inSheet(find.text(en.taskNotYetSynced)), findsOneWidget);
  });

  testWidgets('at 200 % text scale in dark mode the controls still work', (
    tester,
  ) async {
    useAccessibilityExtremes(tester);
    data.tasks.pendingTaskIds = {1};
    await openDetail(tester, 'Quarterly report');

    await tester.ensureVisible(inSheet(find.text(en.taskDetailMarkDone)));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text(en.taskDetailMarkDone)));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['setDone 1 true']);
    await openMenu(tester, en.moreActions);
    expect(find.text(en.taskDelete), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    await openDetail(tester, 'Bare task');

    expect(inSheet(find.text(de.taskDetailStatusOpen)), findsOneWidget);
    expect(inSheet(find.text(de.taskDetailMarkDone)), findsOneWidget);
    expect(inSheet(find.byTooltip(de.taskAddFavourite)), findsOneWidget);
    await openMenu(tester, de.moreActions);
    await tester.tap(find.text(de.taskDelete));
    await tester.pumpAndSettle();
    expect(find.text(de.taskDeleteDialogTitle), findsOneWidget);
    expect(find.text(de.taskDeleteDialogBody('Bare task')), findsOneWidget);
  });

  group('on a server with the bin', () {
    Future<void> deleteFromSheet(WidgetTester tester, String title) async {
      await openDetail(tester, title, connection: fullServer280());
      await openMenu(tester, en.moreActions);
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text(en.taskDeleteDialogConfirm));
      await tester.pumpAndSettle();
    }

    SnackBar snackBar(WidgetTester tester) =>
        tester.widget(find.byType(SnackBar));

    testWidgets('the dialog says the task moves to the bin; once deleted, '
        'the snackbar says so and offers Undo', (tester) async {
      await deleteFromSheet(tester, 'Bare task');

      expect(find.text(en.taskDeleteDialogTitle), findsOneWidget);
      expect(
        find.text(en.taskDeleteDialogBodyTrash('Bare task')),
        findsOneWidget,
      );
      expect(find.text(en.taskDeleteDialogBody('Bare task')), findsNothing);

      await confirm(tester);

      expect(find.byType(TaskDetailSheet), findsNothing);
      expect(data.tasks.writes, ['delete 2']);
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      expect(find.text(en.taskDeleted), findsNothing);
      expect(find.text(en.undo), findsOneWidget);
      expect(find.text('Bare task'), findsNothing);
    });

    testWidgets('Undo restores the task and says so', (tester) async {
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['delete 2', 'restore 2']);
      expect(find.text(en.taskRestored), findsOneWidget);
      expect(find.text(en.taskMovedToTrash), findsNothing);
      expect(find.text('Bare task'), findsOneWidget);
    });

    testWidgets('an Undo that fails says why and leaves the task deleted', (
      tester,
    ) async {
      data.tasks.restoreFailure = const DomainError(412, code: 3008);
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['delete 2', 'restore 2']);
      expect(find.text(en.trashRestoreArchived), findsOneWidget);
      expect(find.text(en.taskRestored), findsNothing);
      expect(find.text('Bare task'), findsNothing);
    });

    testWidgets('a task discarded at once is deleted, without Undo', (
      tester,
    ) async {
      data.tasks.deletion = TaskDeletion.discarded;
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      expect(data.tasks.writes, ['delete 2']);
      expect(find.text(en.taskDeleted), findsOneWidget);
      expect(find.text(en.taskMovedToTrash), findsNothing);
      expect(find.text(en.undo), findsNothing);
    });

    testWidgets('under a screen reader "Task deleted" without Undo still '
        'goes, as nothing else would close it', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            supportsAnnounce: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      data.tasks.deletion = TaskDeletion.discarded;
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      expect(find.text(en.taskDeleted), findsOneWidget);
      expect(snackBar(tester).persist, isFalse);
      await tester.pump(deletedSnackBarDuration + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(en.taskDeleted), findsNothing);
    });

    testWidgets('a task that never reached the server is deleted, not moved '
        'to the bin, and Undo still takes it back', (tester) async {
      data.tasks.all = [...data.tasks.all, sampleTask(id: -3, title: 'Draft')];
      await deleteFromSheet(tester, 'Draft');

      expect(find.text(en.taskDeleteDialogBodyUnsent('Draft')), findsOneWidget);
      expect(find.text(en.taskDeleteDialogBodyTrash('Draft')), findsNothing);
      await confirm(tester);

      expect(data.tasks.writes, ['delete -3']);
      expect(find.text(en.taskDeleted), findsOneWidget);
      expect(find.text(en.taskMovedToTrash), findsNothing);

      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();

      expect(data.tasks.writes, ['delete -3', 'restore -3']);
      expect(find.text(en.taskRestored), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('a task whose create was sent without an answer is not '
        'promised to stay out of the trash', (tester) async {
      data.tasks.all = [...data.tasks.all, sampleTask(id: -3, title: 'Draft')];
      data.tasks.onServer[-3] = TaskOnServer.maybe;
      await deleteFromSheet(tester, 'Draft');

      expect(
        find.text(en.taskDeleteDialogBodyUnconfirmed('Draft')),
        findsOneWidget,
      );
      expect(find.text(en.taskDeleteDialogBodyUnsent('Draft')), findsNothing);
      await confirm(tester);

      expect(data.tasks.writes, ['delete -3']);
    });

    testWidgets('a create that cannot be read is not promised to stay out of '
        'the trash either', (tester) async {
      data.tasks.all = [...data.tasks.all, sampleTask(id: -3, title: 'Draft')];
      data.tasks.onServerFailure = StateError('outbox unreadable');
      await deleteFromSheet(tester, 'Draft');

      expect(
        find.text(en.taskDeleteDialogBodyUnconfirmed('Draft')),
        findsOneWidget,
      );
      expect(find.text(en.taskDeleteDialogBodyUnsent('Draft')), findsNothing);
    });

    testWidgets('the snackbar goes after 10 s', (tester) async {
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      expect(snackBar(tester).duration, deletedSnackBarDuration);
      expect(snackBar(tester).persist, isFalse);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text(en.undo), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(en.taskMovedToTrash), findsNothing);
    });

    testWidgets('a switch from outside takes the Undo away, which would '
        'restore the task in the previous account', (tester) async {
      final auth = AuthFakes();
      final bob = await auth.seedAccount(
        oauthServer230(),
        tokens: issueTokens(issuedAt: now, userId: 8, username: 'bob'),
        activate: false,
      );
      data.accounts[bob.id] = AccountDataFakes(now: now);
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      await pumpSignedInApp(
        tester,
        sync: data,
        auth: auth,
        now: now,
        connection: fullServer280(),
      );
      await tester.tap(find.text('Bare task'));
      await tester.pumpAndSettle();
      await openMenu(tester, en.moreActions);
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(find.text(en.taskMovedToTrash), findsOneWidget);

      final switched = containerOf(tester)
          .read(taskOpenerProvider)
          .activate(bob.id);
      await tester.pumpAndSettle();

      expect(await switched, isTrue);
      expect(find.text(en.taskMovedToTrash), findsNothing);
      expect(find.text(en.undo), findsNothing);
    });

    testWidgets('under a screen reader the snackbar waits for the user', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            accessibleNavigation: true,
            supportsAnnounce: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await deleteFromSheet(tester, 'Bare task');
      await confirm(tester);

      await tester.pump(deletedSnackBarDuration * 3);
      await tester.pumpAndSettle();

      expect(snackBar(tester).persist, isTrue);
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['delete 2', 'restore 2']);
    });

    testWidgets('a write guest is not pointed to the bin page and gets Undo', (
      tester,
    ) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      data.projects.all = [];
      data.tasks.all = [
        sampleTask(id: 2, title: 'Bare task', projectId: guestProjectId),
      ];
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: data,
        permission: Permission.write,
        connection: fullServer280(),
      );
      await tester.tap(find.text('Bare task'));
      await tester.pumpAndSettle();
      await openMenu(tester, en.moreActions);
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();

      expect(
        find.text(en.taskDeleteDialogBodyTrashGuest('Bare task')),
        findsOneWidget,
      );
      expect(
        find.text(en.taskDeleteDialogBodyTrash('Bare task')),
        findsNothing,
      );

      await confirm(tester);
      expect(find.text(en.taskMovedToTrash), findsOneWidget);
      await tester.tap(find.text(en.undo));
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['delete 2', 'restore 2']);
      expect(find.text(en.taskRestored), findsOneWidget);
    });

    testWidgets('a write guest is told the same of a task that never '
        'reached the server', (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      data.projects.all = [];
      data.tasks.all = [
        sampleTask(id: -3, title: 'Draft', projectId: guestProjectId),
      ];
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: data,
        permission: Permission.write,
        connection: fullServer280(),
      );
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      await openMenu(tester, en.moreActions);
      await tester.tap(find.text(en.taskDelete));
      await tester.pumpAndSettle();

      expect(find.text(en.taskDeleteDialogBodyUnsent('Draft')), findsOneWidget);
      expect(
        find.text(en.taskDeleteDialogBodyTrashGuest('Draft')),
        findsNothing,
      );
    });

    testWidgets('is in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await openDetail(tester, 'Bare task', connection: fullServer280());
      await openMenu(tester, de.moreActions);
      await tester.tap(find.text(de.taskDelete));
      await tester.pumpAndSettle();

      expect(
        find.text(de.taskDeleteDialogBodyTrash('Bare task')),
        findsOneWidget,
      );
      await tester.tap(find.text(de.taskDeleteDialogConfirm));
      await tester.pumpAndSettle();
      expect(find.text(de.taskMovedToTrash), findsOneWidget);
      expect(find.text(de.undo), findsOneWidget);
    });
  });

  testWidgets('without the bin a delete has no Undo', (tester) async {
    await openDetail(tester, 'Bare task');
    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.text(en.taskDeleted), findsOneWidget);
    expect(find.text(en.undo), findsNothing);
  });

  testWidgets('without the bin "Task deleted" is a plain snackbar: it waits '
      'for one still up and goes after the usual 4 s, also under a screen '
      'reader', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          supportsAnnounce: true,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openDetail(tester, 'Bare task');
    await openMenu(tester, en.moreActions);
    await tester.tap(find.text(en.taskDelete));
    await tester.pumpAndSettle();
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .showSnackBar(const SnackBar(content: Text('Earlier')));
    await tester.tap(find.text(en.taskDeleteDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Earlier'), findsOneWidget);
    expect(find.text(en.taskDeleted), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text(en.taskDeleted), findsOneWidget);
    final shown = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(shown.duration, const SnackBar(content: SizedBox()).duration);
    expect(shown.persist, isFalse);
    expect(shown.action, isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text(en.taskDeleted), findsNothing);
  });
}
