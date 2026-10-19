import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/projects/application/project_tree.dart';

import '../../helpers/sample_data.dart';

void main() {
  final projects = [
    sampleProject(id: 1, title: 'Work', position: 200),
    sampleProject(id: 2, title: 'Home', position: 100, favorite: true),
    sampleProject(id: 3, title: 'b child', parent: 1, position: 10),
    sampleProject(id: 4, title: 'A child', parent: 1, position: 10),
    sampleProject(id: 5, title: 'Old', archived: true),
    sampleProject(id: 6, title: 'Orphan', parent: 99, position: 150),
    sampleProject(id: 7, title: 'Grandchild', parent: 3),
    sampleProject(id: 8, title: 'Archived child', parent: 1, archived: true),
    const Project(
      id: Project.favoritesId,
      title: 'Favorites',
      isFavorite: true,
    ),
    const Project(id: -2, title: 'Saved filter'),
  ];

  List<String> titles(List<ProjectNode> nodes) =>
      nodes.map((node) => node.project.title).toList();

  test('builds the tree by position then title without archived or pseudo', () {
    final tree = buildProjectTree(projects);

    expect(titles(tree), ['Home', 'Orphan', 'Work']);
    final work = tree.last;
    expect(titles(work.children), ['A child', 'b child']);
    expect(titles(work.children.last.children), ['Grandchild']);
  });

  test('at the same position an umlaut sorts with its letter', () {
    final tree = buildProjectTree([
      sampleProject(id: 1, title: 'Zuhause'),
      sampleProject(id: 2, title: 'Übersicht'),
      sampleProject(id: 3, title: 'Bugs'),
    ]);

    expect(titles(tree), ['Bugs', 'Übersicht', 'Zuhause']);
  });

  test('archived projects on request, in their place; pseudo ones never', () {
    final tree = buildProjectTree(projects, includeArchived: true);

    expect(titles(tree), ['Old', 'Home', 'Orphan', 'Work']);
    expect(titles(tree.last.children), [
      'Archived child',
      'A child',
      'b child',
    ]);
  });

  test('favourites exclude archived and pseudo projects', () {
    expect(favouriteProjects(projects).map((p) => p.title), ['Home']);
  });

  test('flattening honours collapsed nodes and reports the depth', () {
    final tree = buildProjectTree(projects);

    final rows = flattenProjectTree(tree, collapsedIds: const {});
    expect(rows.map((r) => (r.node.project.title, r.depth)), [
      ('Home', 0),
      ('Orphan', 0),
      ('Work', 0),
      ('A child', 1),
      ('b child', 1),
      ('Grandchild', 2),
    ]);

    final collapsed = flattenProjectTree(tree, collapsedIds: const {3});
    expect(collapsed.map((r) => r.node.project.title), [
      'Home',
      'Orphan',
      'Work',
      'A child',
      'b child',
    ]);
    expect(
      flattenProjectTree(
        tree,
        collapsedIds: const {1},
      ).map((r) => r.node.project.title),
      ['Home', 'Orphan', 'Work'],
    );
  });

  test('a parent cycle does not recurse forever', () {
    final tree = buildProjectTree([
      sampleProject(id: 1, title: 'a', parent: 2),
      sampleProject(id: 2, title: 'b', parent: 1),
    ]);

    expect(titles(tree), ['a', 'b']);
    expect(tree.every((node) => node.children.isEmpty), isTrue);
  });
}
