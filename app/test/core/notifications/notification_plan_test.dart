import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart'
    show OwnTaskSubscription, SubscribedTasks;
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_plan.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';

import '../../helpers/sample_data.dart';

void main() {
  const alice = User(id: 7, username: 'alice');
  const bob = User(id: 8, username: 'bob');
  final now = DateTime.utc(2026, 10, 12, 9);
  final inAnHour = now.add(const Duration(hours: 1));
  final inTwoHours = now.add(const Duration(hours: 2));
  final anHourAgo = now.subtract(const Duration(hours: 1));

  ({String title, String body}) describe(
    Task task,
    ScheduledNotificationKind kind,
  ) => (title: task.title, body: kind.name);

  List<DesiredNotification> plan(
    List<Task> tasks, {
    NotificationPreferences preferences = const NotificationPreferences(),
    List<Snooze> snoozes = const [],
  }) => planNotifications(
    tasks: tasks,
    userId: alice.id,
    preferences: preferences,
    now: now,
    snoozes: snoozes,
    describe: describe,
  );

  Task own({
    required int id,
    DateTime? due,
    List<TaskReminder> reminders = const [],
    bool done = false,
    String title = 'Task',
  }) => sampleTask(
    id: id,
    title: title,
    due: due,
    reminders: reminders,
    done: done,
  ).copyWith(createdBy: alice);

  group('planNotifications', () {
    test('a reminder and the due date of a task the user created', () {
      final desired = plan([
        own(
          id: 1,
          title: 'Water',
          due: inTwoHours,
          reminders: [TaskReminder(reminder: inAnHour)],
        ),
      ]);

      expect(desired.map((d) => d.key), ['1:reminder:0', '1:due']);
      expect(desired.map((d) => d.fireAt), [inAnHour, inTwoHours]);
      expect(desired.map((d) => d.kind), [
        ScheduledNotificationKind.reminder,
        ScheduledNotificationKind.dueDate,
      ]);
      expect(desired.map((d) => d.taskId), [1, 1]);
      expect(desired.first.title, 'Water');
      expect(desired.first.body, 'reminder');
      expect(desired.last.body, 'dueDate');
      expect(desired.map((d) => d.snooze), [null, null]);
    });

    test('an assignee gets them, a mere reader does not', () {
      final desired = plan([
        sampleTask(
          id: 1,
          title: 'Assigned',
          due: inAnHour,
          assignees: const [bob, alice],
        ).copyWith(createdBy: bob),
        sampleTask(
          id: 2,
          title: 'Shared',
          due: inAnHour,
          assignees: const [bob],
        ).copyWith(createdBy: bob),
        sampleTask(id: 3, title: 'Nobody', due: inAnHour),
      ]);

      expect(desired.map((d) => d.taskId), [1]);
    });

    test("a task created here under a temporary id counts as the user's", () {
      final desired = plan([sampleTask(id: -2, title: 'New', due: inAnHour)]);

      expect(desired.map((d) => d.key), ['-2:due']);
    });

    test('done tasks get nothing', () {
      expect(plan([own(id: 1, due: inAnHour, done: true)]), isEmpty);
    });

    test('instants that have passed are left out, as is a relative '
        'reminder without an instant', () {
      final desired = plan([
        own(
          id: 1,
          due: anHourAgo,
          reminders: [
            TaskReminder(reminder: anHourAgo),
            const TaskReminder(
              relativePeriod: Duration(minutes: -30),
              relativeTo: ReminderRelativeTo.dueDate,
            ),
            TaskReminder(reminder: now),
            TaskReminder(reminder: inAnHour),
          ],
        ),
      ]);

      expect(desired.map((d) => d.key), ['1:reminder:3']);
    });

    test('the key follows the reminder order of the task', () {
      final desired = plan([
        own(
          id: 1,
          reminders: [
            TaskReminder(reminder: inTwoHours),
            TaskReminder(reminder: inAnHour),
          ],
        ),
      ]);

      expect(desired.map((d) => d.key), ['1:reminder:1', '1:reminder:0']);
    });

    group('snoozes', () {
      final snooze = Snooze(
        key: '1:reminder:0',
        until: now.add(const Duration(minutes: 10)),
        originalFireAt: anHourAgo,
      );

      test('a snooze brings a reminder that has fired back at its time', () {
        final desired = plan(
          [
            own(id: 1, reminders: [TaskReminder(reminder: anHourAgo)]),
          ],
          snoozes: [snooze],
        );

        expect(desired.single.key, '1:reminder:0');
        expect(desired.single.fireAt, snooze.until);
        expect(desired.single.snooze, same(snooze));
      });

      test('a snooze of a time the task no longer has is dropped', () {
        final desired = plan(
          [
            own(id: 1, reminders: [TaskReminder(reminder: inTwoHours)]),
          ],
          snoozes: [snooze],
        );

        expect(desired.single.fireAt, inTwoHours);
        expect(desired.single.snooze, isNull);
      });

      test('an expired snooze is dropped', () {
        final desired = plan(
          [
            own(id: 1, reminders: [TaskReminder(reminder: anHourAgo)]),
          ],
          snoozes: [
            Snooze(key: '1:reminder:0', until: now, originalFireAt: anHourAgo),
          ],
        );

        expect(desired, isEmpty);
      });

      test('a snooze applies to the due date too', () {
        final desired = plan(
          [own(id: 1, due: anHourAgo)],
          snoozes: [
            Snooze(key: '1:due', until: inAnHour, originalFireAt: anHourAgo),
          ],
        );

        expect(desired.single.key, '1:due');
        expect(desired.single.fireAt, inAnHour);
      });
    });

    group('preferences', () {
      final tasks = [
        own(
          id: 1,
          due: inTwoHours,
          reminders: [TaskReminder(reminder: inAnHour)],
        ),
      ];

      test('reminders off leaves only the due date', () {
        final desired = plan(
          tasks,
          preferences: const NotificationPreferences(reminders: false),
        );

        expect(desired.map((d) => d.key), ['1:due']);
      });

      test('due dates off leaves only the reminders', () {
        final desired = plan(
          tasks,
          preferences: const NotificationPreferences(dueDates: false),
        );

        expect(desired.map((d) => d.key), ['1:reminder:0']);
      });

      test('both off plans nothing', () {
        expect(
          plan(
            tasks,
            preferences: const NotificationPreferences(
              reminders: false,
              dueDates: false,
            ),
          ),
          isEmpty,
        );
      });
    });

    test('sorted by time, then by key', () {
      final desired = plan([
        own(
          id: 3,
          due: inTwoHours,
          reminders: [TaskReminder(reminder: inAnHour)],
        ),
        own(id: 2, due: inAnHour),
        own(id: 1, due: inAnHour),
      ]);

      expect(desired.map((d) => d.key), [
        '1:due',
        '2:due',
        '3:reminder:0',
        '3:due',
      ]);
    });
  });

  group('following subscriptions', () {
    const garden = 5;

    List<DesiredNotification> follow(
      List<Task> tasks, {
      Map<int, OwnTaskSubscription> own = const {},
      Set<int> followedProjects = const {garden},
      NotificationPreferences preferences = const NotificationPreferences(),
    }) => planNotifications(
      tasks: tasks,
      userId: alice.id,
      preferences: preferences,
      now: now,
      snoozes: const [],
      describe: describe,
      subscribed: SubscribedTasks(own: own, followedProjects: followedProjects),
    );

    Task task(
      int id, {
      User createdBy = bob,
      int projectId = 1,
      List<User> assignees = const [],
    }) => sampleTask(
      id: id,
      title: 'Task $id',
      projectId: projectId,
      due: inTwoHours,
      reminders: [TaskReminder(reminder: inAnHour)],
      assignees: assignees,
      createdBy: createdBy,
    );

    List<int> plannedTasks(List<DesiredNotification> desired) => [
      for (final entry in desired)
        if (entry.kind == ScheduledNotificationKind.reminder) entry.taskId,
    ];

    test('tasks not read yet: those the user created, is assigned to or '
        'follows through the project', () {
      final desired = follow([
        task(1, createdBy: alice),
        task(2, assignees: const [alice]),
        task(3, projectId: garden),
        task(4, assignees: const [bob]),
      ]);

      expect(plannedTasks(desired), [1, 2, 3]);
    });

    test('an own subscription reaches the user anywhere', () {
      final desired = follow(
        [task(1)],
        own: const {1: OwnTaskSubscription.subscribed},
        followedProjects: const {},
      );

      expect(desired.map((d) => d.key), ['1:reminder:0', '1:due']);
    });

    test('no own row: an assignment since the read subscribes the user, '
        'creating it does not', () {
      final desired = follow(
        [
          task(1, assignees: const [alice]),
          task(2, createdBy: alice),
        ],
        own: const {1: OwnTaskSubscription.none, 2: OwnTaskSubscription.none},
      );

      expect(plannedTasks(desired), [1]);
    });

    test('no own row while assigned: only a followed project', () {
      final desired = follow(
        [
          task(1, assignees: const [alice]),
          task(2, projectId: garden, assignees: const [alice]),
        ],
        own: const {
          1: OwnTaskSubscription.noneWhileAssigned,
          2: OwnTaskSubscription.noneWhileAssigned,
        },
      );

      expect(plannedTasks(desired), [2]);
    });

    test('opted out: nothing, also for a creator and assignee in a '
        'followed project', () {
      final desired = follow(
        [
          task(
            1,
            createdBy: alice,
            projectId: garden,
            assignees: const [alice],
          ),
        ],
        own: const {1: OwnTaskSubscription.optedOut},
      );

      expect(desired, isEmpty);
    });

    test('a task created here under a temporary id', () {
      final desired = follow([
        sampleTask(id: -2, title: 'New', due: inAnHour),
      ], followedProjects: const {});

      expect(desired.map((d) => d.key), ['-2:due']);
    });

    test('due dates follow the same rule', () {
      final desired = follow(
        [
          task(1, createdBy: alice),
          task(2, createdBy: alice),
          task(3, projectId: garden),
          task(4),
        ],
        own: const {2: OwnTaskSubscription.optedOut},
        preferences: const NotificationPreferences(reminders: false),
      );

      expect(desired.map((d) => d.key), ['1:due', '3:due']);
    });

    test('without them the creator and assignees decide (D17), whatever '
        'is followed', () {
      final tasks = [task(1, createdBy: alice), task(2, projectId: garden)];

      expect(plannedTasks(plan(tasks)), [1]);
      expect(
        plannedTasks(
          follow(tasks, own: const {1: OwnTaskSubscription.optedOut}),
        ),
        [2],
      );
    });

    test('done tasks still get nothing', () {
      final desired = follow(
        [task(1, createdBy: alice).copyWith(done: true)],
        own: const {1: OwnTaskSubscription.subscribed},
      );

      expect(desired, isEmpty);
    });
  });

  group('diffSchedule', () {
    DesiredNotification desired(
      String key,
      DateTime at, {
      String title = 'T',
    }) => DesiredNotification(
      key: key,
      taskId: 1,
      kind: ScheduledNotificationKind.reminder,
      fireAt: at,
      title: title,
      body: 'B',
    );

    ({
      String key,
      int osId,
      DateTime fireAt,
      String title,
      String body,
      bool exact,
      NotificationPrivacy privacy,
    })
    scheduled(
      String key,
      int osId,
      DateTime at, {
      String title = 'T',
      bool exact = true,
      NotificationPrivacy privacy = const NotificationPrivacy(),
    }) => (
      key: key,
      osId: osId,
      fireAt: at,
      title: title,
      body: 'B',
      exact: exact,
      privacy: privacy,
    );

    test('schedules what is missing, keeps the unchanged, cancels the gone '
        'and the changed', () {
      final diff = diffSchedule(
        desired: [
          desired('same', inAnHour),
          desired('moved', inTwoHours),
          desired('renamed', inAnHour, title: 'New title'),
          desired('new', inTwoHours),
        ],
        scheduled: [
          scheduled('same', 10, inAnHour),
          scheduled('moved', 11, inAnHour),
          scheduled('renamed', 12, inAnHour),
          scheduled('gone', 13, inAnHour),
        ],
        window: 10,
        exact: true,
        privacy: const NotificationPrivacy(),
      );

      expect(diff.cancelOsIds, [11, 12, 13]);
      expect(diff.schedule.map((d) => d.key), ['moved', 'renamed', 'new']);
    });

    test('only the first window entries are wanted; those beyond it are '
        'cancelled when scheduled', () {
      final diff = diffSchedule(
        desired: [
          desired('a', inAnHour),
          desired('b', inAnHour),
          desired('c', inTwoHours),
        ],
        scheduled: [scheduled('c', 30, inTwoHours)],
        window: 2,
        exact: true,
        privacy: const NotificationPrivacy(),
      );

      expect(diff.cancelOsIds, [30]);
      expect(diff.schedule.map((d) => d.key), ['a', 'b']);
    });

    test('nothing to do when the OS already holds the window', () {
      final diff = diffSchedule(
        desired: [desired('a', inAnHour)],
        scheduled: [scheduled('a', 1, inAnHour)],
        window: 60,
        exact: true,
        privacy: const NotificationPrivacy(),
      );

      expect(diff.cancelOsIds, isEmpty);
      expect(diff.schedule, isEmpty);
    });

    test('an entry scheduled with the other exactness is rescheduled', () {
      final diff = diffSchedule(
        desired: [desired('a', inAnHour), desired('b', inAnHour)],
        scheduled: [
          scheduled('a', 1, inAnHour, exact: false),
          scheduled('b', 2, inAnHour),
        ],
        window: 60,
        exact: true,
        privacy: const NotificationPrivacy(),
      );

      expect(diff.cancelOsIds, [1]);
      expect(diff.schedule.map((d) => d.key), ['a']);

      final revoked = diffSchedule(
        desired: [desired('a', inAnHour)],
        scheduled: [scheduled('a', 1, inAnHour)],
        window: 60,
        exact: false,
        privacy: const NotificationPrivacy(),
      );
      expect(revoked.cancelOsIds, [1]);
      expect(revoked.schedule.map((d) => d.key), ['a']);
    });

    test('an entry scheduled with other privacy settings is rescheduled', () {
      const hidden = NotificationPrivacy(hiddenOnLockScreen: true);
      final diff = diffSchedule(
        desired: [desired('a', inAnHour), desired('b', inAnHour)],
        scheduled: [
          scheduled('a', 1, inAnHour),
          scheduled('b', 2, inAnHour, privacy: hidden),
        ],
        window: 60,
        exact: true,
        privacy: hidden,
      );

      expect(diff.cancelOsIds, [1]);
      expect(diff.schedule.map((d) => d.key), ['a']);
    });

    test('forced, every scheduled entry is cancelled and the window '
        'scheduled again, unchanged ones too', () {
      final diff = diffSchedule(
        desired: [desired('a', inAnHour), desired('b', inTwoHours)],
        scheduled: [
          scheduled('a', 1, inAnHour),
          scheduled('gone', 2, inAnHour),
        ],
        window: 60,
        exact: true,
        privacy: const NotificationPrivacy(),
        force: true,
      );

      expect(diff.cancelOsIds, [1, 2]);
      expect(diff.schedule.map((d) => d.key), ['a', 'b']);
    });

    test('an empty plan cancels everything', () {
      final diff = diffSchedule(
        desired: const [],
        scheduled: [scheduled('a', 1, inAnHour), scheduled('b', 2, inAnHour)],
        window: 60,
        exact: true,
        privacy: const NotificationPrivacy(),
      );

      expect(diff.cancelOsIds, [1, 2]);
      expect(diff.schedule, isEmpty);
    });
  });

  group('parseNotificationKey', () {
    test('reads the task, kind and ordinal back', () {
      expect(parseNotificationKey(reminderNotificationKey(7, 2)), (
        taskId: 7,
        kind: ScheduledNotificationKind.reminder,
        ordinal: 2,
      ));
      expect(parseNotificationKey(dueNotificationKey(-3)), (
        taskId: -3,
        kind: ScheduledNotificationKind.dueDate,
        ordinal: 0,
      ));
    });

    test('anything else is null', () {
      for (final key in ['test', '7', '7:reminder', '7:reminder:x', 'x:due']) {
        expect(parseNotificationKey(key), isNull, reason: key);
      }
    });
  });
}
