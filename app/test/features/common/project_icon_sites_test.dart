import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/legible_color.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/default_project_picker.dart';
import 'package:vikunja_mobile/features/common/presentation/project_icon.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/parent_picker.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_row.dart';
import 'package:vikunja_mobile/features/tasks/presentation/create/project_field.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/project_breadcrumb.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/color_row.dart';
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

  testWidgets('a colour too close to what it is drawn on gets lighter or '
      'darker until it stands out by 3:1; colour pickers keep the stored '
      'colour', (tester) async {
    const purple = Color(0xFF6A1B9A);
    const yellow = Color(0xFFF0E442);
    final reading = sampleProject(id: 4, title: 'Reading', hexColor: '6a1b9a');
    final garden = sampleProject(id: 5, title: 'Garden', hexColor: 'f0e442');
    for (final (theme, stays, changes) in [
      (AppTheme.dark(), yellow, purple),
      (AppTheme.light(), purple, yellow),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [activeAccountIdProvider.overrideWithValue(null)],
          child: MaterialApp(
            theme: theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: appSupportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  SectionCard(
                    children: [
                      ProjectRow(project: reading, onTap: () {}),
                      ProjectRow(project: garden, onTap: () {}),
                    ],
                  ),
                  const ColorDot(color: purple),
                  const ColorDot(color: yellow),
                  ColorRow(
                    value: '6a1b9a',
                    original: 'f0e442',
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final colors = theme.colorScheme;
      final drawn = marks(tester);
      final stayed = drawn[stays == purple ? 0 : 1]!;
      final changed = drawn[stays == purple ? 1 : 0]!;
      expect(stayed, stays);
      expect(changed, isNot(changes));
      expect(
        contrastRatio(changed, colors.surfaceContainerLow),
        greaterThanOrEqualTo(3),
      );
      final dots = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ColorDot),
            matching: find.byType(DecoratedBox),
          ),
        ))
          (box.decoration as BoxDecoration).color,
      ];
      expect(dots[stays == purple ? 0 : 1], stays);
      expect(
        contrastRatio(dots[stays == purple ? 1 : 0]!, colors.surface),
        greaterThanOrEqualTo(3),
      );
      final swatches = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ColorRow),
            matching: find.byType(DecoratedBox),
          ),
        ))
          if (box.decoration case BoxDecoration(:final color?)) color,
      ];
      expect(swatches, containsAll([purple, yellow]));
    }
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
    // Compact density would shrink the chip to 40 dp, and the tap-target
    // guideline skips it as a link.
    for (final chip in find.byType(ActionChip).evaluate()) {
      final size = tester.getSize(find.byWidget(chip.widget));
      expect(size.height, greaterThanOrEqualTo(48), reason: '$size');
    }
  });

  testWidgets("the new task's project field, also while the text names the "
      'project', (tester) async {
    final colors = await pump(
      tester,
      Column(
        children: [
          ProjectField(title: 'Work', hexColor: '1973ff', onPressed: () {}),
          ProjectField(title: 'Home', onPressed: () {}),
          const ProjectField(
            title: 'Work',
            hexColor: '1973ff',
            onPressed: null,
            note: 'Set in the title',
          ),
        ],
      ),
    );

    expect(marks(tester), [blue, colors.onSurfaceVariant, blue]);
    expect(find.byType(ColorDot), findsNothing);
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
