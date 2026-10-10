import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/task_edits.dart';

import '../../helpers/sample_data.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);
  final task = sampleTask(
    id: 3,
    title: 'Write report',
    identifier: 'WORK-3',
    due: DateTime.utc(2026, 10, 13),
    priority: TaskPriority.high,
    labels: [sampleLabel(id: 1, title: 'Finance')],
    assignees: const [User(id: 7, username: 'alice')],
    favorite: true,
    description: '<p>Numbers</p>',
    position: 4,
  );

  test('a done copy is done now and otherwise the same task', () {
    final done = withDone(task, done: true, now: now);

    expect(done.done, isTrue);
    expect(done.doneAt, now);
    expect(done.id, task.id);
    expect(done.title, task.title);
    expect(done.identifier, task.identifier);
    expect(done.dueDate, task.dueDate);
    expect(done.priority, task.priority);
    expect(done.labels, task.labels);
    expect(done.assignees, task.assignees);
    expect(done.isFavorite, isTrue);
    expect(done.description, task.description);
    expect(done.position, task.position);
  });

  test('an open copy clears the done time', () {
    final reopened = withDone(
      withDone(task, done: true, now: now),
      done: false,
      now: now,
    );

    expect(reopened.done, isFalse);
    expect(reopened.doneAt, isNull);
  });
}
