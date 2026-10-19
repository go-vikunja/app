import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/local/local_task_details_repository.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';

import '../../helpers/fake_sync_client.dart';
import '../../helpers/fake_write_client.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient read;
  late FakeWriteClient write;
  late LocalTaskDetailsRepository repository;
  const anna = User(id: 9, username: 'anna', name: 'Anna');
  final noon = DateTime.utc(2026, 10, 12, 12);

  setUp(() async {
    db = testDatabase();
    read = FakeSyncClient();
    write = FakeWriteClient();
    repository = LocalTaskDetailsRepository(db, read, write);
    read.allTasks = [sampleTask(id: 1, title: 'One', projectId: 7)];
    await db.tasksDao.upsertAll(read.allTasks);
  });

  test('the details come from one read of the server', () async {
    final details = TaskDetails(
      attachments: [sampleAttachment(id: 3)],
      coverImageAttachmentId: 3,
      reactions: const {
        '👍': [anna],
      },
      commentCount: 2,
      isUnread: true,
      subscription: const Subscription(
        entity: SubscriptionEntity.project,
        entityId: 7,
      ),
    );
    read.taskDetails[1] = details;

    expect(await repository.details(1), same(details));
    expect(read.requests, ['task details 1']);
  });

  test('a page of comments is sorted by created, then id, also within the '
      'second the server cannot tell apart', () async {
    read.taskComments[1] = [
      sampleComment(id: 5, created: noon),
      sampleComment(id: 4, created: noon.add(const Duration(minutes: 1))),
      sampleComment(id: 6, created: noon),
      sampleComment(id: 3, created: noon),
      sampleComment(id: 2, created: noon.subtract(const Duration(days: 1))),
    ];

    final oldestFirst = await repository.comments(1);
    final newestFirst = await repository.comments(1, newestFirst: true);

    expect(oldestFirst.items.map((comment) => comment.id), [2, 3, 5, 6, 4]);
    // The server keeps the ties in ascending id order in both directions.
    expect(newestFirst.items.map((comment) => comment.id), [4, 6, 5, 3, 2]);
    expect(read.requests, ['comments 1 page 1 asc', 'comments 1 page 1 desc']);
  });

  test('the paging of the server comes through', () async {
    read = FakeSyncClient(maxPerPage: 2);
    repository = LocalTaskDetailsRepository(db, read, write);
    read
      ..allTasks = [sampleTask(id: 1, title: 'One')]
      ..taskComments[1] = [
        for (var id = 1; id <= 5; id++) sampleComment(id: id),
      ];

    final first = await repository.comments(1);
    final last = await repository.comments(1, page: 3);

    expect(first.items.map((comment) => comment.id), [1, 2]);
    expect(first.hasMore, isTrue);
    expect(first.total, 5);
    expect(last.items.map((comment) => comment.id), [5]);
    expect(last.hasMore, isFalse);
  });

  test('marking read goes straight to the server', () async {
    await repository.markRead(1);

    expect(write.requests, ['markRead 1']);
  });

  test('a task created here goes by its server id once its create was '
      'answered', () async {
    await db
        .into(db.taskIdRemaps)
        .insert(
          TaskIdRemapRow(localId: -4, serverId: 1, at: DateTime.utc(2026)),
        );

    await repository.details(-4);
    await repository.comments(-4);
    await repository.markRead(-4);

    expect(read.requests, ['task details 1', 'comments 1 page 1 asc']);
    expect(write.requests, ['markRead 1']);
  });

  test('a task whose create was not answered is not on the server yet: no '
      'request', () async {
    await expectLater(repository.details(-5), throwsA(isA<TaskNotSyncedYet>()));
    await expectLater(
      repository.comments(-5),
      throwsA(isA<TaskNotSyncedYet>()),
    );
    await expectLater(
      repository.markRead(-5),
      throwsA(isA<TaskNotSyncedYet>()),
    );
    expect(read.requests, isEmpty);
    expect(write.requests, isEmpty);
  });

  test('failures propagate: offline, gone, comments disabled', () async {
    await expectLater(repository.details(2), throwsA(isA<NotFound>()));

    read.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);
    write.beforeRequest = read.beforeRequest;
    await expectLater(repository.details(1), throwsA(isA<NetworkFailure>()));
    await expectLater(repository.comments(1), throwsA(isA<NetworkFailure>()));
    await expectLater(repository.markRead(1), throwsA(isA<NetworkFailure>()));

    read.beforeRequest = (request) async {
      if (request.startsWith('comments')) throw const NotFound();
    };
    await expectLater(
      repository.comments(1),
      throwsA(
        isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', true),
      ),
    );
  });
}
