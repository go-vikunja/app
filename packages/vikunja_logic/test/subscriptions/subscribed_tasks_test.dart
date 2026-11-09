import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

const _alice = User(id: 7, username: 'alice');
const _bob = User(id: 8, username: 'bob');
const _garden = 5;
const _shed = 2;

Task _task(
  int id, {
  User createdBy = _bob,
  List<User> assignees = const [],
  int projectId = _shed,
}) => Task(
  id: id,
  title: 'Task $id',
  projectId: projectId,
  createdBy: createdBy,
  assignees: assignees,
);

void main() {
  group('OwnTaskSubscription', () {
    test('wire names', () {
      expect(
        {for (final value in OwnTaskSubscription.values) value: value.wireName},
        {
          OwnTaskSubscription.subscribed: 'subscribed',
          OwnTaskSubscription.none: 'none',
          OwnTaskSubscription.noneWhileAssigned: 'none_assigned',
          OwnTaskSubscription.optedOut: 'opted_out',
        },
      );
    });

    test('fromWire reads every name back', () {
      for (final value in OwnTaskSubscription.values) {
        expect(OwnTaskSubscription.fromWire(value.wireName), value);
      }
    });

    test('fromWire is null for null and an unknown name', () {
      expect(OwnTaskSubscription.fromWire(null), isNull);
      expect(OwnTaskSubscription.fromWire('muted'), isNull);
      expect(OwnTaskSubscription.fromWire('noneWhileAssigned'), isNull);
      expect(OwnTaskSubscription.fromWire(''), isNull);
    });
  });

  group('ownTaskSubscriptionFrom', () {
    const ownTask = Subscription(entity: SubscriptionEntity.task, entityId: 3);
    const viaProject = Subscription(
      entity: SubscriptionEntity.project,
      entityId: _garden,
    );

    OwnTaskSubscription from(
      Subscription? read, {
      bool projectFollowed = false,
      bool assigned = false,
    }) => ownTaskSubscriptionFrom(
      read,
      projectFollowed: projectFollowed,
      assigned: assigned,
    );

    test('a subscription naming the task is the own row', () {
      for (final projectFollowed in [false, true]) {
        for (final assigned in [false, true]) {
          expect(
            from(ownTask, projectFollowed: projectFollowed, assigned: assigned),
            OwnTaskSubscription.subscribed,
            reason: 'followed $projectFollowed, assigned $assigned',
          );
        }
      }
    });

    test('a subscription naming a project means no own row', () {
      for (final projectFollowed in [false, true]) {
        expect(
          from(viaProject, projectFollowed: projectFollowed),
          OwnTaskSubscription.none,
        );
        expect(
          from(viaProject, projectFollowed: projectFollowed, assigned: true),
          OwnTaskSubscription.noneWhileAssigned,
        );
      }
    });

    test('nothing under a followed project is an opt-out', () {
      expect(from(null, projectFollowed: true), OwnTaskSubscription.optedOut);
      expect(
        from(null, projectFollowed: true, assigned: true),
        OwnTaskSubscription.optedOut,
      );
    });

    test('nothing under a project not followed is no own row', () {
      expect(from(null), OwnTaskSubscription.none);
      expect(from(null, assigned: true), OwnTaskSubscription.noneWhileAssigned);
    });
  });

  group('SubscribedTasks.covers', () {
    bool covers(
      Task task, {
      OwnTaskSubscription? own,
      Set<int> followedProjects = const {},
    }) => SubscribedTasks(
      own: {task.id: ?own},
      followedProjects: followedProjects,
    ).covers(task, userId: _alice.id);

    test('a task created here and not sent yet', () {
      final draft = _task(-2);

      expect(covers(draft), isTrue);
      expect(covers(draft, own: OwnTaskSubscription.optedOut), isTrue);
    });

    group('not read yet', () {
      test('the creator', () {
        expect(covers(_task(1, createdBy: _alice)), isTrue);
      });

      test('an assignee', () {
        expect(covers(_task(1, assignees: const [_bob, _alice])), isTrue);
      });

      test('a follower of its project', () {
        expect(
          covers(_task(1, projectId: _garden), followedProjects: {_garden}),
          isTrue,
        );
      });

      test('anybody else, also following another project', () {
        expect(covers(_task(1, assignees: const [_bob])), isFalse);
        expect(
          covers(_task(1, projectId: _garden), followedProjects: {_shed}),
          isFalse,
        );
      });

      test('without a known creator', () {
        expect(
          covers(const Task(id: 1, title: 'Task 1', projectId: _shed)),
          isFalse,
        );
      });
    });

    test('subscribed: always, also unassigned and outside followed '
        'projects', () {
      expect(covers(_task(1), own: OwnTaskSubscription.subscribed), isTrue);
    });

    group('none', () {
      const none = OwnTaskSubscription.none;

      test('not for the creator alone', () {
        expect(covers(_task(1, createdBy: _alice), own: none), isFalse);
      });

      test('an assignment since the read subscribes the user', () {
        expect(covers(_task(1, assignees: const [_alice]), own: none), isTrue);
      });

      test('through its followed project', () {
        expect(
          covers(
            _task(1, projectId: _garden),
            own: none,
            followedProjects: {_garden},
          ),
          isTrue,
        );
      });

      test('not through another followed project', () {
        expect(covers(_task(1), own: none, followedProjects: {7}), isFalse);
      });
    });

    group('none while assigned', () {
      const noneWhileAssigned = OwnTaskSubscription.noneWhileAssigned;

      test('not while still assigned', () {
        expect(
          covers(
            _task(1, createdBy: _alice, assignees: const [_alice]),
            own: noneWhileAssigned,
          ),
          isFalse,
        );
      });

      test('through its followed project', () {
        expect(
          covers(
            _task(1, projectId: _garden, assignees: const [_alice]),
            own: noneWhileAssigned,
            followedProjects: {_garden},
          ),
          isTrue,
        );
      });
    });

    test('opted out: never, also assigned in a followed project', () {
      expect(
        covers(
          _task(
            1,
            createdBy: _alice,
            projectId: _garden,
            assignees: const [_alice],
          ),
          own: OwnTaskSubscription.optedOut,
          followedProjects: {_garden},
        ),
        isFalse,
      );
    });

    test('rows of other tasks change nothing', () {
      const tasks = SubscribedTasks(
        own: {
          2: OwnTaskSubscription.subscribed,
          3: OwnTaskSubscription.optedOut,
        },
        followedProjects: {},
      );

      expect(
        tasks.covers(_task(1, createdBy: _alice), userId: _alice.id),
        isTrue,
      );
      expect(tasks.covers(_task(4), userId: _alice.id), isFalse);
    });

    test('the user is told apart from other users', () {
      const tasks = SubscribedTasks(
        own: {1: OwnTaskSubscription.none},
        followedProjects: {},
      );
      final assignedToBob = _task(1, assignees: const [_bob]);

      expect(tasks.covers(assignedToBob, userId: _alice.id), isFalse);
      expect(tasks.covers(assignedToBob, userId: _bob.id), isTrue);
    });
  });
}
