import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class MockProjectsController extends ProjectsController {
  final ProjectListModel model;
  MockProjectsController(this.model);

  @override
  Future<ProjectListModel> build() async => model;
}

void main() {
  testWidgets('ProjectListPage displays projects and grouped subprojects', (
    WidgetTester tester,
  ) async {
    final subproject = Project(
      id: 2,
      title: 'Subproject 1',
      parentProjectId: 1,
    );
    final parentProject = Project(
      id: 1,
      title: 'Parent Project',
      parentProjectId: 0,
    );
    parentProject.subprojects = [subproject];

    final projects = [parentProject];
    final model = ProjectListModel(projects);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsControllerProvider.overrideWith(
            () => MockProjectsController(model),
          ),
        ],
        child: const MaterialApp(
          home: ProjectListPage(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
        ),
      ),
    );

    // Initial load
    await tester.pump();

    // Verify parent project is displayed
    expect(find.text('Parent Project'), findsOneWidget);

    // Verify expansion tile is used
    expect(find.byType(VikunjaExpansionTile), findsOneWidget);

    // Tap the expansion icon to ensure it opens and subproject is visible
    await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
    await tester.pump();

    expect(find.text('Subproject 1'), findsOneWidget);
  });
}
