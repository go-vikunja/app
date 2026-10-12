import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';

import '../../../helpers/label_user_fakes.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/sync_fakes.dart';
import '../../../helpers/zero_random.dart';

// The service with the real parser of vikunja_logic.
void main() {
  // Monday, local time.
  final now = DateTime(2026, 10, 12, 10, 15);
  final inbox = sampleProject(id: 4, title: 'Inbox', position: 1);
  final garage = sampleProject(id: 3, title: 'Garage', position: 2);
  final twoWords = sampleProject(id: 5, title: 'Side Project', position: 3);
  final archived = sampleProject(id: 6, title: 'Old', archived: true);
  const wichtig = Label(id: 10, title: 'Wichtig');
  const alice = User(id: 20, username: 'alice', name: 'Alice Doe');
  late FakeTaskRepository tasks;
  late FakeLabelRepository labels;
  late FakeUserRepository users;

  setUp(() {
    tasks = FakeTaskRepository(FakeSyncEngine(clock: () => now));
    labels = FakeLabelRepository(labels: const [wichtig]);
    users = FakeUserRepository(
      projectUsers: {
        3: const [alice],
        4: const [alice],
      },
    );
  });

  LocalQuickAddService service({
    UserSettings settings = const UserSettings(),
  }) => LocalQuickAddService(
    snapshot: QuickAddSnapshot(
      projects: [inbox, garage, twoWords, archived],
      labels: labels.labels,
      knownUsers: const [alice],
      settings: settings,
    ),
    tasks: tasks,
    labels: labels,
    users: users,
    now: () => now,
    random: ZeroRandom(),
  );

  test('the line of the contract test', () async {
    const line =
        'Reifen wechseln *wichtig *neu +Garage @alice !3 tomorrow at 9:00 '
        'every week';

    final plan = service().plan(line);

    expect(plan.title, 'Reifen wechseln');
    expect(plan.project, garage);
    expect(plan.labels, [wichtig]);
    expect(plan.newLabels, ['neu']);
    expect(plan.assignees, [alice]);
    expect(plan.priority, 3);
    expect(plan.dueDate, DateTime(2026, 10, 13, 9).toUtc());

    await service().submit(line);

    expect(tasks.creates.single.repeatAfter, const Duration(days: 7));
    expect(tasks.creates.single.repeatMode, RepeatMode.afterAmount);
    expect(
      tasks.updates.single.$2,
      const TaskChanges(
        labels: IdSetChange(added: {10, 500}),
        assignees: IdSetChange(added: {20}),
      ),
    );
  });

  test('quoted labels and projects with spaces', () {
    final plan = service().plan('Plan *"two words" +"side project" trip');

    expect(plan.project, twoWords);
    expect(plan.newLabels, ['two words']);
    expect(plan.title, 'Plan trip');
  });

  test('D38-7: an unmatched project stays where it was typed', () {
    final plan = service().plan('Call +nowhere about the car tomorrow');

    expect(plan.unmatchedProject, 'nowhere');
    expect(plan.title, 'Call +nowhere about the car');
    expect(plan.project, inbox);
    expect(plan.dueDate, DateTime(2026, 10, 13, 12).toUtc());
  });

  test('D38-7: quoted, archived, and followed by another project', () {
    final quoted = service().plan('Ask +"No Such" !2');
    expect(quoted.title, 'Ask +"No Such"');
    expect(quoted.priority, 2);

    final old = service().plan('+Old cleanup *wichtig');
    expect(old.title, '+Old cleanup');
    expect(old.labels, [wichtig]);

    final second = service().plan('x +nowhere +Garage');
    expect(second.title, 'x +nowhere +Garage');
    expect(second.project, inbox);
  });

  group('D38-7: the title and every part of a line with an unmatched '
      'project come from one parse', () {
    test('a date the project token kept from the end is no date', () {
      final plan = service().plan('Meeting 9/11 +Wrok');

      expect(plan.title, 'Meeting 9/11 +Wrok');
      expect(plan.dueDate, isNull);
      expect(plan.parsed.datePhrases, isEmpty);
      expect(plan.unmatchedProject, 'Wrok');
    });

    test('an ordinal the project token kept from `at` is no date', () {
      final plan = service().plan('Call 1st +x at 10');

      expect(plan.title, 'Call 1st +x');
      expect(plan.dueDate, DateTime(2026, 10, 12, 10).toUtc());
      expect(plan.parsed.datePhrases, ['at 10']);
    });

    test('a time after a leading project is a time', () {
      final plan = service().plan('+nowhere at 15:00 call');

      expect(plan.title, '+nowhere call');
      expect(plan.dueDate, DateTime(2026, 10, 12, 15).toUtc());
    });

    test('words inside a quoted project stay in it', () {
      final date = service().plan('Call +"stuff tomorrow"');
      expect(date.title, 'Call +"stuff tomorrow"');
      expect(date.dueDate, isNull);

      final priority = service().plan('Task +"a !3"');
      expect(priority.title, 'Task +"a !3"');
      expect(priority.priority, isNull);
    });

    test('the submitted task is the plan', () async {
      await service().submit('+nowhere at 15:00 call');

      expect(tasks.creates.single.title, '+nowhere call');
      expect(tasks.creates.single.dueDate, DateTime(2026, 10, 12, 15).toUtc());
    });
  });

  test('monthly, every two months and yearly repeats', () async {
    await service().submit('a every month\nb every 2 months\nc yearly');

    expect(tasks.creates.map((task) => (task.repeatAfter, task.repeatMode)), [
      (Duration.zero, RepeatMode.monthly),
      (const Duration(days: 60), RepeatMode.afterAmount),
      (const Duration(days: 365), RepeatMode.afterAmount),
    ]);
    // Without a date each is due today at the default time.
    expect(
      tasks.creates.map((task) => task.dueDate),
      everyElement(DateTime(2026, 10, 12, 12).toUtc()),
    );
  });

  test('magic only and the whole-text quote escape', () {
    final magic = service().plan('*wichtig +Garage');
    expect(magic.magicOnly, isTrue);
    expect(magic.title, '*wichtig +Garage');
    expect(magic.project, inbox);

    final quoted = service().plan('"*wichtig tomorrow"');
    expect(quoted.magicOnly, isFalse);
    expect(quoted.title, '*wichtig tomorrow');
    expect(quoted.labels, isEmpty);
    expect(quoted.dueDate, isNull);
  });

  test('todoist and disabled modes', () {
    final todoist = service(
      settings: const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.todoist,
      ),
    ).plan('Lorem Ipsum @wichtig #garage !2 +alice');
    expect(todoist.title, 'Lorem Ipsum');
    expect(todoist.labels, [wichtig]);
    expect(todoist.project, garage);
    expect(todoist.assignees, [alice]);

    final disabled = service(
      settings: const UserSettings(
        quickAddMagicMode: QuickAddMagicMode.disabled,
      ),
    ).plan('Lorem *wichtig tomorrow');
    expect(disabled.title, 'Lorem *wichtig tomorrow');
    expect(disabled.labels, isEmpty);
    expect(disabled.dueDate, isNull);
  });

  test('the default reminders go with a parsed date', () {
    final plan = service(
      settings: const UserSettings(
        quickAddDefaultReminders: [Duration(minutes: -10)],
      ),
    ).plan('Dentist next monday at 15:00');

    expect(plan.title, 'Dentist');
    // D38-6: on a Monday, next monday is today.
    expect(plan.dueDate, DateTime(2026, 10, 12, 15).toUtc());
    expect(plan.reminders, const [
      TaskReminder(
        relativePeriod: Duration(minutes: -10),
        relativeTo: ReminderRelativeTo.dueDate,
      ),
    ]);
  });
}
