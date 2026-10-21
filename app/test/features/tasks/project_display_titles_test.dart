import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/new_task_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../quick_add/presentation/composer_harness.dart';
import 'edit_page_harness.dart';

/// The server's default project names in the user's language where the
/// task screens show a project; quick add still matches the server's.
void main() {
  final now = DateTime(2026, 10, 12, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Inbox'),
      sampleProject(id: 2, title: 'Work', identifier: 'WORK'),
    ];
    data.tasks.all = [
      sampleTask(id: 1, title: 'Call mom', due: DateTime(2026, 10, 13, 9)),
    ];
  });

  testWidgets('the rows, the sheet and its breadcrumb', (tester) async {
    useLocale(tester, const Locale('de'));
    usePhoneSurface(tester, logicalSize: const Size(360, 1600));
    await pumpSignedInApp(tester, sync: data, now: now);

    expect(find.textContaining('Eingang'), findsOneWidget);
    expect(find.textContaining('Inbox'), findsNothing);

    await openTab(tester, de.tabUpcoming);
    expect(find.textContaining('Eingang'), findsOneWidget);

    await tester.tap(find.text('Call mom'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TaskDetailSheet),
        matching: find.text('Eingang'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the edit page and its project picker', (tester) async {
    useLocale(tester, const Locale('de'));
    await openEditPageWith(tester, data: data, taskId: 1, now: now);

    expect(find.text('Eingang'), findsOneWidget);
    await tapVisible(tester, find.text('Eingang'));
    expect(find.text(de.taskEditProjectPickerTitle), findsOneWidget);
    expect(find.text('Eingang'), findsNWidgets(2));
    expect(find.text('Inbox'), findsNothing);
  });

  testWidgets('the new-task sheet and the quick add preview, which still '
      'match the server title', (tester) async {
    useLocale(tester, const Locale('de'));
    final harness = ComposerHarness();
    await harness.open(tester);

    Finder projectField(String title) => find.descendant(
      of: find.byType(NewTaskSheet),
      matching: find.ancestor(
        of: find.text(title),
        matching: find.byType(ProjectField),
      ),
    );
    expect(projectField('Eingang'), findsOneWidget);

    await typeLine(tester, 'Buy milk +Inbox');
    await tester.pumpAndSettle();
    expect(find.text(de.quickAddProjectNotFound('Inbox')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NewTaskSheet),
        matching: find.text('Eingang'),
      ),
      findsNWidgets(2),
    );

    await typeLine(tester, 'Buy milk +Eingang');
    await tester.pumpAndSettle();
    expect(find.text(de.quickAddProjectNotFound('Eingang')), findsOneWidget);
  });
}
