import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
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

  Future<void> openDetail(WidgetTester tester, String title) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpSignedInApp(tester, sync: data, now: now);
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

  testWidgets('Mark as done marks the task done and the sheet follows the '
      'row, without a snackbar; Mark as not done reopens it', (tester) async {
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
    expect(find.text(en.undo), findsNothing);

    await tester.tap(markNotDone());
    await tester.pumpAndSettle();
    expect(data.tasks.writes.last, 'setDone 2 false');
    expect(markDone(), findsOneWidget);
    expect(inSheet(find.text(en.taskDetailStatusOpen)), findsOneWidget);
    expect(
      inSheet(find.textContaining(en.taskDetailDoneWhen(''))),
      findsNothing,
    );
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
}
