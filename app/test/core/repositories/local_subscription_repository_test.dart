import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_subscription_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late LocalSubscriptionRepository repository;
  const ownTask = Subscription(entity: SubscriptionEntity.task, entityId: 1);
  const project = Subscription(entity: SubscriptionEntity.project, entityId: 7);

  setUp(() async {
    db = testDatabase();
    read = FakeSyncClient();
    write = FakeWriteClient();
    repository = LocalSubscriptionRepository(db, read, write);
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'One', projectId: 7),
    ]);
    // The fake server: what a write stores, the next read answers.
    write.beforeRequest = (request) async {
      final [action, entity, id] = request.split(' ');
      final subscriptions = entity == 'task'
          ? read.taskSubscriptions
          : read.projectSubscriptions;
      if (action == 'subscribe') {
        subscriptions[int.parse(id)] = Subscription(
          entity: SubscriptionEntity.fromWire(entity)!,
          entityId: int.parse(id),
        );
      } else {
        subscriptions.remove(int.parse(id));
      }
    };
  });

  test('the state is read from the server, own or inherited', () async {
    read.projectSubscriptions[7] = project;
    read.taskSubscriptions[1] = project;

    expect(await repository.forTask(1), project);
    expect(await repository.forProject(7), project);
    expect(await repository.forProject(8), isNull);
    expect(read.requests, [
      'subscription task 1',
      'subscription project 7',
      'subscription project 8',
    ]);
  });

  test(
    'following a task subscribes and answers with the state read back',
    () async {
      final state = await repository.setTaskSubscribed(1, subscribed: true);

      expect(state, ownTask);
      expect(write.requests, ['subscribe task 1']);
      expect(read.requests, ['subscription task 1']);
    },
  );

  test('unfollowing a task followed through its project stores the opt-out '
      'and reads back none', () async {
    read.taskSubscriptions[1] = project;

    final state = await repository.setTaskSubscribed(1, subscribed: false);

    expect(state, isNull);
    expect(write.requests, ['unsubscribe task 1']);
  });

  test('following and unfollowing a project', () async {
    expect(await repository.setProjectSubscribed(7, subscribed: true), project);
    expect(await repository.setProjectSubscribed(7, subscribed: false), isNull);
    expect(write.requests, ['subscribe project 7', 'unsubscribe project 7']);
  });

  test('a task created here goes by its server id once its create was '
      'answered', () async {
    await db
        .into(db.taskIdRemaps)
        .insert(
          TaskIdRemapRow(localId: -4, serverId: 1, at: DateTime.utc(2026)),
        );

    await repository.setTaskSubscribed(-4, subscribed: true);

    expect(write.requests, ['subscribe task 1']);
    expect(await repository.forTask(-4), ownTask);
  });

  test('a task whose create was not answered is not on the server yet: no '
      'request', () async {
    await expectLater(repository.forTask(-5), throwsA(isA<TaskNotSyncedYet>()));
    await expectLater(
      repository.setTaskSubscribed(-5, subscribed: true),
      throwsA(isA<TaskNotSyncedYet>()),
    );
    expect(read.requests, isEmpty);
    expect(write.requests, isEmpty);
  });

  test('offline the failure propagates', () async {
    read.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    write.beforeRequest = read.beforeRequest;

    await expectLater(repository.forTask(1), throwsA(isA<NetworkFailure>()));
    await expectLater(
      repository.setProjectSubscribed(7, subscribed: true),
      throwsA(isA<NetworkFailure>()),
    );
  });

  group('what the reads say is stored for the notifications (D80)', () {
    const alice = 7;
    late int refreshes;
    late Future<void> Function() refresh;

    setUp(() async {
      refreshes = 0;
      refresh = () async {};
      await db.projectsDao.upsertAll([sampleProject(id: 7, title: 'Work')]);
    });

    LocalSubscriptionRepository recording({int? subscriberId = alice}) =>
        LocalSubscriptionRepository(
          db,
          read,
          write,
          subscriberId: subscriberId,
          refreshAfterWrite: () {
            refreshes++;
            return refresh();
          },
        );

    Future<Subscription?> storedForProject() async =>
        (await db.projectsDao.loadProject(7))!.subscription;

    test("a task's read and read-back record the user's own subscription, "
        'judged with the stored project', () async {
      final repository = recording();
      read.taskSubscriptions[1] = ownTask;

      await repository.forTask(1);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.subscribed,
      });

      await repository.setTaskSubscribed(1, subscribed: false);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.none,
      });

      await repository.setProjectSubscribed(7, subscribed: true);
      read.taskSubscriptions[1] = project;
      await repository.setTaskSubscribed(1, subscribed: false);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.optedOut,
      });
    });

    test('an unfollow that went through counts although its read-back '
        'fails; a follow waits for its read-back', () async {
      final repository = recording();
      read.taskSubscriptions[1] = ownTask;
      await repository.forTask(1);
      read.beforeRequest = (request) async {
        if (request == 'subscription task 1') {
          throw const NetworkFailure(NetworkProblem.unreachable);
        }
      };

      await expectLater(
        repository.setTaskSubscribed(1, subscribed: false),
        throwsA(isA<NetworkFailure>()),
      );
      expect(write.requests, ['unsubscribe task 1']);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.none,
      });

      await expectLater(
        repository.setTaskSubscribed(1, subscribed: true),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.none,
      });
    });

    test(
      "a project's unfollow that went through counts although its "
      'read-back fails, for the subprojects covered through it too',
      () async {
        final repository = recording();
        await db.projectsDao.upsertAll([
          sampleProject(id: 7, title: 'Work').copyWith(subscription: project),
          sampleProject(
            id: 8,
            title: 'Below',
            parent: 7,
          ).copyWith(subscription: project),
        ]);
        read.beforeRequest = (request) async {
          if (request == 'subscription project 7') {
            throw const NetworkFailure(NetworkProblem.unreachable);
          }
        };

        await expectLater(
          repository.setProjectSubscribed(7, subscribed: false),
          throwsA(isA<NetworkFailure>()),
        );
        expect(write.requests, ['unsubscribe project 7']);
        expect(await storedForProject(), isNull);
        expect((await db.projectsDao.loadProject(8))!.subscription, isNull);
      },
    );

    test('unfollowing a task followed through a project not known here as '
        'followed yet records the opt-out', () async {
      final repository = recording();
      read.taskSubscriptions[1] = project;

      expect(await repository.forTask(1), project);
      expect(await storedForProject(), project);
      await repository.setTaskSubscribed(1, subscribed: false);

      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.optedOut,
      });
    });

    test("a project's toggle also stores its state for the subprojects "
        'covered through it', () async {
      final repository = recording();
      await db.projectsDao.upsertAll([
        sampleProject(id: 7, title: 'Work').copyWith(subscription: project),
        sampleProject(
          id: 8,
          title: 'Below',
          parent: 7,
        ).copyWith(subscription: project),
      ]);

      await repository.setProjectSubscribed(7, subscribed: false);

      expect((await db.projectsDao.loadProject(8))!.subscription, isNull);
    });

    test("without a subscriber id no task's is recorded; the project's still "
        'is', () async {
      final repository = recording(subscriberId: null);
      read
        ..taskSubscriptions[1] = ownTask
        ..projectSubscriptions[7] = project;

      await repository.forTask(1);
      await repository.setTaskSubscribed(1, subscribed: true);
      await repository.forProject(7);

      expect(await db.tasksDao.ownSubscriptions(), isEmpty);
      expect(await storedForProject(), project);
    });

    test("a project's read and toggles store its state; a toggle starts one "
        'quiet refresh for its subprojects', () async {
      final repository = recording();
      read.projectSubscriptions[7] = project;

      await repository.forProject(7);
      expect(await storedForProject(), project);
      expect(refreshes, 0);

      await repository.setProjectSubscribed(7, subscribed: false);
      expect(await storedForProject(), isNull);
      expect(refreshes, 1);

      refresh = () async =>
          throw const NetworkFailure(NetworkProblem.unreachable);
      await repository.setProjectSubscribed(7, subscribed: true);
      await pumpEventQueue();
      expect(await storedForProject(), project);
      expect(refreshes, 2, reason: 'its failure only logged');
    });

    test('a recording failure, or a task not stored here, does not fail the '
        'call', () async {
      final repository = recording();
      read
        ..taskSubscriptions[1] = ownTask
        ..taskSubscriptions[2] = ownTask
        ..projectSubscriptions[7] = project;
      await db.customStatement(
        'CREATE TRIGGER no_task_state BEFORE UPDATE OF own_subscription '
        "ON tasks BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await db.customStatement(
        'CREATE TRIGGER no_project_state BEFORE UPDATE OF subscribed_via '
        "ON projects BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      expect(await repository.forTask(1), ownTask);
      expect(await repository.forTask(2), ownTask);
      expect(await repository.setTaskSubscribed(1, subscribed: true), ownTask);
      expect(await repository.forProject(7), project);
      expect(
        await repository.setProjectSubscribed(7, subscribed: false),
        isNull,
      );

      expect(await db.tasksDao.ownSubscriptions(), isEmpty);
      expect(await db.tasksDao.findRow(2), isNull);
      expect(await storedForProject(), isNull);
      expect(refreshes, 1);
    });
  });
}
