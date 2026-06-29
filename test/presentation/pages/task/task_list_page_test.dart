import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class MockTaskPageController extends TaskPageController {
  final TaskPageModel model;
  MockTaskPageController(this.model);

  @override
  Future<TaskPageModel> build() async => model;
}

void main() {
  testWidgets('TaskListPage displays subproject title in task subtitle', (
    WidgetTester tester,
  ) async {
    final user = User(username: 'testuser');
    final subproject = Project(
      id: 2,
      title: 'Subproject A',
      parentProjectId: 1,
    );

    final task = Task(
      id: 101,
      title: 'Task in Subproject',
      createdBy: user,
      projectId: 2,
    );
    task.project = subproject;

    final model = TaskPageModel([task], false, 1, false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskPageControllerProvider.overrideWith(
            () => MockTaskPageController(model),
          ),
        ],
        child: MaterialApp(
          home: const TaskListPage(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();

    // Verify task title is displayed
    expect(find.text('Task in Subproject'), findsOneWidget);

    // Verify subproject title is displayed in the subtitle
    expect(find.text('Subproject A'), findsOneWidget);
  });
}
