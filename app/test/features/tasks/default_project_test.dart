import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/tasks/application/default_project.dart';

import '../../helpers/sample_data.dart';

void main() {
  final projects = [
    sampleProject(id: 3, title: 'Work', position: 2),
    sampleProject(id: 4, title: 'Inbox', position: 3),
    sampleProject(id: 5, title: 'Archive', archived: true, position: 1),
    sampleProject(id: 6, title: 'Child', parent: 3),
    sampleProject(id: -1, title: 'Favorites'),
  ];

  test('the current project wins', () {
    expect(defaultProjectFor(projects, currentProjectId: 6)?.id, 6);
  });

  test("the current project wins over the user's default project", () {
    expect(
      defaultProjectFor(projects, currentProjectId: 6, defaultProjectId: 3)?.id,
      6,
    );
  });

  test("without a usable current project it is the user's default "
      'project', () {
    expect(defaultProjectFor(projects, defaultProjectId: 6)?.id, 6);
    expect(
      defaultProjectFor(projects, currentProjectId: 5, defaultProjectId: 3)?.id,
      3,
    );
    expect(
      defaultProjectFor(
        projects,
        currentProjectId: -1,
        defaultProjectId: 3,
      )?.id,
      3,
    );
  });

  test('a default project the task cannot live in is passed over', () {
    // Archived, a pseudo project, or one this device does not know.
    for (final id in [5, -1, 99]) {
      expect(
        defaultProjectFor(projects, defaultProjectId: id)?.id,
        4,
        reason: '$id',
      );
    }
  });

  test('without a usable current project it is the Inbox', () {
    expect(defaultProjectFor(projects)?.id, 4);
    expect(defaultProjectFor(projects, currentProjectId: 5)?.id, 4);
    expect(defaultProjectFor(projects, currentProjectId: -1)?.id, 4);
  });

  test('without an Inbox it is the first project of the tree', () {
    final noInbox = [
      for (final project in projects)
        if (project.id != 4) project,
    ];
    expect(defaultProjectFor(noInbox)?.id, 3);
    expect(defaultProjectFor(noInbox, defaultProjectId: 5)?.id, 3);
  });

  test('null without projects', () {
    expect(defaultProjectFor(const []), isNull);
    expect(defaultProjectFor(const [], defaultProjectId: 4), isNull);
    expect(
      defaultProjectFor([sampleProject(id: 5, title: 'A', archived: true)]),
      isNull,
    );
  });

  test('selectable projects are the tree rows with their depth', () {
    final rows = selectableProjects(projects);
    expect([for (final row in rows) row.node.project.id], [3, 6, 4]);
    expect([for (final row in rows) row.depth], [0, 1, 0]);
  });
}
