import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class MockProjectController extends ProjectController {
  final ProjectPageModel model;
  MockProjectController(this.model);

  @override
  Future<ProjectPageModel> build(Project project) async => model;
}

void main() {
  testWidgets('ProjectTaskList displays subprojects and tasks sections', (
    WidgetTester tester,
  ) async {
    final user = User(username: 'testuser');
    final subproject = Project(
      id: 2,
      title: 'Subproject A',
      parentProjectId: 1,
    );
    final parentProject = Project(
      id: 1,
      title: 'Parent Project',
      parentProjectId: 0,
    );
    parentProject.subprojects = [subproject];

    final task = Task(id: 101, title: 'Task 1', createdBy: user, projectId: 1);
    final tasks = [task];

    final view = ProjectView(
      DateTime.now(),
      0,
      0,
      1,
      0.0,
      1,
      'List View',
      DateTime.now(),
      null,
      [],
      'manual',
      ViewKind.list,
    );
    parentProject.views = [view];

    final model = ProjectPageModel(parentProject, 0, tasks, [], false, false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectControllerProvider(
            parentProject,
          ).overrideWith(() => MockProjectController(model)),
        ],
        child: MaterialApp(
          home: Scaffold(body: ProjectTaskList(parentProject)),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();

    // Verify sections are displayed (titles from AppLocalizations)
    // In English, these are usually "Subprojects" and "Tasks" or similar.
    // Based on ProjectTaskList code: AppLocalizations.of(context).projectSection and AppLocalizations.of(context).tasksSection

    // We can also just search for the text if we know it, or find by type and check content
    expect(find.text('Subproject A'), findsOneWidget);
    expect(find.text('Task 1'), findsOneWidget);

    // Check for section headers (bold text)
    // We expect "Projects" and "Tasks" based on Vikunja's typical English l10n
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
  });
}
