import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/project_moves.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

import '../../helpers/sample_data.dart';

void main() {
  final projects = [
    sampleProject(id: 1, title: 'Work', position: 200),
    sampleProject(id: 2, title: 'Home', position: 100),
    sampleProject(id: 3, title: 'Reports', parent: 1, position: 20),
    sampleProject(id: 4, title: 'Admin', parent: 1, position: 10),
    sampleProject(id: 5, title: 'Q1', parent: 3, position: 5),
    sampleProject(id: 6, title: 'Old', position: 300, archived: true),
    sampleProject(id: 7, title: 'Under old', parent: 6, position: 1000),
    sampleProject(id: 8, title: 'Shared', parent: 99, position: 150),
  ];

  ProjectTreeMoves movesOf(
    List<Project> projects, {
    bool includeArchived = true,
  }) => ProjectTreeMoves(
    buildProjectTree(projects, includeArchived: includeArchived),
    all: projects,
  );

  final moves = movesOf(projects);

  test('reads the tree as shown', () {
    expect(moves.childrenOf(0).map((project) => project.id), [2, 8, 1, 6]);
    expect(moves.childrenOf(1).map((project) => project.id), [4, 3]);
    expect(moves.shownParentOf(5), 3);
    expect(moves.shownParentOf(8), 0);
    expect(moves.isWithin(5, 1), isTrue);
    expect(moves.isWithin(1, 5), isFalse);
    expect(moves.isArchived(7), isTrue);
    expect(moves.isArchived(3), isFalse);
  });

  group('among its siblings', () {
    test('between its new neighbours, keeping the parent', () {
      expect(
        moves.plan(3, parentId: 1, index: 0),
        const MoveProject(projectId: 3, position: 5, parentProjectId: 1),
      );
      expect(
        moves.plan(2, parentId: 0, index: 2),
        const MoveProject(projectId: 2, position: 250, parentProjectId: 0),
      );
    });

    test('where it is already, it stays', () {
      expect(moves.plan(4, parentId: 1, index: 0), const ProjectStays());
      expect(moves.plan(3, parentId: 1, index: 5), const ProjectStays());
    });

    test('an orphan put on the top level keeps the parent it cannot see', () {
      expect(
        moves.plan(8, parentId: 0, index: 0),
        const MoveProject(projectId: 8, position: 50, parentProjectId: 99),
      );
    });
  });

  group('under another project', () {
    test('as the last subproject', () {
      expect(
        moves.plan(2, parentId: 1, index: 2),
        const MoveProject(
          projectId: 2,
          position: 20 + 65536,
          parentProjectId: 1,
        ),
      );
    });

    test('into a project without subprojects at 2^16', () {
      expect(
        moves.plan(2, parentId: 4, index: 0),
        const MoveProject(projectId: 2, position: 65536, parentProjectId: 4),
      );
    });

    test('out to the top level, right after its parent', () {
      expect(
        moves.plan(3, parentId: 0, index: 3),
        const MoveProject(projectId: 3, position: 250, parentProjectId: 0),
      );
    });
  });

  group('refused', () {
    test('into itself or below itself', () {
      expect(moves.plan(1, parentId: 1, index: 0), const ProjectMoveRefused());
      expect(moves.plan(1, parentId: 3, index: 0), const ProjectMoveRefused());
      expect(moves.plan(1, parentId: 5, index: 0), const ProjectMoveRefused());
    });

    test('an archived project, or one below it, moved or taking one', () {
      expect(moves.plan(6, parentId: 0, index: 0), const ProjectMoveRefused());
      expect(moves.plan(7, parentId: 0, index: 0), const ProjectMoveRefused());
      expect(moves.plan(2, parentId: 6, index: 1), const ProjectMoveRefused());
      expect(moves.plan(2, parentId: 7, index: 0), const ProjectMoveRefused());
    });

    test('a project not shown, or under one not shown', () {
      final hidden = movesOf(projects, includeArchived: false);

      expect(hidden.plan(2, parentId: 6, index: 0), const ProjectMoveRefused());
      expect(
        hidden.plan(42, parentId: 0, index: 0),
        const ProjectMoveRefused(),
      );
    });

    test('a place whose position would fall below 0.1', () {
      final low = movesOf([
        sampleProject(id: 1, title: 'First', position: 0.15),
        sampleProject(id: 2, title: 'Second', position: 5),
      ]);

      expect(low.plan(2, parentId: 0, index: 0), const ProjectMoveRefused());
      expect(
        low.plan(1, parentId: 0, index: 1),
        const MoveProject(
          projectId: 1,
          position: 5 + 65536,
          parentProjectId: 0,
        ),
      );
    });

    test('between neighbours sharing a position unless the title sorts '
        'between theirs', () {
      final tied = movesOf([
        sampleProject(id: 1, title: 'Alpha', position: 100),
        sampleProject(id: 2, title: 'Gamma', position: 100),
        sampleProject(id: 3, title: 'Beta', position: 300),
        sampleProject(id: 4, title: 'Zulu', position: 400),
      ]);

      expect(
        tied.plan(3, parentId: 0, index: 1),
        const MoveProject(projectId: 3, position: 100, parentProjectId: 0),
      );
      expect(tied.plan(4, parentId: 0, index: 1), const ProjectMoveRefused());
    });
  });
}
