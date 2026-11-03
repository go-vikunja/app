import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/real_fonts.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  var robotoLoaded = false;
  setUpAll(() async => robotoLoaded = await loadRoboto());

  final now = DateTime(2026, 10, 10, 12);

  for (final locale in const [Locale('en'), Locale('de')]) {
    final l10n = locale.languageCode == 'de' ? de : en;
    for (final bold in const [false, true]) {
      testWidgets('every name of the attribute card stays on one line beside '
          'its value on a 360 dp phone in ${locale.languageCode}'
          '${bold ? ' with bold text' : ''}', (tester) async {
        if (!robotoLoaded) {
          markTestSkipped("the Flutter SDK's Roboto is needed to measure");
          return;
        }
        if (bold) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(boldText: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final data = SyncFakes(now: now);
        data.projects.all = [sampleProject(id: 1, title: 'Work')];
        data.tasks.all = [
          sampleTask(
            id: 1,
            title: 'Quarterly report',
            due: DateTime(2026, 10, 12, 9, 30),
            start: DateTime(2026, 10, 11, 8),
            end: DateTime(2026, 10, 13, 17),
            priority: TaskPriority.high,
            percentDone: 0.5,
            labels: [sampleLabel(id: 1, title: 'Finance')],
            assignees: const [User(id: 7, username: 'alice', name: 'Alice')],
            reminders: const [
              TaskReminder(
                relativePeriod: Duration(hours: -1),
                relativeTo: ReminderRelativeTo.dueDate,
              ),
            ],
            repeatAfter: const Duration(days: 14),
          ),
        ];
        useLocale(tester, locale);
        usePhoneSurface(tester, logicalSize: const Size(360, 2200));
        await pumpSignedInApp(tester, sync: data, now: now);
        await tester.tap(find.text('Quarterly report'));
        await tester.pumpAndSettle();

        Finder inSheet(String text) => find.descendant(
          of: find.byType(TaskDetailSheet),
          matching: find.text(text),
        );
        for (final label in [
          l10n.taskDetailDueDateRow,
          l10n.taskDetailStartDate,
          l10n.taskDetailEndDate,
          l10n.taskDetailPriority,
          l10n.taskDetailProgress,
          l10n.taskDetailRepeat,
          l10n.taskDetailReminders,
          l10n.taskDetailLabels,
          l10n.taskDetailAssignees,
        ]) {
          final name = tester.renderObject<RenderParagraph>(inSheet(label));
          expect(
            name.size.height,
            name.getMinIntrinsicHeight(double.infinity),
            reason: label,
          );
        }
        for (final (label, value) in [
          (l10n.taskDetailAssignees, 'Alice'),
          (l10n.taskDetailPriority, l10n.priorityHigh),
        ]) {
          final name = tester.getRect(inSheet(label));
          final shown = tester.getRect(inSheet(value));
          expect(shown.left, greaterThan(name.right), reason: label);
          expect(shown.center.dy, closeTo(name.center.dy, 1), reason: label);
        }
      });
    }
  }
}
