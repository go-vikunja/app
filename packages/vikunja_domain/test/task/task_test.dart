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

  test('toString uses the display identifier and never the title', () {
    expect('${_task(identifier: '-4', index: 4)}', 'Task(1, #4)');
  });

  group('comments', () {
    test('none and read by default', () {
      expect(_task().commentCount, 0);
      expect(_task().isUnread, isFalse);
    });

    // Marking read changes neither `updated` nor anything else.
    test('the count and the unread flag count for equality', () {
      expect(_task(), _task());
      expect(_task().copyWith(commentCount: 1), isNot(_task()));
      expect(_task().copyWith(isUnread: true), isNot(_task()));
    });
  });

  _copyWithTests();
  _deepEqualityTests();
}

void _deepEqualityTests() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  const urgent = Label(id: 3, title: 'Urgent', hexColor: 'e8445a');
  const alice = User(id: 7, username: 'alice');
  const subtask = Task(id: 4, title: 's', projectId: 2, labels: [urgent]);
  final task = Task(
    id: 1,
    title: 't',
    projectId: 2,
    labels: const [urgent],
    assignees: const [alice],
    reminders: [TaskReminder(reminder: monday)],
    relatedTasks: const {
      TaskRelationKind.subtask: [subtask],
    },
    createdBy: alice,
    created: monday,
  );

  group('deep equality', () {
    test('holds for a copy with new lists of the same items', () {
      final copy = task.copyWith(
        labels: [...task.labels],
        assignees: [...task.assignees],
        reminders: [...task.reminders],
        relatedTasks: {
          TaskRelationKind.subtask: [subtask.copyWith()],
        },
      );

      expect(deepTaskEquals(copy, task), isTrue);
      expect(deepTaskListEquals([copy, subtask], [task, subtask]), isTrue);
    });

    test('sees every field that `==` leaves out', () {
      final changed = {
        'a label renamed': task.copyWith(
          labels: const [Label(id: 3, title: 'Later', hexColor: 'e8445a')],
        ),
        'a label recoloured': task.copyWith(
          labels: const [Label(id: 3, title: 'Urgent', hexColor: '1973ff')],
        ),
        'an assignee': task.copyWith(assignees: const []),
        'a reminder': task.copyWith(
          reminders: [
            TaskReminder(reminder: monday.add(const Duration(hours: 1))),
          ],
        ),
        'the repeat interval': task.copyWith(
          repeatAfter: const Duration(days: 7),
        ),
        'the repeat mode': task.copyWith(repeatMode: RepeatMode.monthly),
        "a related task's label": task.copyWith(
          relatedTasks: {
            TaskRelationKind.subtask: [subtask.copyWith(labels: const [])],
          },
        ),
        'the kind of a relation': task.copyWith(
          relatedTasks: {
            TaskRelationKind.parentTask: [subtask],
          },
        ),
        'the bucket': task.copyWith(bucketId: 5),
        'the creator': task.copyWith(createdBy: null),
        'the creation time': task.copyWith(created: null),
      };

      for (final MapEntry(key: what, value: other) in changed.entries) {
        expect(other, task, reason: '`==` leaves out $what');
        expect(deepTaskEquals(other, task), isFalse, reason: what);
      }
    });

    test('sees what `==` sees', () {
      expect(deepTaskEquals(task.copyWith(title: 'u'), task), isFalse);
    });

    test('of lists compares the tasks in order', () {
      expect(deepTaskListEquals([task, subtask], [subtask, task]), isFalse);
      expect(deepTaskListEquals([task], [task, subtask]), isFalse);
      expect(
        deepTaskListEquals([task], [task.copyWith(assignees: const [])]),
        isFalse,
      );
    });
  });
}

void _copyWithTests() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  final task = Task(
    id: 1,
    title: 't',
    projectId: 2,
    done: true,
    doneAt: monday,
    dueDate: monday,
    isFavorite: true,
    labels: const [Label(id: 3, title: 'l')],
    assignees: const [User(id: 7, username: 'alice')],
    repeatAfter: const Duration(days: 1),
    updated: monday,
    commentCount: 4,
  );

  group('copyWith', () {
    test('keeps every field that is left out', () {
      final copy = task.copyWith(title: 'renamed');

      expect(copy.title, 'renamed');
      expect(copy.id, 1);
      expect(copy.projectId, 2);
      expect(copy.done, isTrue);
      expect(copy.doneAt, monday);
      expect(copy.dueDate, monday);
      expect(copy.isFavorite, isTrue);
      expect(copy.labels, task.labels);
      expect(copy.assignees, task.assignees);
      expect(copy.repeatAfter, const Duration(days: 1));
      expect(copy.updated, monday);
      expect(copy.commentCount, 4);
      expect(copy.isUnread, isFalse);
    });

    test('replaces the comment count and the unread flag', () {
      final copy = task.copyWith(commentCount: 0, isUnread: true);

      expect(copy.commentCount, 0);
      expect(copy.isUnread, isTrue);
    });

    test('clears a nullable field passed as null', () {
      final copy = task.copyWith(done: false, doneAt: null, dueDate: null);

      expect(copy.done, isFalse);
      expect(copy.doneAt, isNull);
      expect(copy.dueDate, isNull);
      expect(copy.updated, monday);
    });
  });

  test('the limits are the server limits of Vikunja 2.8.0', () {
    expect(Task.maxTitleLength, 1000);
    expect(Task.maxReminders, 100);
  });
}
