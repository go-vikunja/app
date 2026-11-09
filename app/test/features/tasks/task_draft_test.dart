import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/repeat_editor.dart';
import 'package:vikunja_mobile/features/tasks/application/task_draft.dart';

import '../../helpers/sample_data.dart';

void main() {
  final task = sampleTask(
    id: 1,
    title: 'Report',
    due: DateTime(2026, 10, 12, 9, 30),
    priority: TaskPriority.high,
    percentDone: 0.5,
    repeatAfter: const Duration(days: 14),
  );

  test('an untouched draft has no changes', () {
    expect(TaskDraft.fromTask(task).diff(task).isEmpty, isTrue);
  });

  test('only the edited fields are in the diff', () {
    final draft = TaskDraft.fromTask(task)
        .copyWith(title: '  Report Q4 ', priority: TaskPriority.urgent);
    expect(
      draft.diff(task),
      const TaskChanges(title: 'Report Q4', priority: 4),
    );
  });

  test('line breaks in the title become spaces', () {
    final pasted = TaskDraft.fromTask(task).copyWith(title: 'Buy\n  milk\n');
    expect(pasted.diff(task).title, 'Buy milk');
    expect(pasted.normalizedTitle, 'Buy milk');

    final same = TaskDraft.fromTask(task).copyWith(title: 'Re\nport');
    expect(same.diff(task).title, 'Re port');
    expect(
      TaskDraft.fromTask(task).copyWith(title: 'Report\n').diff(task).isEmpty,
      isTrue,
    );
  });

  test('a title edited back to its value is no change', () {
    final draft = TaskDraft.fromTask(task).copyWith(title: 'Report ');
    expect(draft.diff(task).isEmpty, isTrue);
  });

  test('dates are set or cleared and compared as instants', () {
    final base = TaskDraft.fromTask(task);
    final sameDue = base.copyWith(dueDate: DateTime(2026, 10, 12, 9, 30));
    expect(sameDue.diff(task).dueDate, isNull);

    final moved = base.copyWith(
      dueDate: DateTime(2026, 10, 13, 9, 30),
      startDate: DateTime(2026, 10, 11, 8),
    );
    expect(
      moved.diff(task),
      TaskChanges(
        dueDate: DateChange.set(DateTime(2026, 10, 13, 9, 30).toUtc()),
        startDate: DateChange.set(DateTime(2026, 10, 11, 8).toUtc()),
      ),
    );

    final cleared = base.copyWith(dueDate: null);
    expect(cleared.diff(task), const TaskChanges(dueDate: DateChange.clear()));
  });

  test('project, percent done and colour', () {
    final draft = TaskDraft.fromTask(task)
        .copyWith(projectId: 7, percentDone: 0.8, hexColor: '1973FF');
    expect(
      draft.diff(task),
      const TaskChanges(projectId: 7, percentDone: 0.8, hexColor: '1973ff'),
    );
  });

  test('clearing the colour sends an empty string', () {
    final coloured = task.copyWith(hexColor: 'ff4136');
    final draft = TaskDraft.fromTask(coloured).copyWith(hexColor: '');
    expect(draft.diff(coloured).hexColor, '');
  });

  group('repeat', () {
    test('a changed interval sends the seconds only', () {
      final draft = TaskDraft.fromTask(task).copyWith(
        repeat: RepeatSetting.none.withPreset(RepeatPreset.thirtyDays),
      );
      expect(
        draft.diff(task),
        const TaskChanges(repeatAfter: Duration(seconds: 2592000)),
      );
    });

    test('removing the repeat sends 0 and the default mode where they '
        'differ', () {
      final draft = TaskDraft.fromTask(task)
          .copyWith(repeat: RepeatSetting.none);
      expect(draft.diff(task), const TaskChanges(repeatAfter: Duration.zero));

      final monthly = task.copyWith(repeatMode: RepeatMode.monthly);
      final fromMonthly = TaskDraft.fromTask(monthly)
          .copyWith(repeat: RepeatSetting.none);
      expect(
        fromMonthly.diff(monthly),
        const TaskChanges(
          repeatAfter: Duration.zero,
          repeatMode: RepeatMode.afterAmount,
        ),
      );
    });

    test('monthly keeps the seconds the server already has', () {
      final monthly = task.copyWith(repeatMode: RepeatMode.monthly);
      final untouched = TaskDraft.fromTask(monthly);
      expect(untouched.diff(monthly).isEmpty, isTrue);
      expect(untouched.copyWith(title: 'x').diff(monthly).repeatAfter, isNull);
    });

    test('from completion with a new amount sends both', () {
      final draft = TaskDraft.fromTask(task).copyWith(
        repeat: const RepeatSetting(
          mode: RepeatEditorMode.fromCompletion,
          amount: 2,
          unit: RepeatUnit.days,
        ),
      );
      expect(
        draft.diff(task),
        const TaskChanges(
          repeatAfter: Duration(days: 2),
          repeatMode: RepeatMode.fromCurrentDate,
        ),
      );
    });
  });

  group('labels and assignees', () {
    final finance = sampleLabel(id: 1, title: 'Finance');
    final errand = sampleLabel(id: 2, title: 'Errand');
    final garden = sampleLabel(id: 3, title: 'Garden');
    const alice = User(id: 7, username: 'alice');
    const bob = User(id: 8, username: 'bob');
    final labelled = task.copyWith(
      labels: [finance, errand],
      assignees: const [alice],
    );

    test('come from the task, without the duplicates a server may send', () {
      final draft = TaskDraft.fromTask(
        labelled.copyWith(labels: [finance, finance, errand]),
      );
      expect(draft.labels, [finance, errand]);
      expect(draft.assignees, [alice]);
    });

    test('go as the ids added and removed', () {
      final draft = TaskDraft.fromTask(labelled)
          .copyWith(labels: [errand, garden], assignees: const [bob]);
      expect(
        draft.diff(labelled),
        const TaskChanges(
          labels: IdSetChange(added: {3}, removed: {1}),
          assignees: IdSetChange(added: {8}, removed: {7}),
        ),
      );
    });

    test('a new order or a removal undone is no change', () {
      final draft = TaskDraft.fromTask(labelled);
      expect(
        draft.copyWith(labels: [errand, finance]).diff(labelled).isEmpty,
        isTrue,
      );
      final undone = draft
          .copyWith(labels: [errand])
          .copyWith(labels: [errand, finance]);
      expect(undone.diff(labelled).labels, isNull);
      expect(
        draft.copyWith(assignees: const []).copyWith(assignees: const [alice]),
        draft,
      );
    });

    test('removing all of them removes every id', () {
      final draft = TaskDraft.fromTask(labelled)
          .copyWith(labels: const [], assignees: const []);
      expect(
        draft.diff(labelled),
        const TaskChanges(
          labels: IdSetChange(removed: {1, 2}),
          assignees: IdSetChange(removed: {7}),
        ),
      );
    });
  });

  group('reminders', () {
    final dayBefore = TaskReminder(
      reminder: DateTime.utc(2026, 10, 11, 7, 30),
      relativePeriod: const Duration(days: -1),
      relativeTo: ReminderRelativeTo.dueDate,
    );
    final absolute = TaskReminder(reminder: DateTime.utc(2026, 10, 20, 9));
    final reminded = task.copyWith(reminders: [dayBefore, absolute]);

    test('an untouched list, a new order and a re-added one are no '
        'change', () {
      final draft = TaskDraft.fromTask(reminded);
      expect(draft.diff(reminded).isEmpty, isTrue);
      expect(
        draft.copyWith(reminders: [absolute, dayBefore]).diff(reminded),
        const TaskChanges(),
      );
      // Added again from a preset, without the instant the server stored.
      const fromPreset = TaskReminder(
        relativePeriod: Duration(days: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      expect(
        draft.copyWith(reminders: [absolute, fromPreset]).diff(reminded),
        const TaskChanges(),
      );
      expect(
        draft
            .copyWith(
              reminders: [TaskReminder(reminder: absolute.reminder!.toLocal())],
            )
            .copyWith(reminders: [dayBefore, absolute])
            .diff(reminded)
            .isEmpty,
        isTrue,
      );
    });

    test('any other list goes whole', () {
      const weekBefore = TaskReminder(
        relativePeriod: Duration(days: -7),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      final draft = TaskDraft.fromTask(reminded);
      expect(
        draft.copyWith(reminders: [dayBefore, weekBefore]).diff(reminded),
        TaskChanges(reminders: [dayBefore, weekBefore]),
      );
      expect(
        draft.copyWith(reminders: const []).diff(reminded),
        const TaskChanges(reminders: []),
      );
      expect(
        TaskDraft.fromTask(task)
            .copyWith(reminders: [absolute])
            .diff(task)
            .reminders,
        [absolute],
      );
    });

    test('a duplicate on the task is kept and counts', () {
      final twice = task.copyWith(reminders: [absolute, absolute]);
      final draft = TaskDraft.fromTask(twice);
      expect(draft.reminders, [absolute, absolute]);
      expect(draft.copyWith(reminders: [absolute]).diff(twice).reminders, [
        absolute,
      ]);
    });

    test('absolute instants are held in UTC', () {
      final local = task.copyWith(
        reminders: [TaskReminder(reminder: DateTime(2026, 10, 20, 9))],
      );
      expect(
        TaskDraft.fromTask(local).reminders.single.reminder!.isUtc,
        isTrue,
      );
    });
  });

  group('validity', () {
    test('needs a title and a repeat amount above 0', () {
      final base = TaskDraft.fromTask(task);
      expect(base.isValid, isTrue);
      expect(base.copyWith(title: '   ').isValid, isFalse);
      expect(
        base
            .copyWith(
              repeat: const RepeatSetting(
                mode: RepeatEditorMode.every,
                amount: 0,
                unit: RepeatUnit.days,
              ),
            )
            .isValid,
        isFalse,
      );
    });

    test('a changed title must fit the limit in code points; a stored '
        'longer one may stay', () {
      final base = TaskDraft.fromTask(task);
      final atLimit = '😀' * Task.maxTitleLength;
      expect(base.copyWith(title: atLimit).titleFits(task), isTrue);
      expect(base.copyWith(title: '$atLimit!').titleFits(task), isFalse);

      final stored = sampleTask(id: 2, title: 'a' * 1200);
      final kept = TaskDraft.fromTask(stored);
      expect(kept.titleFits(stored), isTrue);
      expect(kept.copyWith(title: 'a' * 1199).titleFits(stored), isFalse);
      expect(kept.copyWith(title: 'a' * 1000).titleFits(stored), isTrue);
    });
  });
}
