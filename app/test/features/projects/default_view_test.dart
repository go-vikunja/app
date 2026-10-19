import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/project_list_model.dart';

/// `frontend_settings.default_view` in the view resolution, with the web's
/// vectors (`ProjectView.vue`).
void main() {
  ProjectView view(int id, ProjectViewKind kind, {int? position}) =>
      ProjectView(
        id: id,
        projectId: 1,
        title: kind.wireName,
        kind: kind,
        position: (position ?? id).toDouble(),
      );

  final webViews = [
    view(1, ProjectViewKind.list),
    view(2, ProjectViewKind.gantt),
    view(3, ProjectViewKind.table),
    view(4, ProjectViewKind.kanban),
  ];

  group("the web's vectors", () {
    test('no default kind (first) opens the first view', () {
      expect(resolveViewId(webViews, remembered: null), 1);
    });

    test('a default kind opens its first view', () {
      expect(
        resolveViewId(
          webViews,
          remembered: null,
          defaultKind: ProjectViewKind.kanban,
        ),
        4,
      );
    });

    test('the remembered view comes first', () {
      expect(
        resolveViewId(
          webViews,
          remembered: 3,
          defaultKind: ProjectViewKind.kanban,
        ),
        3,
      );
    });

    test('a remembered view that is gone falls back to the default kind', () {
      expect(
        resolveViewId(
          webViews,
          remembered: 99,
          defaultKind: ProjectViewKind.table,
        ),
        3,
      );
    });

    test('a kind the project lacks opens the first view', () {
      final favorites = [
        view(-1, ProjectViewKind.list, position: 1),
        view(-2, ProjectViewKind.gantt, position: 2),
        view(-3, ProjectViewKind.table, position: 3),
      ];
      expect(
        resolveViewId(
          favorites,
          remembered: null,
          defaultKind: ProjectViewKind.kanban,
        ),
        -1,
      );
    });

    test('without views there is nothing to open', () {
      expect(
        resolveViewId(
          const [],
          remembered: null,
          defaultKind: ProjectViewKind.list,
        ),
        0,
      );
    });
  });

  group('the app shows list views only', () {
    final project = Project(
      id: 1,
      title: 'Work',
      views: [
        view(10, ProjectViewKind.kanban, position: 1),
        view(11, ProjectViewKind.list, position: 2),
        view(12, ProjectViewKind.table, position: 3),
        view(13, ProjectViewKind.list, position: 4),
      ],
    );
    final listViews = listViewsOf(project);

    for (final kind in [null, ...ProjectViewKind.values]) {
      test('default ${kind?.wireName ?? 'first'} opens the first list view, '
          'the remembered one while it exists', () {
        expect(
          resolveViewId(listViews, remembered: null, defaultKind: kind),
          11,
        );
        expect(resolveViewId(listViews, remembered: 13, defaultKind: kind), 13);
        expect(resolveViewId(listViews, remembered: 12, defaultKind: kind), 11);
      });
    }
  });
}
