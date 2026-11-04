import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

void main() {
  testWidgets('allows selecting a project when creating a task', (
    tester,
  ) async {
    int? selectedProjectId;
    int? selectedPriority;
    DateTime? selectedDueDate;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AddTaskDialog(
            projects: [
              Project(id: 1, title: 'Personal'),
              Project(id: 2, title: 'Work'),
            ],
            initialProjectId: 1,
            onAddTask: (title, dueDate, projectId, priority) {
              selectedProjectId = projectId;
              selectedPriority = priority;
              selectedDueDate = dueDate;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Prepare report');

    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();

    final priorityIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('priority-icon-3')),
    );
    expect(priorityIcon.color, Colors.red);

    await tester.tap(find.text('Add'));

    expect(selectedProjectId, 2);
    expect(selectedPriority, 3);
    expect(selectedDueDate, isNotNull);
  });
}
