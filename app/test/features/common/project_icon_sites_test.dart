import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/default_project_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/parent_picker.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/project_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row_parts.dart';

import '../../helpers/sample_data.dart';

/// Every project shows as a folder in its colour, muted without one.
void main() {
  const blue = Color(0xFF1973FF);
  final work = sampleProject(id: 1, title: 'Work', hexColor: '1973ff');
  final home = sampleProject(id: 2, title: 'Home');

  Future<ColorScheme> pump(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeAccountIdProvider.overrideWithValue(null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
  }

  List<Color?> marks(WidgetTester tester) => [
    for (final icon in tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(ProjectIcon),
        matching: find.byType(Icon),
      ),
    ))
      icon.color,
  ];

  testWidgets('a project row', (tester) async {
    final colors = await pump(
      tester,
      Column(
        children: [
          ProjectRow(project: work, onTap: () {}),
          ProjectRow(project: home, onTap: () {}),
        ],
      ),
    );

    expect(marks(tester), [blue, colors.onSurfaceVariant]);
  });

  testWidgets("the task's project chip", (tester) async {
    final colors = await pump(
      tester,
      Column(
        children: [
          ProjectBreadcrumb(path: [work], onOpen: (_) {}),
          ProjectBreadcrumb(
            path: [
              work,
              sampleProject(id: 3, title: 'Reports', parent: 1),
            ],
            onOpen: (_) {},
          ),
        ],
      ),
    );

    expect(marks(tester), [blue, colors.onSurfaceVariant]);
    expect(find.byType(ColorDot), findsNothing);
  });

  testWidgets("the new task's project field, unless the text names the "
      'project', (tester) async {
    final colors = await pump(
      tester,
      Column(
        children: [
          ProjectField(title: 'Work', hexColor: '1973ff', onPressed: () {}),
          ProjectField(title: 'Home', onPressed: () {}),
          const ProjectField(
            title: 'Garden',
            onPressed: null,
            leading: Icon(Icons.folder_outlined, color: Colors.purple),
          ),
        ],
      ),
    );

    expect(marks(tester), [blue, colors.onSurfaceVariant]);
    expect(find.byType(ColorDot), findsNothing);
    expect(
      tester.widgetList<Icon>(find.byIcon(Icons.folder_outlined)).last.color,
      Colors.purple,
    );
  });

  for (final (name, open) in <(String, void Function(BuildContext))>[
    (
      'the project picker',
      (context) => pickProject(context, projects: [work, home], selectedId: 1),
    ),
    (
      'the parent picker',
      (context) =>
          pickParentProject(context, projects: [work, home], selectedId: 0),
    ),
    (
      'the default project picker',
      (context) =>
          pickDefaultProject(context, projects: [work, home], selectedId: 1),
    ),
  ]) {
    testWidgets(name, (tester) async {
      final colors = await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(marks(tester), unorderedEquals([blue, colors.onSurfaceVariant]));
    });
  }
}
