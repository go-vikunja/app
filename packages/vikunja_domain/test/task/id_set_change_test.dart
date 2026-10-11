import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('IdSetChange.merge', () {
    final table = <(String, IdSetChange, IdSetChange, IdSetChange)>[
      (
        'disjoint changes add up',
        const IdSetChange(added: {1}, removed: {2}),
        const IdSetChange(added: {3}, removed: {4}),
        const IdSetChange(added: {1, 3}, removed: {2, 4}),
      ),
      (
        'add then remove: removed',
        const IdSetChange(added: {1}),
        const IdSetChange(removed: {1}),
        const IdSetChange(removed: {1}),
      ),
      (
        'remove then add: added',
        const IdSetChange(removed: {1}),
        const IdSetChange(added: {1}),
        const IdSetChange(added: {1}),
      ),
      (
        'add twice: added once',
        const IdSetChange(added: {1}),
        const IdSetChange(added: {1}),
        const IdSetChange(added: {1}),
      ),
      (
        'remove twice: removed once',
        const IdSetChange(removed: {1}),
        const IdSetChange(removed: {1}),
        const IdSetChange(removed: {1}),
      ),
      (
        'add, remove, add again',
        const IdSetChange(added: {1}).merge(const IdSetChange(removed: {1})),
        const IdSetChange(added: {1}),
        const IdSetChange(added: {1}),
      ),
      (
        'an empty later change keeps the earlier one',
        const IdSetChange(added: {1}, removed: {2}),
        const IdSetChange(),
        const IdSetChange(added: {1}, removed: {2}),
      ),
      (
        'an empty earlier change takes the later one',
        const IdSetChange(),
        const IdSetChange(added: {1}, removed: {2}),
        const IdSetChange(added: {1}, removed: {2}),
      ),
      (
        'the later change wins per id and leaves the others',
        const IdSetChange(added: {1, 2}, removed: {3, 4}),
        const IdSetChange(added: {3}, removed: {1}),
        const IdSetChange(added: {2, 3}, removed: {1, 4}),
      ),
    ];

    for (final (name, earlier, later, merged) in table) {
      test(name, () {
        expect(earlier.merge(later), merged);
      });
    }

    test('add then remove of an id the server never had is a no-op on the '
        'server state', () {
      final merged = const IdSetChange(added: {1})
          .merge(const IdSetChange(removed: {1}));

      expect(merged.applyTo(const [2]), {2});
    });
  });

  group('IdSetChange.applyTo', () {
    test('removes and adds', () {
      expect(
        const IdSetChange(added: {3, 4}, removed: {1}).applyTo(const [1, 2]),
        {2, 3, 4},
      );
    });

    test('ignores removals of absent ids and additions of present ones', () {
      expect(
        const IdSetChange(added: {2}, removed: {9}).applyTo(const [1, 2]),
        {1, 2},
      );
    });

    test('an id both added and removed ends up present', () {
      expect(
        const IdSetChange(added: {1}, removed: {1}).applyTo(const <int>[]),
        {1},
      );
      expect(const IdSetChange(added: {1}, removed: {1}).applyTo(const [1]), {
        1,
      });
    });

    test('the empty change keeps the set', () {
      expect(const IdSetChange().applyTo(const [1, 2, 2]), {1, 2});
    });
  });

  group('IdSetChange', () {
    test('isEmpty only without additions and removals', () {
      expect(const IdSetChange().isEmpty, isTrue);
      expect(const IdSetChange(added: {1}).isEmpty, isFalse);
      expect(const IdSetChange(removed: {1}).isEmpty, isFalse);
    });

    test('equal by content, regardless of order', () {
      expect(
        const IdSetChange(added: {1, 2}, removed: {3}),
        const IdSetChange(added: {2, 1}, removed: {3}),
      );
      expect(
        const IdSetChange(added: {1, 2}, removed: {3}).hashCode,
        const IdSetChange(added: {2, 1}, removed: {3}).hashCode,
      );
      expect(const IdSetChange(), const IdSetChange());
    });

    test('differs when either set differs', () {
      expect(
        const IdSetChange(added: {1}),
        isNot(const IdSetChange(removed: {1})),
      );
      expect(
        const IdSetChange(added: {1}),
        isNot(const IdSetChange(added: {1, 2})),
      );
      expect(
        const IdSetChange(removed: {1, 2}),
        isNot(const IdSetChange(removed: {1, 3})),
      );
    });
  });
}
