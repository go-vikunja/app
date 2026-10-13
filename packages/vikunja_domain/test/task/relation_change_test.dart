import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _parentOf1 = TaskRelationRef(TaskRelationKind.parentTask, 1);
const _relatedTo1 = TaskRelationRef(TaskRelationKind.related, 1);
const _blocks2 = TaskRelationRef(TaskRelationKind.blocking, 2);
const _follows3 = TaskRelationRef(TaskRelationKind.follows, 3);
const _temporary = TaskRelationRef(TaskRelationKind.parentTask, -4);

void main() {
  group('TaskRelationRef', () {
    test('equal by kind and other task', () {
      expect(_parentOf1, const TaskRelationRef(TaskRelationKind.parentTask, 1));
      expect(
        _parentOf1.hashCode,
        const TaskRelationRef(TaskRelationKind.parentTask, 1).hashCode,
      );
      expect(_parentOf1, isNot(_relatedTo1));
      expect(
        _parentOf1,
        isNot(const TaskRelationRef(TaskRelationKind.parentTask, 2)),
      );
    });

    test('toString names the wire kind and the id', () {
      expect('$_parentOf1', 'TaskRelationRef(parenttask, 1)');
    });
  });

  group('RelationChange.merge', () {
    final table = <(String, RelationChange, RelationChange, RelationChange)>[
      (
        'disjoint changes add up',
        RelationChange(added: {_parentOf1}, removed: {_blocks2}),
        RelationChange(added: {_follows3}, removed: {_relatedTo1}),
        RelationChange(
          added: {_parentOf1, _follows3},
          removed: {_blocks2, _relatedTo1},
        ),
      ),
      (
        'add then remove: removed',
        RelationChange(added: {_parentOf1}),
        RelationChange(removed: {_parentOf1}),
        RelationChange(removed: {_parentOf1}),
      ),
      (
        'remove then add: added',
        RelationChange(removed: {_parentOf1}),
        RelationChange(added: {_parentOf1}),
        RelationChange(added: {_parentOf1}),
      ),
      (
        'add twice: added once',
        RelationChange(added: {_parentOf1}),
        RelationChange(added: {_parentOf1}),
        RelationChange(added: {_parentOf1}),
      ),
      (
        'the same other task under another kind is another edge',
        RelationChange(added: {_parentOf1}),
        RelationChange(removed: {_relatedTo1}),
        RelationChange(added: {_parentOf1}, removed: {_relatedTo1}),
      ),
      (
        'an empty later change keeps the earlier one',
        RelationChange(added: {_parentOf1}, removed: {_blocks2}),
        const RelationChange(),
        RelationChange(added: {_parentOf1}, removed: {_blocks2}),
      ),
      (
        'an empty earlier change takes the later one',
        const RelationChange(),
        RelationChange(added: {_parentOf1}, removed: {_blocks2}),
        RelationChange(added: {_parentOf1}, removed: {_blocks2}),
      ),
      (
        'add, remove, add again',
        RelationChange(added: {_parentOf1})
            .merge(RelationChange(removed: {_parentOf1})),
        RelationChange(added: {_parentOf1}),
        RelationChange(added: {_parentOf1}),
      ),
    ];

    for (final (name, earlier, later, merged) in table) {
      test(name, () {
        expect(earlier.merge(later), merged);
      });
    }

    test('an add and its removal leave a change that is not empty', () {
      final merged = RelationChange(added: {_parentOf1})
          .merge(RelationChange(removed: {_parentOf1}));

      expect(merged.isEmpty, isFalse);
      expect(merged.applyTo(const []), isEmpty);
    });
  });

  group('RelationChange.applyTo', () {
    test('removes and adds', () {
      expect(
        RelationChange(
          added: {_blocks2},
          removed: {_parentOf1},
        ).applyTo(const [_parentOf1, _relatedTo1]),
        {_relatedTo1, _blocks2},
      );
    });

    test('ignores removals of absent edges and additions of present ones', () {
      expect(
        RelationChange(
          added: {_relatedTo1},
          removed: {_follows3},
        ).applyTo(const [_relatedTo1]),
        {_relatedTo1},
      );
    });

    test('an edge both added and removed ends up present', () {
      final both = RelationChange(added: {_blocks2}, removed: {_blocks2});

      expect(both.applyTo(const []), {_blocks2});
      expect(both.applyTo(const [_blocks2]), {_blocks2});
    });

    test('removing one kind keeps the other kinds to the same task', () {
      expect(
        RelationChange(removed: {_parentOf1})
            .applyTo(const [_parentOf1, _relatedTo1]),
        {_relatedTo1},
      );
    });
  });

  group('RelationChange.mapTaskIds', () {
    test('resolves the other task of every edge on both sides', () {
      final change = RelationChange(
        added: {_temporary, _relatedTo1},
        removed: {const TaskRelationRef(TaskRelationKind.blocked, -5)},
      );

      final mapped = change.mapTaskIds(
        (id) => switch (id) {
          -4 => 40,
          -5 => 50,
          _ => id,
        },
      );

      expect(
        mapped,
        RelationChange(
          added: {
            const TaskRelationRef(TaskRelationKind.parentTask, 40),
            _relatedTo1,
          },
          removed: {const TaskRelationRef(TaskRelationKind.blocked, 50)},
        ),
      );
      expect(change.added, contains(_temporary));
    });

    test('two temporary ids resolving to one edge collapse', () {
      final mapped = RelationChange(
        added: {
          _temporary,
          const TaskRelationRef(TaskRelationKind.parentTask, 40),
        },
      ).mapTaskIds((id) => id < 0 ? 40 : id);

      expect(mapped.added, {
        const TaskRelationRef(TaskRelationKind.parentTask, 40),
      });
    });
  });

  group('RelationChange', () {
    test('isEmpty only without additions and removals', () {
      expect(const RelationChange().isEmpty, isTrue);
      expect(RelationChange(added: {_parentOf1}).isEmpty, isFalse);
      expect(RelationChange(removed: {_parentOf1}).isEmpty, isFalse);
    });

    test('equal by content, regardless of order', () {
      expect(
        RelationChange(added: {_parentOf1, _blocks2}, removed: {_follows3}),
        RelationChange(added: {_blocks2, _parentOf1}, removed: {_follows3}),
      );
      expect(
        RelationChange(
          added: {_parentOf1, _blocks2},
          removed: {_follows3},
        ).hashCode,
        RelationChange(
          added: {_blocks2, _parentOf1},
          removed: {_follows3},
        ).hashCode,
      );
      expect(const RelationChange(), const RelationChange());
    });

    test('differs when either set differs', () {
      expect(
        RelationChange(added: {_parentOf1}),
        isNot(RelationChange(removed: {_parentOf1})),
      );
      expect(
        RelationChange(added: {_parentOf1}),
        isNot(RelationChange(added: {_parentOf1, _blocks2})),
      );
      expect(
        RelationChange(added: {_parentOf1}),
        isNot(RelationChange(added: {_relatedTo1})),
      );
    });
  });
}
