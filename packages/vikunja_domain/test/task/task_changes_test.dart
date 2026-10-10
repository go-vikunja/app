import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  final friday = DateTime.utc(2026, 10, 16, 17);

  group('DateChange', () {
    test('set compares by instant, clear is a singleton', () {
      expect(DateChange.set(monday), SetDate(monday));
      expect(DateChange.set(monday), isNot(SetDate(friday)));
      expect(const DateChange.clear(), const ClearDate());
      expect(DateChange.set(monday), isNot(const ClearDate()));
      expect(DateChange.set(monday).hashCode, SetDate(monday).hashCode);
      expect(const ClearDate().hashCode, const ClearDate().hashCode);
    });
  });

  group('TaskChanges.isEmpty', () {
    test('is true without any field set', () {
      expect(const TaskChanges().isEmpty, isTrue);
    });

    test('is false with any single field set', () {
      final singles = [
        const TaskChanges(title: 't'),
        const TaskChanges(description: ''),
        const TaskChanges(done: false),
        const TaskChanges(isFavorite: false),
        const TaskChanges(priority: 0),
        const TaskChanges(percentDone: 0),
        const TaskChanges(hexColor: ''),
        TaskChanges(dueDate: DateChange.set(monday)),
        const TaskChanges(startDate: DateChange.clear()),
        const TaskChanges(endDate: DateChange.clear()),
      ];

      expect(singles.map((c) => c.isEmpty), everyElement(isFalse));
    });
  });

  group('TaskChanges.merge', () {
    test('the later change wins where both set a field', () {
      final earlier = TaskChanges(
        title: 'old',
        done: true,
        priority: 1,
        dueDate: DateChange.set(monday),
      );
      final later = TaskChanges(
        title: 'new',
        done: false,
        dueDate: DateChange.set(friday),
      );

      expect(
        earlier.merge(later),
        TaskChanges(
          title: 'new',
          done: false,
          priority: 1,
          dueDate: DateChange.set(friday),
        ),
      );
    });

    test('fields the later change leaves null keep the earlier value', () {
      final earlier = TaskChanges(
        description: '<p>d</p>',
        isFavorite: true,
        percentDone: 0.5,
        hexColor: 'ff00aa',
        startDate: DateChange.set(monday),
        endDate: const DateChange.clear(),
      );

      expect(
        earlier.merge(const TaskChanges(done: true)),
        TaskChanges(
          description: '<p>d</p>',
          done: true,
          isFavorite: true,
          percentDone: 0.5,
          hexColor: 'ff00aa',
          startDate: DateChange.set(monday),
          endDate: const DateChange.clear(),
        ),
      );
      expect(earlier.merge(const TaskChanges()), earlier);
      expect(const TaskChanges().merge(earlier), earlier);
    });

    test('a clear after a set clears, a set after a clear sets', () {
      final set = TaskChanges(dueDate: DateChange.set(monday));
      const clear = TaskChanges(dueDate: DateChange.clear());

      expect(set.merge(clear).dueDate, const ClearDate());
      expect(clear.merge(set).dueDate, SetDate(monday));
    });

    test('a toggle and its undo leave the last state', () {
      const done = TaskChanges(done: true);
      const undone = TaskChanges(done: false);

      expect(done.merge(undone), undone);
      expect(done.merge(undone).merge(done), done);
    });
  });

  group('equality', () {
    test('compares every field', () {
      expect(
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)),
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)),
      );
      expect(
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)).hashCode,
        TaskChanges(title: 'a', dueDate: DateChange.set(monday)).hashCode,
      );
      expect(
        const TaskChanges(title: 'a'),
        isNot(const TaskChanges(title: 'a', done: true)),
      );
      expect(
        const TaskChanges(percentDone: 0.5),
        isNot(const TaskChanges(percentDone: 0.25)),
      );
    });
  });
}
