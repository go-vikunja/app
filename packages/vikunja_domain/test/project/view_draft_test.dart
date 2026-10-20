import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _board = ProjectView(
  id: 7,
  projectId: 2,
  title: 'Board',
  kind: ProjectViewKind.kanban,
  position: 400,
  filter: ViewFilter(filter: 'done = false', sortBy: ['id']),
  bucketConfigurationMode: BucketConfigurationMode.manual,
  defaultBucketId: 3,
  doneBucketId: 5,
);

void main() {
  test('view filters are equal by value', () {
    expect(
      const ViewFilter(filter: 'a', sortBy: ['id'], orderBy: ['asc']),
      ViewFilter(filter: 'a', sortBy: List.of(['id']), orderBy: const ['asc']),
    );
    expect(
      const ViewFilter(filter: 'a').hashCode,
      const ViewFilter(filter: 'a').hashCode,
    );
    expect(
      const ViewFilter(sortBy: ['id']),
      isNot(const ViewFilter(sortBy: ['id', 'done'])),
    );
    expect(const ViewFilter(), isNot(const ViewFilter(includeNulls: true)));
    expect(const ViewFilter(), isNot(const ViewFilter(search: 's')));
  });

  group('ViewDraft', () {
    test('is equal by value', () {
      const draft = ViewDraft(title: 'List', kind: ProjectViewKind.list);

      expect(draft, const ViewDraft(title: 'List', kind: ProjectViewKind.list));
      expect(
        draft.hashCode,
        const ViewDraft(title: 'List', kind: ProjectViewKind.list).hashCode,
      );
      expect(
        draft,
        isNot(
          const ViewDraft(
            title: 'List',
            kind: ProjectViewKind.list,
            filter: ViewFilter(),
          ),
        ),
      );
    });

    test('prints neither the title nor the filter', () {
      final text = ViewDraft(
        title: _board.title,
        kind: _board.kind,
        filter: _board.filter,
        bucketConfigurationMode: _board.bucketConfigurationMode,
        position: 150,
      ).toString();

      expect(text, contains('kanban'));
      expect(text, contains('mode: manual'));
      expect(text, contains('position: 150'));
      expect(text, isNot(contains('Board')));
      expect(text, isNot(contains('done = false')));
    });
  });
}
