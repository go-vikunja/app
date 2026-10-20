import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('NewProject', () {
    test('defaults to the top level without a colour', () {
      const project = NewProject(title: 'Studio');

      expect(project.parentProjectId, 0);
      expect(project.hexColor, '');
    });

    test('is equal by value and prints no title', () {
      expect(
        const NewProject(title: 'Studio', parentProjectId: 3),
        const NewProject(title: 'Studio', parentProjectId: 3),
      );
      expect(
        const NewProject(title: 'Studio'),
        isNot(const NewProject(title: 'Studio', hexColor: 'e8b04a')),
      );
      expect(
        const NewProject(title: 'Secret', parentProjectId: 3).toString(),
        allOf(contains('3'), isNot(contains('Secret'))),
      );
    });
  });

  group('ProjectChanges', () {
    test('is empty only without any field', () {
      expect(const ProjectChanges().isEmpty, isTrue);
      for (final changes in const [
        ProjectChanges(title: 'a'),
        ProjectChanges(description: ''),
        ProjectChanges(identifier: ''),
        ProjectChanges(hexColor: ''),
        ProjectChanges(parentProjectId: 0),
        ProjectChanges(isFavorite: false),
        ProjectChanges(isArchived: false),
        ProjectChanges(position: 0.5),
      ]) {
        expect(changes.isEmpty, isFalse, reason: '$changes');
      }
    });

    test('is equal by value', () {
      expect(
        const ProjectChanges(title: 'a', isArchived: true),
        const ProjectChanges(title: 'a', isArchived: true),
      );
      expect(
        const ProjectChanges(title: 'a').hashCode,
        const ProjectChanges(title: 'a').hashCode,
      );
      expect(
        const ProjectChanges(identifier: ''),
        isNot(const ProjectChanges(hexColor: '')),
      );
      expect(
        const ProjectChanges(description: '<p>a</p>'),
        isNot(const ProjectChanges(description: '<p>b</p>')),
      );
      expect(
        const ProjectChanges(isFavorite: true),
        isNot(const ProjectChanges(isFavorite: true, position: 0.5)),
      );
    });

    test('names the fields set without user text', () {
      final text = const ProjectChanges(
        title: 'Secret',
        description: '<p>Hidden</p>',
        identifier: 'SEC',
        hexColor: 'abcdef',
        parentProjectId: 4,
        isFavorite: true,
        isArchived: false,
        position: 0.5,
      ).toString();

      expect(text, contains('title'));
      expect(text, contains('description'));
      expect(text, contains('identifier'));
      expect(text, contains('parentProjectId: 4'));
      expect(text, contains('isFavorite: true'));
      expect(text, contains('isArchived: false'));
      expect(text, contains('position: 0.5'));
      expect(text, isNot(contains('Secret')));
      expect(text, isNot(contains('Hidden')));
      expect(text, isNot(contains('SEC')));
      expect(text, isNot(contains('abcdef')));
    });
  });
}
