import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

Task _task({
  String identifier = '',
  int index = 0,
  bool done = false,
  DateTime? dueDate,
  Duration repeatAfter = Duration.zero,
  RepeatMode repeatMode = RepeatMode.afterAmount,
  Map<TaskRelationKind, List<Task>> relatedTasks = const {},
}) => Task(
  id: 1,
  title: 't',
  projectId: 2,
  identifier: identifier,
  index: index,
  done: done,
  dueDate: dueDate,
  repeatAfter: repeatAfter,
  repeatMode: repeatMode,
  relatedTasks: relatedTasks,
);

void main() {
  group('displayIdentifier', () {
    test('is the server identifier when the project has one', () {
      expect(_task(identifier: 'WORK-2', index: 2).displayIdentifier, 'WORK-2');
    });

    test('is #index for a project without identifier', () {
      expect(_task(identifier: '-2', index: 2).displayIdentifier, '#2');
    });

    test('is #index when the server sent none', () {
      expect(_task(index: 7).displayIdentifier, '#7');
    });

    test('only the exact -index form is replaced', () {
      expect(_task(identifier: '-3', index: 2).displayIdentifier, '-3');
    });
  });

  group('isOverdue', () {
    final now = DateTime.utc(2026, 10, 10, 12);

    test('is true for an open task due in the past or right now', () {
      expect(
        _task(dueDate: now.subtract(const Duration(minutes: 1))).isOverdue(now),
        isTrue,
      );
      expect(_task(dueDate: now).isOverdue(now), isTrue);
    });

    test('is false for a future due date, a done task or no due date', () {
      expect(
        _task(dueDate: now.add(const Duration(minutes: 1))).isOverdue(now),
        isFalse,
      );
      expect(
        _task(
          dueDate: now.subtract(const Duration(days: 1)),
          done: true,
        ).isOverdue(now),
        isFalse,
      );
      expect(_task().isOverdue(now), isFalse);
    });
  });

  group('repeats', () {
    test('with an interval or in monthly mode', () {
      expect(_task(repeatAfter: const Duration(days: 1)).repeats, isTrue);
      expect(_task(repeatMode: RepeatMode.monthly).repeats, isTrue);
      expect(_task(repeatMode: RepeatMode.fromCurrentDate).repeats, isFalse);
      expect(_task().repeats, isFalse);
    });
  });

  group('relations', () {
    final child = _task(identifier: 'A-2', index: 2);
    final parent = _task(identifier: 'A-1', index: 1);

    test('subtasks and parentTasks read the relation map', () {
      final task = _task(
        relatedTasks: {
          TaskRelationKind.subtask: [child],
          TaskRelationKind.parentTask: [parent],
        },
      );

      expect(task.subtasks, [child]);
      expect(task.parentTasks, [parent]);
    });

    test('are empty without relations', () {
      expect(_task().subtasks, isEmpty);
      expect(_task().parentTasks, isEmpty);
    });
  });

  group('enums', () {
    test('priority and repeat mode map unknown values to the default', () {
      expect(TaskPriority.fromValue(5), TaskPriority.doNow);
      expect(TaskPriority.fromValue(9), TaskPriority.unset);
      expect(RepeatMode.fromValue(2), RepeatMode.fromCurrentDate);
      expect(RepeatMode.fromValue(7), RepeatMode.afterAmount);
    });

    test('relation kinds and reminder references come from wire names', () {
      expect(
        TaskRelationKind.fromWire('parenttask'),
        TaskRelationKind.parentTask,
      );
      expect(TaskRelationKind.fromWire('unknown'), isNull);
      expect(
        ReminderRelativeTo.fromWire('due_date'),
        ReminderRelativeTo.dueDate,
      );
      expect(ReminderRelativeTo.fromWire(''), isNull);
    });

    test('a reminder is relative when it references a date', () {
      const relative = TaskReminder(
        relativePeriod: Duration(hours: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      expect(relative.isRelative, isTrue);
      expect(TaskReminder(reminder: DateTime.utc(2026)).isRelative, isFalse);
    });
  });

  test('toString uses the display identifier', () {
    expect('${_task(identifier: '-4', index: 4)}', 'Task(1, #4, t)');
  });
}
