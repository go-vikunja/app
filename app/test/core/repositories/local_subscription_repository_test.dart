import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
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
}
