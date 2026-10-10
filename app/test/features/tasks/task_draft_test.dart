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
  });
}
