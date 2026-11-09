import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/features/quick_add/application/local_quick_add_service.dart';
import 'package:vikunja_mobile/features/quick_add/application/quick_add_plan.dart';

import '../../../helpers/label_user_fakes.dart';
import '../../../helpers/sample_data.dart';
import '../../../helpers/sync_fakes.dart';
import '../../../helpers/zero_random.dart';
import 'fake_grammar.dart';

void main() {
  // Monday, local time: the parser works on the wall clock.
  final now = DateTime(2026, 10, 12, 10, 15);
  final tomorrowAt9 = DateTime(2026, 10, 13, 9).toUtc();
  final inbox = sampleProject(id: 4, title: 'Inbox', position: 1);
  final garage = sampleProject(
    id: 3,
    title: 'Garage',
    identifier: 'GAR',
    position: 2,
  );
  final work = sampleProject(
    id: 5,
    title: 'Work',
    identifier: 'WRK',
    position: 3,
  );
  final archived = sampleProject(id: 6, title: 'Old', archived: true);
  // Its identifier is another project's title: the title wins.
  final shadow = sampleProject(
    id: 7,
    title: 'Shadow',
    identifier: 'WORK',
    position: 4,
  );
  const wichtig = Label(id: 10, title: 'Wichtig');
  const alice = User(id: 20, username: 'alice', name: 'Alice Doe');
  const bob = User(id: 21, username: 'bob', name: 'Bob');
  const bobby = User(id: 22, username: 'bobby', name: 'Bobby');
  const dora = User(id: 23, username: 'dora', name: 'Twin');
  const dirk = User(id: 24, username: 'dirk', name: 'Twin');

  late FakeTaskRepository tasks;
  late FakeLabelRepository labels;
  late FakeUserRepository users;

  setUp(() {
    tasks = FakeTaskRepository(FakeSyncEngine(clock: () => now));
    labels = FakeLabelRepository(labels: const [wichtig]);
    users = FakeUserRepository(
      projectUsers: {
        3: const [alice, bob, bobby],
        4: const [alice, bob],
      },
    );
  });

  LocalQuickAddService service({
    List<Project>? projects,
    List<User> known = const [alice, dora, dirk],
    UserSettings settings = const UserSettings(),
    DateTime? at,
    bool guest = false,
  }) => LocalQuickAddService(
    snapshot: QuickAddSnapshot(
      projects: projects ?? [inbox, garage, work, archived, shadow],
      labels: labels.labels,
      knownUsers: known,
      settings: settings,
    ),
    tasks: tasks,
    labels: labels,
    users: users,
    now: () => at ?? now,
    guest: guest,
    grammar: fakeGrammar,
    random: ZeroRandom(),
  );

  group('plan', () {
    test('every field of a line', () {
      const line =
          'Reifen wechseln *wichtig *neu +Garage @alice !3 tomorrow every week';

      final plan = service(
        settings: const UserSettings(
          quickAddDefaultReminders: [Duration(minutes: -15), Duration.zero],
        ),
      ).plan(line);

      expect(plan.input, line);
      expect(plan.parsed.text, 'Reifen wechseln @alice');
      expect(plan.title, 'Reifen wechseln');
      expect(plan.project, garage);
      expect(plan.unmatchedProject, isNull);
      expect(plan.labels, [wichtig]);
      expect(plan.newLabels, ['neu']);
      expect(plan.assignees, [alice]);
      expect(plan.unresolvedAssignees, isEmpty);
      expect(plan.priority, 3);
      expect(plan.dueDate, tomorrowAt9);
      expect(plan.dueDate!.isUtc, isTrue);
      expect(
        plan.repeat,
        const QuickAddRepeat(amount: 1, unit: QuickAddRepeatUnit.weeks),
      );
      expect(plan.reminders, const [
        TaskReminder(
          relativePeriod: Duration(minutes: -15),
          relativeTo: ReminderRelativeTo.dueDate,
        ),
        TaskReminder(relativeTo: ReminderRelativeTo.dueDate),
      ]);
      expect(plan.magicOnly, isFalse);
    });

    test("the sheet's priority goes to a line without one; the line's own "
        'wins', () {
      final quickAdd = service();

      final plain = quickAdd.plan('Buy milk', fallbackPriority: 4);
      expect(plain.priority, 4);
      expect(plain.priorityFromText, isFalse);

      final own = quickAdd.plan('Buy milk !2', fallbackPriority: 4);
      expect(own.priority, 2);
      expect(own.priorityFromText, isTrue);

      final magicOnly = quickAdd.plan('!2', fallbackPriority: 4);
      expect(magicOnly.magicOnly, isTrue);
      expect(magicOnly.priority, 4);
      expect(magicOnly.priorityFromText, isFalse);
    });

    test('a plain title goes to the fallback with nothing else', () {
      final plan = service().plan('  Buy milk  ', fallbackProjectId: 5);

      expect(plan.title, 'Buy milk');
      expect(plan.project, work);
      expect(plan.labels, isEmpty);
      expect(plan.newLabels, isEmpty);
      expect(plan.dueDate, isNull);
      expect(plan.priority, isNull);
      expect(plan.reminders, isEmpty);
      expect(plan.magicOnly, isFalse);
    });

    group('project', () {
      test('matches a title or an identifier, ignoring case', () {
        expect(service().plan('a +garage').project, garage);
        expect(service().plan('a +GARAGE').project, garage);
        expect(service().plan('a +gar').project, garage);
        expect(service().plan('a +wrk').project, work);
      });

      test('a title wins over an identifier', () {
        expect(service().plan('a +work').project, work);
      });

      test('the fallback: the screen, the default project, the Inbox', () {
        const settings = UserSettings(defaultProjectId: 3);

        expect(
          service(settings: settings).plan('a', fallbackProjectId: 5).project,
          work,
        );
        expect(service(settings: settings).plan('a').project, garage);
        expect(service().plan('a').project, inbox);
        expect(
          service(settings: const UserSettings(defaultProjectId: 6))
              .plan('a', fallbackProjectId: 99)
              .project,
          inbox,
        );
      });

      test('null without any project', () {
        expect(service(projects: [archived]).plan('a +Old').project, isNull);
      });

      test('D38-7: one that matches nothing stays in the title and the '
          'fallback takes the task', () {
        final plan = service().plan(
          'Call +nowhere Bob tomorrow',
          fallbackProjectId: 5,
        );

        expect(plan.title, 'Call +nowhere Bob');
        expect(plan.unmatchedProject, 'nowhere');
        expect(plan.project, work);
        expect(plan.dueDate, tomorrowAt9);
      });

      test('D38-7: archived projects are not matched', () {
        final plan = service().plan('Clean up +Old');

        expect(plan.unmatchedProject, 'Old');
        expect(plan.title, 'Clean up +Old');
        expect(plan.project, inbox);
      });

      test('only the first project counts, as on the web; a later one '
          'stays text also when the first matched nothing', () {
        final matched = service().plan('x +Garage +Work');
        expect(matched.project, garage);
        expect(matched.title, 'x +Work');

        final unmatched = service().plan('x +nowhere +Garage !2');
        expect(unmatched.project, inbox);
        expect(unmatched.unmatchedProject, 'nowhere');
        expect(unmatched.title, 'x +nowhere +Garage');
        expect(unmatched.priority, 2);
      });
    });

    group('labels', () {
      test('match by title ignoring case; new ones are listed once', () {
        final plan = service().plan('a *WICHTIG *Neu *neu *wichtig');

        expect(plan.labels, [wichtig]);
        expect(plan.newLabels, ['Neu']);
        expect(plan.title, 'a');
      });
    });

    group('assignees', () {
      test('a username matches ignoring case and leaves the title', () {
        final plan = service().plan('Call @ALICE now');

        expect(plan.assignees, [alice]);
        expect(plan.title, 'Call now');
      });

      test('a display name matches when only one known user has it', () {
        const eve = User(id: 25, username: 'e123', name: 'Eve');
        expect(service().plan('a @eve').assignees, isEmpty);
        expect(service(known: const [alice, eve]).plan('a @EVE').assignees, [
          eve,
        ]);
        final twins = service().plan('a @twin');
        expect(twins.assignees, isEmpty);
        expect(twins.unresolvedAssignees, ['twin']);
      });

      test('unresolved names stay in the title for the server search', () {
        final plan = service().plan('Task @alice @missing *label');

        expect(plan.title, 'Task @missing');
        expect(plan.assignees, [alice]);
        expect(plan.unresolvedAssignees, ['missing']);
        expect(plan.newLabels, ['label']);
      });

      test('a title of nothing but the people keeps them', () {
        final plan = service().plan('@alice *wichtig');

        expect(plan.title, '@alice');
        expect(plan.assignees, [alice]);
        expect(plan.labels, [wichtig]);
        expect(plan.magicOnly, isFalse);
      });
    });

    group('magic only', () {
      test('keeps the raw title in the fallback project and applies '
          'nothing', () {
        final plan = service().plan(
          ' *wichtig +Garage !3 tomorrow ',
          fallbackProjectId: 5,
        );

        expect(plan.magicOnly, isTrue);
        expect(plan.title, '*wichtig +Garage !3 tomorrow');
        expect(plan.project, work);
        expect(plan.labels, isEmpty);
        expect(plan.newLabels, isEmpty);
        expect(plan.priority, isNull);
        expect(plan.dueDate, isNull);
        expect(plan.repeat, isNull);
        expect(plan.reminders, isEmpty);
      });

      test('a blank line is no magic, just empty', () {
        final plan = service().plan('   ');

        expect(plan.magicOnly, isFalse);
        expect(plan.title, isEmpty);
        expect(plan.project, inbox);
      });
    });

    group('dates', () {
      test('a repeat without a date is due today at the default time', () {
        final plan = service(
          settings: const UserSettings(
            quickAddDefaultReminders: [Duration(hours: -1)],
          ),
        ).plan('Water plants every week');

        expect(plan.dueDate, DateTime(2026, 10, 12, 12).toUtc());
        expect(plan.reminders.single.relativePeriod, const Duration(hours: -1));
      });

      test('the default time follows the breakpoints, after 21:00 the '
          'same day at 9', () {
        for (final (hour, minute, expected) in [
          (8, 59, 9),
          (12, 0, 12),
          (12, 1, 15),
          (21, 30, 9),
        ]) {
          final plan = service(at: DateTime(2026, 10, 12, hour, minute))
              .plan('Water plants every week');
          expect(
            plan.dueDate,
            DateTime(2026, 10, 12, expected).toUtc(),
            reason: '$hour:$minute',
          );
        }
      });

      test('a parsed date wins over the repeat default', () {
        final plan = service().plan('Call mom today at 15:00 every week');

        expect(plan.dueDate, DateTime(2026, 10, 12, 15).toUtc());
      });

      test('default reminders only with a due date', () {
        final plan = service(
          settings: const UserSettings(
            quickAddDefaultReminders: [Duration(hours: -1)],
          ),
        ).plan('No date here');

        expect(plan.dueDate, isNull);
        expect(plan.reminders, isEmpty);
      });

      test('the clock is read as local wall-clock time', () {
        final plan = service(at: now.toUtc()).plan('a tomorrow');

        expect(plan.dueDate, tomorrowAt9);
      });
    });

    group('modes', () {
      test("todoist uses the user's prefixes", () {
        final plan = service(
          settings: const UserSettings(
            quickAddMagicMode: QuickAddMagicMode.todoist,
          ),
        ).plan('Lorem @wichtig #garage !2 +alice +nobody');

        expect(plan.labels, [wichtig]);
        expect(plan.project, garage);
        expect(plan.priority, 2);
        expect(plan.assignees, [alice]);
        expect(plan.title, 'Lorem +nobody');
        expect(plan.unresolvedAssignees, ['nobody']);
      });

      test('todoist keeps an unmatched #project in the title', () {
        final plan = service(
          settings: const UserSettings(
            quickAddMagicMode: QuickAddMagicMode.todoist,
          ),
        ).plan('Lorem #nowhere');

        expect(plan.title, 'Lorem #nowhere');
        expect(plan.unmatchedProject, 'nowhere');
      });

      test('disabled takes the text as it is', () {
        final plan = service(
          settings: const UserSettings(
            quickAddMagicMode: QuickAddMagicMode.disabled,
          ),
        ).plan(' *wichtig +Garage tomorrow ', fallbackProjectId: 5);

        expect(plan.title, '*wichtig +Garage tomorrow');
        expect(plan.project, work);
        expect(plan.labels, isEmpty);
        expect(plan.dueDate, isNull);
        expect(plan.magicOnly, isFalse);
      });

      test("disabled still takes the sheet's due date and priority", () {
        final due = DateTime(2026, 10, 20, 12).toUtc();
        final plan = service(
          settings: const UserSettings(
            quickAddMagicMode: QuickAddMagicMode.disabled,
          ),
        ).plan('Buy milk !1', fallbackDueDate: due, fallbackPriority: 5);

        expect(plan.title, 'Buy milk !1');
        expect(plan.dueDate, due);
        expect(plan.priority, 5);
        expect(plan.priorityFromText, isFalse);
      });
    });
  });

  group('submit', () {
    test('creates the task, then attaches labels and people', () async {
      final result =
          await service(
            settings: const UserSettings(
              quickAddDefaultReminders: [Duration(minutes: -15)],
            ),
          ).submit(
            'Reifen wechseln *wichtig *neu +Garage @alice !3 tomorrow '
            'every week',
          );

      expect(labels.created, const [
        NewLabel(title: 'neu', hexColor: 'e69f00'),
      ]);
      expect(tasks.creates, [
        NewTask(
          projectId: 3,
          title: 'Reifen wechseln',
          dueDate: tomorrowAt9,
          priority: TaskPriority.high,
          repeatAfter: const Duration(days: 7),
          reminders: const [
            TaskReminder(
              relativePeriod: Duration(minutes: -15),
              relativeTo: ReminderRelativeTo.dueDate,
            ),
          ],
        ),
      ]);
      expect(tasks.updates, [
        (
          -1,
          const TaskChanges(
            labels: IdSetChange(added: {10, 500}),
            assignees: IdSetChange(added: {20}),
          ),
        ),
      ]);
      expect(tasks.writes, ['create -1 Reifen wechseln', 'update -1']);
      expect(result.createdTaskIds, [-1]);
      expect(result.labelsNotCreated, isEmpty);
      expect(result.unresolvedAssignees, isEmpty);
      // A known name is checked against the project too.
      expect(users.searches, [(3, 'alice')]);
    });

    test('the plan is what submit sends', () async {
      final due = DateTime(2026, 10, 20, 12).toUtc();
      final quickAdd = service(
        settings: const UserSettings(
          quickAddDefaultReminders: [Duration(hours: -1)],
        ),
      );
      const line = 'Pay rent *wichtig !2';

      final plan = quickAdd.plan(line, fallbackDueDate: due);
      await quickAdd.submit(line, fallbackDueDate: due);

      final created = tasks.creates.single;
      expect(created.title, plan.title);
      expect(created.projectId, plan.project!.id);
      expect(created.dueDate, plan.dueDate);
      expect(created.reminders, plan.reminders);
      expect(plan.dueDate, due);
      expect(plan.dueDateFromText, isFalse);
      expect(plan.reminders.single.relativePeriod, const Duration(hours: -1));
    });

    test('without labels or people there is no update', () async {
      await service().submit('Buy milk !1', fallbackProjectId: 5);

      expect(tasks.creates.single.projectId, 5);
      expect(tasks.creates.single.priority, TaskPriority.low);
      expect(tasks.updates, isEmpty);
    });

    test("a repeat becomes the task's interval", () async {
      await service().submit('a every week');
      await service().submit('b every 2 months');

      expect(tasks.creates.map((task) => task.repeatAfter), [
        const Duration(days: 7),
        const Duration(days: 60),
      ]);
    });

    test("the sheet's due date goes to the lines without a date phrase, "
        'with the default reminders', () async {
      final due = DateTime(2026, 10, 20, 12).toUtc();
      await service(
        settings: const UserSettings(
          quickAddDefaultReminders: [Duration(hours: -1)],
        ),
      ).submit('a\nb tomorrow\nc every week\ntomorrow', fallbackDueDate: due);

      expect(tasks.creates.map((task) => (task.title, task.dueDate)), [
        ('a', due),
        ('b', tomorrowAt9),
        ('c', due),
        ('tomorrow', due),
      ]);
      expect(
        tasks.creates.map((task) => task.reminders),
        everyElement(const [
          TaskReminder(
            relativePeriod: Duration(hours: -1),
            relativeTo: ReminderRelativeTo.dueDate,
          ),
        ]),
      );
    });

    test("the sheet's priority goes to the lines without their own", () async {
      await service().submit('a\nb !1\n!2', fallbackPriority: 4);

      expect(tasks.creates.map((task) => (task.title, task.priority)), [
        ('a', TaskPriority.urgent),
        ('b', TaskPriority.low),
        ('!2', TaskPriority.urgent),
      ]);
    });

    test('the further fields go to every task: the lines add labels and '
        'reminders, and a repeat of their own replaces the repeat', () async {
      const roadTrip = Label(id: 11, title: 'Road trip');
      const dayBefore = TaskReminder(
        relativePeriod: Duration(days: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      const hourBefore = TaskReminder(
        relativePeriod: Duration(hours: -1),
        relativeTo: ReminderRelativeTo.dueDate,
      );
      final due = DateTime(2026, 10, 20, 12).toUtc();

      await service(
        settings: const UserSettings(
          quickAddDefaultReminders: [Duration(hours: -1), Duration(days: -1)],
        ),
      ).submit(
        'a *wichtig\nb every 2 months\nc',
        fallbackDueDate: due,
        extras: const QuickAddExtras(
          description: '<p>Notes</p>',
          labels: [roadTrip],
          reminders: [dayBefore],
          repeatAfter: Duration(days: 7),
        ),
      );

      expect(
        tasks.creates.map(
          (task) => (task.title, task.description, task.repeatAfter),
        ),
        [
          ('a', '<p>Notes</p>', const Duration(days: 7)),
          ('b', '<p>Notes</p>', const Duration(days: 60)),
          ('c', '<p>Notes</p>', const Duration(days: 7)),
        ],
      );
      expect(
        tasks.creates.map((task) => task.reminders),
        everyElement(const [dayBefore, hourBefore]),
      );
      expect(tasks.updates, [
        (-1, const TaskChanges(labels: IdSetChange(added: {11, 10}))),
        (-2, const TaskChanges(labels: IdSetChange(added: {11}))),
        (-3, const TaskChanges(labels: IdSetChange(added: {11}))),
      ]);
    });

    test("the sheet's new labels are created on submit, once with the "
        "lines' own, and go to every task", () async {
      final result = await service().submit(
        'a *neu\nb',
        extras: const QuickAddExtras(newLabels: ['Errands', 'Neu']),
      );

      expect(labels.created.map((label) => label.title), ['Errands', 'Neu']);
      expect(tasks.updates, [
        (-1, const TaskChanges(labels: IdSetChange(added: {500, 501}))),
        (-2, const TaskChanges(labels: IdSetChange(added: {500, 501}))),
      ]);
      expect(result.labelsNotCreated, isEmpty);
    });

    test("offline, the sheet's new labels are reported and the tasks go "
        'without them', () async {
      labels.createFailure = const NetworkFailure(NetworkProblem.unreachable);

      final result = await service().submit(
        'a',
        extras: const QuickAddExtras(newLabels: ['Errands']),
      );

      expect(tasks.creates.single.title, 'a');
      expect(tasks.updates, isEmpty);
      expect(result.labelsNotCreated, ['Errands']);
    });

    test('a monthly repeat from the sheet keeps its mode', () async {
      await service().submit(
        'a',
        extras: const QuickAddExtras(repeatMode: RepeatMode.monthly),
      );

      expect(tasks.creates.single.repeatMode, RepeatMode.monthly);
      expect(tasks.creates.single.repeatAfter, Duration.zero);
    });

    test('several lines: one task each, in order; a new label is created '
        'once for all of them', () async {
      final result = await service().submit(
        '- One *neu\n  * Two *Neu +Garage\n\n[ ] Three *wichtig',
      );

      expect(labels.created.map((label) => label.title), ['neu']);
      expect(tasks.creates.map((task) => (task.title, task.projectId)), [
        ('One', 4),
        ('Two', 3),
        ('Three', 4),
      ]);
      expect(tasks.updates, [
        (-1, const TaskChanges(labels: IdSetChange(added: {500}))),
        (
          -2,
          TaskChanges(
            labels: const IdSetChange(added: {500}),
            relations: RelationChange(
              added: {const TaskRelationRef(TaskRelationKind.parentTask, -1)},
            ),
          ),
        ),
        (-3, const TaskChanges(labels: IdSetChange(added: {10}))),
      ]);
      expect(result.createdTaskIds, [-1, -2, -3]);
    });

    test('D38-8: magic-only lines create no labels', () async {
      await service().submit('*Urgent\nTask *other');

      expect(labels.created.map((label) => label.title), ['other']);
      expect(tasks.creates.map((task) => task.title), ['*Urgent', 'Task']);
      expect(tasks.updates.single.$1, -2);
    });

    test('a label that cannot be created is reported once; the tasks go '
        'without it', () async {
      labels.createFailure = const ServerFailure(500);

      final result = await service().submit(
        'Buy milk *Urgent *wichtig\nSell milk *urgent',
      );

      expect(tasks.creates.map((task) => task.title), [
        'Buy milk',
        'Sell milk',
      ]);
      expect(tasks.updates, [
        (-1, const TaskChanges(labels: IdSetChange(added: {10}))),
      ]);
      expect(result.labelsNotCreated, ['Urgent']);
    });

    test('offline, the first failed label create skips the others', () async {
      var attempts = 0;
      labels
        ..createFailure = const NetworkFailure(NetworkProblem.unreachable)
        ..beforeCreate = () async => attempts++;

      final result = await service().submit('a *one *two *three');

      expect(attempts, 1);
      expect(result.labelsNotCreated, ['one', 'two', 'three']);
      expect(tasks.creates.single.title, 'a');
    });

    test('a label title the server cannot take is reported without a '
        'request', () async {
      final long = 'x' * 251;

      final result = await service().submit('a *$long');

      expect(labels.created, isEmpty);
      expect(labels.lookups, isEmpty);
      expect(result.labelsNotCreated, [long]);
    });

    test('the title length counts characters, not UTF-16 units', () async {
      final emoji = '${'x' * 140}${'\u{1F600}' * 60}';
      expect(emoji.runes.length, 200);
      expect(emoji.length, 260);

      final result = await service().submit('a *$emoji');

      expect(labels.created.single.title, emoji);
      expect(result.labelsNotCreated, isEmpty);
    });

    test('a label the server has but this device has not synced yet is '
        'adopted, not made twice', () async {
      labels = FakeLabelRepository(
        labels: const [wichtig],
        serverOnly: const [Label(id: 77, title: 'Einkauf')],
      );

      await service().submit('Milch *einkauf');

      expect(labels.lookups, ['einkauf']);
      expect(labels.created, isEmpty);
      expect(
        tasks.updates.single.$2,
        const TaskChanges(labels: IdSetChange(added: {77})),
      );
    });

    test('a line failing after earlier ones were created reports what was '
        'created and the lines left', () async {
      tasks.beforeWrite = () async {
        if (tasks.creates.length == 3) throw StateError('database');
      };

      final failure = await service()
          .submit('- One\n- Two\n- Three\n- Four')
          .then<Object?>((_) => null, onError: (Object error) => error);

      expect(
        failure,
        isA<QuickAddPartlyFailed>()
            .having((f) => f.createdTaskIds, 'created', [-1, -2])
            .having((f) => f.lineCount, 'lines', 4)
            .having((f) => f.remainingText, 'remaining', 'Three\nFour')
            .having((f) => f.cause, 'cause', isA<StateError>()),
      );
    });

    test('a task created whose labels could not be queued counts as '
        'created', () async {
      tasks.beforeWrite = () async {
        if (tasks.updates.isNotEmpty) throw StateError('database');
      };

      final failure = await service()
          .submit('One *wichtig\nTwo')
          .then<Object?>((_) => null, onError: (Object error) => error);

      expect(
        failure,
        isA<QuickAddPartlyFailed>()
            .having((f) => f.createdTaskIds, 'created', [-1])
            .having((f) => f.remainingText, 'remaining', 'Two'),
      );
    });

    test('a first line that fails throws its own error', () async {
      tasks.beforeWrite = () async => throw StateError('database');

      await expectLater(
        service().submit('One\nTwo'),
        throwsA(isA<StateError>()),
      );
    });

    group('people', () {
      test('a name not known here is looked up in the task project and '
          'leaves the title when found', () async {
        final result = await service().submit('Call @bob soon +Garage');

        expect(users.searches, [(3, 'bob')]);
        expect(tasks.creates.single.title, 'Call soon');
        expect(
          tasks.updates.single.$2,
          const TaskChanges(assignees: IdSetChange(added: {21})),
        );
        expect(result.unresolvedAssignees, isEmpty);
      });

      test('several results need an exact match', () async {
        users = FakeUserRepository(
          projectUsers: {
            4: const [bobby, bob],
          },
        );

        await service().submit('a @bob');

        expect(
          tasks.updates.single.$2.assignees,
          const IdSetChange(added: {21}),
        );
      });

      test('a single result is taken when it contains the name', () async {
        await service().submit('a @bobb');

        expect(users.searches, [(4, 'bobb')]);
        expect(tasks.creates.single.title, 'a @bobb');
        expect(tasks.updates, isEmpty);

        await service().submit('a @obb +Garage');
        expect(tasks.creates.last.title, 'a');
        expect(
          tasks.updates.single.$2.assignees,
          const IdSetChange(added: {22}),
        );
      });

      test('a known user without access to the project stays in the '
          'title', () async {
        final quickAdd = service();
        expect(quickAdd.plan('Angebot @dora +Garage').assignees, [dora]);

        final result = await quickAdd.submit('Angebot @dora +Garage');

        expect(users.searches, [(3, 'dora')]);
        expect(tasks.creates.single.title, 'Angebot @dora');
        expect(tasks.updates, isEmpty);
        expect(result.unresolvedAssignees, ['dora']);
      });

      test('nobody found: the name stays and is reported once', () async {
        final result = await service().submit(
          'Ask @missing\nTell @Missing\nAsk @missing again',
        );

        expect(tasks.creates.map((task) => task.title), [
          'Ask @missing',
          'Tell @Missing',
          'Ask @missing again',
        ]);
        // One search per name and project, whatever the case.
        expect(users.searches, [(4, 'missing')]);
        expect(result.unresolvedAssignees, ['missing']);
      });

      test('offline the local resolution stands and nothing more is asked '
          'of the server', () async {
        users.searchFailure = const NetworkFailure(NetworkProblem.timeout);

        final result = await service().submit(
          'a @bob @alice *neu\nb @carl +Garage',
        );

        expect(users.searches, [(4, 'bob')]);
        expect(labels.created, isEmpty);
        expect(tasks.creates.map((task) => task.title), ['a @bob', 'b @carl']);
        expect(tasks.updates.single, (
          -1,
          const TaskChanges(assignees: IdSetChange(added: {20})),
        ));
        expect(result.unresolvedAssignees, ['bob', 'carl']);
        expect(result.labelsNotCreated, ['neu']);
      });

      test('a search the server refuses leaves only that name '
          'unresolved', () async {
        users.searchFailure = const Forbidden(code: 7003);

        final result = await service().submit('a @bob *neu');

        expect(result.unresolvedAssignees, ['bob']);
        expect(labels.created.map((label) => label.title), ['neu']);
      });

      test('a link-share guest, whom the server refuses both, matches people '
          'only among the known ones and creates no label', () async {
        final result = await service(guest: true)
            .submit('a @alice @bob *neu *wichtig');

        expect(users.searches, isEmpty);
        expect(labels.created, isEmpty);
        expect(tasks.creates.single.title, 'a @bob');
        expect(tasks.updates.single, (
          -1,
          const TaskChanges(
            labels: IdSetChange(added: {10}),
            assignees: IdSetChange(added: {20}),
          ),
        ));
        expect(result.unresolvedAssignees, ['bob']);
        expect(result.labelsNotCreated, ['neu']);
      });

      test('a line of nothing but a person keeps the name as the title and '
          'assigns them', () async {
        await service().submit('@bob');

        expect(tasks.creates.single.title, '@bob');
        expect(users.searches, [(4, 'bob')]);
        expect(
          tasks.updates.single.$2.assignees,
          const IdSetChange(added: {21}),
        );
      });
    });

    test('without a project nothing is created', () async {
      await expectLater(
        service(projects: [archived]).submit('a *neu\nb'),
        throwsA(isA<QuickAddNoProject>()),
      );

      expect(labels.created, isEmpty);
      expect(tasks.creates, isEmpty);
    });

    test('blank text creates nothing', () async {
      final result = await service().submit(' \n\n  ');

      expect(result.createdTaskIds, isEmpty);
      expect(tasks.writes, isEmpty);
    });
  });

  group('submit with indentation', () {
    TaskChanges parentIs(int parent) => TaskChanges(
      relations: RelationChange(
        added: {TaskRelationRef(TaskRelationKind.parentTask, parent)},
      ),
    );

    test('an indented line is a subtask of the line above: created after it '
        'and given its parent behind both creates', () async {
      final result = await service().submit('Parent\n  Child one\n  Child two');

      expect(result.createdTaskIds, [-1, -2, -3]);
      expect(tasks.creates.map((task) => (task.title, task.projectId)), [
        ('Parent', 4),
        ('Child one', 4),
        ('Child two', 4),
      ]);
      expect(tasks.writes, [
        'create -1 Parent',
        'create -2 Child one',
        'update -2',
        'create -3 Child two',
        'update -3',
      ]);
      expect(tasks.updates, [(-2, parentIs(-1)), (-3, parentIs(-1))]);
    });

    test('three levels: each line names the nearest line above with less '
        'indent', () async {
      await service().submit('A\n  B\n    C\n  D\nE\n  F');

      expect(tasks.creates.map((task) => task.title), [
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
      expect(tasks.updates, [
        (-2, parentIs(-1)),
        (-3, parentIs(-2)),
        (-4, parentIs(-1)),
        (-6, parentIs(-5)),
      ]);
    });

    test("a subtask without a project goes into its parent line's, a "
        'subtask with its own keeps it', () async {
      await service().submit(
        'Car +Garage\n  Tyres\n    Valves\n  Invoice +Work',
        fallbackProjectId: 4,
      );

      expect(tasks.creates.map((task) => (task.title, task.projectId)), [
        ('Car', 3),
        ('Tyres', 3),
        ('Valves', 3),
        ('Invoice', 5),
      ]);
    });

    test('a parent project nothing matches leaves the subtask in the '
        'fallback, like the parent', () async {
      await service().submit('Car +Nowhere\n  Tyres', fallbackProjectId: 3);

      expect(tasks.creates.map((task) => (task.title, task.projectId)), [
        ('Car +Nowhere', 3),
        ('Tyres', 3),
      ]);
    });

    test('labels and the parent go in one update', () async {
      await service().submit('Parent\n  Child *Wichtig');

      expect(tasks.updates, [
        (
          -2,
          TaskChanges(
            labels: const IdSetChange(added: {10}),
            relations: RelationChange(
              added: {const TaskRelationRef(TaskRelationKind.parentTask, -1)},
            ),
          ),
        ),
      ]);
    });

    test('the lines left after a failure keep their tree; a child of a '
        'created line starts its own', () async {
      tasks.beforeWrite = () async {
        if (tasks.creates.length == 3) throw StateError('database');
      };

      final failure = await service()
          .submit('A\n  B\n    C\n      D\n  E\n    F')
          .then<Object?>((_) => null, onError: (Object error) => error);

      expect(
        failure,
        isA<QuickAddPartlyFailed>()
            .having((f) => f.createdTaskIds, 'created', [-1, -2])
            .having((f) => f.remainingText, 'remaining', 'C\n  D\nE\n  F'),
      );
    });

    test('a single indented line is one task as typed', () async {
      await service().submit('   Alone');

      expect(tasks.creates.single.title, 'Alone');
      expect(tasks.updates, isEmpty);
    });
  });

  group('acceptSearchedAssignee', () {
    const carl = User(id: 30, username: 'carl', name: 'Carl', email: 'c@x.io');

    test('one result containing the name in username, name or email', () {
      expect(acceptSearchedAssignee(const [carl], 'ARL'), carl);
      expect(acceptSearchedAssignee(const [carl], 'c@x'), carl);
      expect(acceptSearchedAssignee(const [carl], 'dora'), isNull);
    });

    test('several results need equality in one of them', () {
      expect(acceptSearchedAssignee(const [bobby, bob], 'BOB'), bob);
      expect(acceptSearchedAssignee(const [bobby, bob], 'bo'), isNull);
      expect(acceptSearchedAssignee(const [carl, bob], 'c@x.io'), carl);
    });

    test('no result, no user', () {
      expect(acceptSearchedAssignee(const [], 'bob'), isNull);
    });
  });
}
