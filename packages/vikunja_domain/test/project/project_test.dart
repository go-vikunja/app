import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Project _project(int id, {int parentProjectId = 0}) =>
    Project(id: id, title: 'p', parentProjectId: parentProjectId);

void main() {
  test('a project without parent is top level', () {
    expect(_project(3).isTopLevel, isTrue);
    expect(_project(3, parentProjectId: 1).isTopLevel, isFalse);
  });

  group('pseudo projects', () {
    test('negative ids are pseudo projects', () {
      expect(_project(-1).isPseudo, isTrue);
      expect(_project(-2).isPseudo, isTrue);
      expect(_project(0).isPseudo, isFalse);
      expect(_project(5).isPseudo, isFalse);
    });

    test('-1 is the Favorites project', () {
      expect(Project.favoritesId, -1);
      expect(_project(-1).isFavoritesPseudo, isTrue);
      expect(_project(-2).isFavoritesPseudo, isFalse);
      expect(_project(1).isFavoritesPseudo, isFalse);
    });

    test('saved filter n is project -n - 1', () {
      expect(_project(-2).savedFilterId, 1);
      expect(_project(-10).savedFilterId, 9);
      expect(_project(-1).savedFilterId, isNull);
      expect(_project(4).savedFilterId, isNull);
    });
  });

  group('views', () {
    test('kinds and bucket modes come from wire names', () {
      expect(ProjectViewKind.fromWire('kanban'), ProjectViewKind.kanban);
      expect(ProjectViewKind.fromWire('timeline'), isNull);
      expect(
        BucketConfigurationMode.fromWire('manual'),
        BucketConfigurationMode.manual,
      );
      expect(
        BucketConfigurationMode.fromWire('x'),
        BucketConfigurationMode.none,
      );
    });

    test('views are identified by id and project', () {
      const a = ProjectView(
        id: 1,
        projectId: 2,
        title: 'List',
        kind: ProjectViewKind.list,
      );
      const b = ProjectView(
        id: 1,
        projectId: 2,
        title: 'Other',
        kind: ProjectViewKind.table,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const ProjectView(
            id: 1,
            projectId: 3,
            title: 'List',
            kind: ProjectViewKind.list,
          ),
        ),
      );
    });
  });

  test('equality ignores owner and views', () {
    const owner = User(id: 1, username: 'u');
    const view = ProjectView(
      id: 1,
      projectId: 1,
      title: 'List',
      kind: ProjectViewKind.list,
    );

    expect(
      const Project(id: 1, title: 'p', owner: owner, views: [view]),
      const Project(id: 1, title: 'p'),
    );
    expect(
      const Project(id: 1, title: 'p'),
      isNot(const Project(id: 1, title: 'q')),
    );
  });
}
