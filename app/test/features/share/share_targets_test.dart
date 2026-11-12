import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/share/application/share_targets.dart';

import '../../helpers/sample_data.dart';

void main() {
  final work = sampleProject(id: 1, title: 'Work');
  final archived = sampleProject(id: 2, title: 'Old', archived: true);
  final readOnly = sampleProject(
    id: 3,
    title: 'Shared',
  ).copyWith(maxPermission: Permission.read);
  final projectsById = {
    work.id: work,
    archived.id: archived,
    readOnly.id: readOnly,
  };
  final tasks = [
    sampleTask(id: 1, title: 'Café order', identifier: 'W-1'),
    sampleTask(id: 2, title: 'Plan', identifier: 'W-2'),
    sampleTask(id: 3, title: 'Café archive', projectId: 2),
    sampleTask(id: 4, title: 'Café menu', projectId: 3),
  ];

  List<int> ids(String query) => [
    for (final task in shareTargets(
      tasks,
      query: query,
      projectsById: projectsById,
    ))
      task.id,
  ];

  test('finds by title or identifier, ignoring case and accents, outside '
      'archived projects and projects the user may only read', () {
    expect(ids(''), [1, 2]);
    expect(ids('CAFE'), [1]);
    expect(ids('café'), [1]);
    expect(ids('w-2'), [2]);
  });
}
