import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import 'edit_page_harness.dart';

// Vikunja 2.8.0 takes a title of at most 1000 code points and at most 100
// reminders, checking each only when it changes or grows.
void main() {
  final now = DateTime(2026, 10, 10, 12);
  const max = Task.maxTitleLength;
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Work')];
  });

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  group('edit page', () {
    Finder titleField() => field(en.taskEditTitleLabel);

    testWidgets('a stored longer title is kept whole while other fields '
        'change', (tester) async {
      final long = 'a' * (max + 200);
      data.tasks.all = [sampleTask(id: 1, title: long)];
      await openEditPageWith(
        tester,
        data: data,
        taskId: 1,
        now: now,
        size: const Size(360, 5000),
      );

      expect(fieldText(tester, en.taskEditTitleLabel), long);
      await tester.tap(find.text(en.priorityUrgent));
      await tester.pumpAndSettle();
      expect(editSaveEnabled(tester), isTrue);
      await saveEdits(tester);

      expect(data.tasks.updates, [(1, const TaskChanges(priority: 4))]);
    });

    testWidgets('a stored longer title can only shrink, and saves once it '
        'fits', (tester) async {
      final long = 'a' * (max + 200);
      data.tasks.all = [sampleTask(id: 1, title: long)];
      await openEditPageWith(tester, data: data, taskId: 1, now: now);

      await tester.enterText(titleField(), '$long more');
      await tester.pumpAndSettle();
      expect(fieldText(tester, en.taskEditTitleLabel), long);
      expect(editSaveEnabled(tester), isFalse);

      await tester.enterText(titleField(), 'a' * (max + 1));
      await tester.pumpAndSettle();
      expect(find.text('${max + 1}/$max'), findsOneWidget);
      expect(editSaveEnabled(tester), isFalse);

      await tester.enterText(titleField(), 'a' * max);
      await tester.pumpAndSettle();
      expect(find.text('$max/$max'), findsOneWidget);
      expect(editSaveEnabled(tester), isTrue);
      await saveEdits(tester);
      expect(data.tasks.updates, [(1, TaskChanges(title: 'a' * max))]);
    });

    testWidgets('a title cannot grow past the limit, counted in code points', (
      tester,
    ) async {
      data.tasks.all = [sampleTask(id: 1, title: 'Report')];
      await openEditPageWith(tester, data: data, taskId: 1, now: now);
      expect(find.text('6/$max'), findsNothing);

      await tester.enterText(titleField(), '😀' * (max + 1));
      await tester.pumpAndSettle();

      expect(fieldText(tester, en.taskEditTitleLabel), '😀' * max);
      expect(find.text('$max/$max'), findsOneWidget);
      expect(editSaveEnabled(tester), isTrue);
    });

    testWidgets('adding a reminder stops at the limit', (tester) async {
      data.tasks.all = [
        sampleTask(
          id: 1,
          title: 'Report',
          reminders: [
            for (var i = 0; i < Task.maxReminders; i++)
              TaskReminder(
                reminder: DateTime.utc(2026, 11, 2).add(Duration(hours: i)),
              ),
          ],
        ),
      ];
      await openEditPageWith(
        tester,
        data: data,
        taskId: 1,
        now: now,
        size: const Size(360, 9000),
      );
      ActionChip addChip() => tester.widget<ActionChip>(
        find.widgetWithText(ActionChip, en.taskEditAddReminder),
      );

      expect(addChip().onPressed, isNull);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      expect(addChip().onPressed, isNotNull);
    });
  });

  testWidgets('the subtask field takes a title up to the limit', (
    tester,
  ) async {
    data.tasks.all = [sampleTask(id: 1, title: 'Plan the trip')];
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
    await pumpSignedInApp(tester, sync: data, now: now);
    await tester.tap(find.text('Plan the trip').first);
    await tester.pumpAndSettle();
    final subtask = find.descendant(
      of: find.byType(TaskDetailSheet),
      matching: field(en.taskDetailAddSubtask),
    );

    await tester.ensureVisible(subtask);
    await tester.enterText(subtask, 'b' * (max + 5));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(subtask).controller!.text, 'b' * max);
  });

  group('share sheet', () {
    Finder inSheet(Finder matching) =>
        find.descendant(of: find.byType(ShareSheet), matching: matching);

    testWidgets('a shared first line over the limit is cut, its rest starts '
        'the description, and the title field takes no more', (tester) async {
      final line = 'word ' * 250;
      data.shareSource.push(IncomingShare(text: '$line\nsecond line'));
      await pumpSignedInApp(tester, sync: data);

      final title = ('word ' * 200).trim();
      final rest = ('word ' * 50).trim();
      expect(fieldText(tester, en.taskEditTitleLabel), title);
      expect(fieldText(tester, en.taskDetailDescription), '$rest\nsecond line');

      await tester.enterText(
        inSheet(field(en.taskEditTitleLabel)),
        '$title and more',
      );
      await tester.pumpAndSettle();
      expect(
        fieldText(tester, en.taskEditTitleLabel).runes.length,
        lessThanOrEqualTo(max),
      );
      await tester.enterText(inSheet(field(en.taskEditTitleLabel)), title);
      await tester.pumpAndSettle();

      await tester.tap(
        inSheet(find.widgetWithText(TextButton, en.shareCreate)),
      );
      await tester.pumpAndSettle();

      expect(data.tasks.creates.single.title, title);
      expect(
        data.tasks.creates.single.description,
        '<p>$rest<br>second line</p>',
      );
    });
  });
}
