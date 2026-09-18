import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';

void main() {
  group('Task.textColor', () {
    test('is black on a light background', () {
      expect(buildTask(color: Colors.white).textColor, Colors.black);
    });

    test('is white on a dark background', () {
      expect(buildTask(color: Colors.black).textColor, Colors.white);
    });

    test('is white when no colour is set', () {
      expect(buildTask().textColor, Colors.white);
    });
  });

  group('Task date predicates', () {
    // The API encodes "no date" as year 1, not null, so both must read false.
    test('hasDueDate is false for null and for the year-1 sentinel', () {
      expect(buildTask(dueDate: null).hasDueDate, isFalse);
      expect(buildTask(dueDate: DateTime.utc(1)).hasDueDate, isFalse);
    });

    test('hasDueDate is true for a real date', () {
      expect(buildTask(dueDate: DateTime.utc(2030, 1, 1)).hasDueDate, isTrue);
    });

    test('hasStartDate is false for null and for the year-1 sentinel', () {
      expect(buildTask(startDate: null).hasStartDate, isFalse);
      expect(buildTask(startDate: DateTime.utc(1)).hasStartDate, isFalse);
    });

    test('hasStartDate is true for a real date', () {
      expect(
        buildTask(startDate: DateTime.utc(2030, 1, 1)).hasStartDate,
        isTrue,
      );
    });

    test('hasEndDate is false for null and for the year-1 sentinel', () {
      expect(buildTask(endDate: null).hasEndDate, isFalse);
      expect(buildTask(endDate: DateTime.utc(1)).hasEndDate, isFalse);
    });

    test('hasEndDate is true for a real date', () {
      expect(buildTask(endDate: DateTime.utc(2030, 1, 1)).hasEndDate, isTrue);
    });
  });

  group('Task.copyWith', () {
    test('returns an equal-valued copy when given nothing', () {
      final task = buildTask(
        title: 'Original',
        priority: 3,
        done: true,
        labels: [buildLabel()],
      );

      final copy = task.copyWith();

      expect(copy.id, task.id);
      expect(copy.title, task.title);
      expect(copy.priority, task.priority);
      expect(copy.done, task.done);
      expect(copy.labels, task.labels);
      expect(copy.projectId, task.projectId);
    });

    test('overrides only the fields it is given', () {
      final task = buildTask(title: 'Original', priority: 1);

      final copy = task.copyWith(title: 'Renamed', done: true);

      expect(copy.title, 'Renamed');
      expect(copy.done, isTrue);
      expect(copy.priority, 1);
    });

    test('leaves the source untouched', () {
      final task = buildTask(title: 'Original');

      task.copyWith(title: 'Renamed');

      expect(task.title, 'Original');
    });

    test('copies dates, colour, position and repeat interval', () {
      final due = DateTime.utc(2030, 5, 5);
      final task = buildTask();

      final copy = task.copyWith(
        dueDate: due,
        startDate: due,
        endDate: due,
        color: Colors.red,
        position: 12.5,
        percentDone: 0.5,
        repeatAfter: const Duration(days: 7),
        identifier: '#42',
        description: 'details',
        bucketId: 9,
        parentTaskId: 4,
      );

      expect(copy.dueDate, due);
      expect(copy.startDate, due);
      expect(copy.endDate, due);
      expect(copy.color, Colors.red);
      expect(copy.position, 12.5);
      expect(copy.percentDone, 0.5);
      expect(copy.repeatAfter, const Duration(days: 7));
      expect(copy.identifier, '#42');
      expect(copy.description, 'details');
      expect(copy.bucketId, 9);
      expect(copy.parentTaskId, 4);
    });

    test('does not carry the transient loading flag or project across', () {
      final task = buildTask(project: buildProject())..loading = true;

      final copy = task.copyWith();

      expect(copy.loading, isFalse);
      expect(copy.project, isNull);
    });
  });
}
