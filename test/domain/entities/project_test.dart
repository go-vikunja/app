import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';

void main() {
  group('Project.copyWith', () {
    test('keeps every copied field when given nothing', () {
      final project = buildProject(
        id: 4,
        title: 'Roadmap',
        description: 'Long term',
        parentProjectId: 2,
        isArchived: true,
        isFavourite: true,
        position: 7.5,
        color: Colors.teal,
        owner: buildUser(),
      );

      final copy = project.copyWith();

      expect(copy.id, 4);
      expect(copy.title, 'Roadmap');
      expect(copy.description, 'Long term');
      expect(copy.parentProjectId, 2);
      expect(copy.isArchived, isTrue);
      expect(copy.isFavourite, isTrue);
      expect(copy.position, 7.5);
      expect(copy.color, Colors.teal);
      expect(copy.owner, project.owner);
      expect(copy.created, project.created);
      expect(copy.updated, project.updated);
    });

    test('replaces only the fields it is given', () {
      final project = buildProject(title: 'Old', isFavourite: false);

      final copy = project.copyWith(title: 'New', isFavourite: true);

      expect(copy.title, 'New');
      expect(copy.isFavourite, isTrue);
      expect(copy.id, project.id);
    });

    test('leaves the source untouched', () {
      final project = buildProject(title: 'Old');

      project.copyWith(title: 'New');

      expect(project.title, 'Old');
    });

    test('does not carry views or subprojects across', () {
      final project = buildProject(subprojects: [buildProject(id: 2)]);

      final copy = project.copyWith();

      expect(copy.views, isEmpty);
      expect(copy.subprojects, isEmpty);
    });
  });
}
