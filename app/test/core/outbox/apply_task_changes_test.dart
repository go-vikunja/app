import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/outbox/apply_task_changes.dart';

void main() {
  test('a cover change survives every rewrite of queued changes', () {
    const changes = TaskChanges(
      title: 'Ship',
      description: '<p>a</p>',
      descriptionBase: '',
      labels: IdSetChange(added: {1}),
      coverImageAttachmentId: 0,
    );
    for (final rewritten in [
      changesAfterCreate(changes),
      withoutLabels(changes, {1}),
      withoutPlacements(changes),
      withoutRelatedTasks(changes, {9}),
      withDescriptionBase(changes, '<p>web</p>'),
      withoutDescription(changes),
    ]) {
      expect(rewritten.coverImageAttachmentId, 0);
    }
  });

  group('dates set here are in whole seconds, as the server keeps them', () {
    final fine = DateTime.utc(2026, 11, 23, 14, 23, 45, 678, 912);
    final whole = DateTime.utc(2026, 11, 23, 14, 23, 45);

    test('in a create', () {
      final task = applyChangesToNewTask(
        const NewTask(projectId: 1, title: 'Call Bob'),
        TaskChanges(
          dueDate: DateChange.set(fine),
          startDate: DateChange.set(fine.toLocal()),
        ),
      );

      expect(task.dueDate, whole);
      expect(task.startDate, whole);
    });

    test('in the reminders, absolute and relative', () {
      final reminders = withLocalInstants(
        [
          TaskReminder(reminder: fine),
          const TaskReminder(
            relativePeriod: Duration(minutes: -15),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ],
        dueDate: fine,
        startDate: null,
        endDate: null,
      );

      expect(reminders.map((reminder) => reminder.reminder), [
        whole,
        whole.subtract(const Duration(minutes: 15)),
      ]);
    });
  });
}
