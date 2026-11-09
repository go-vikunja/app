import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart' show OwnTaskSubscription;
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
    final row = (await db.tasksDao.find(1))!;
    expect(row.commentCount, 2);
    expect(row.isUnread, isTrue);
  });

  test('a details read corrects a row the sync could not: read elsewhere, '
      'comments gone', () async {
    await db.tasksDao.storeCommentState(1, commentCount: 4, isUnread: true);
    read.taskDetails[1] = const TaskDetails(commentCount: 3);

    await repository.details(1);

    final row = (await db.tasksDao.find(1))!;
    expect(row.commentCount, 3);
    expect(row.isUnread, isFalse);
  });

  group("the user's own subscription (D80)", () {
    const alice = 7;
    const followWork = Subscription(
      entity: SubscriptionEntity.project,
      entityId: 7,
    );

    setUp(() async {
      await db.projectsDao.upsertAll([
        sampleProject(id: 7, title: 'Work').copyWith(subscription: followWork),
      ]);
    });

    test('with a subscriber id each details read records it, judged with '
        'the stored project', () async {
      repository = LocalTaskDetailsRepository(
        db,
        read,
        write,
        subscriberId: alice,
      );
      read.taskDetails[1] = const TaskDetails(subscription: followWork);

      await repository.details(1);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.none,
      });

      read.taskDetails[1] = const TaskDetails();
      await repository.details(1);
      expect(await db.tasksDao.ownSubscriptions(), {
        1: OwnTaskSubscription.optedOut,
      });
    });

    test('without one nothing is recorded', () async {
      read.taskDetails[1] = const TaskDetails();

      await repository.details(1);

      expect(await db.tasksDao.ownSubscriptions(), isEmpty);
    });

    test('a recording failure, or a task not stored here, does not fail the '
        'read', () async {
      repository = LocalTaskDetailsRepository(
        db,
        read,
        write,
        subscriberId: alice,
      );
      read.allTasks = [...read.allTasks, sampleTask(id: 2, title: 'Two')];
      const details = TaskDetails(commentCount: 2, subscription: followWork);
      read
        ..taskDetails[1] = details
        ..taskDetails[2] = details;
      await db.customStatement(
        'CREATE TRIGGER no_task_state BEFORE UPDATE OF own_subscription '
        "ON tasks BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );

      expect(await repository.details(1), same(details));
      expect(await repository.details(2), same(details));

      expect((await db.tasksDao.find(1))!.commentCount, 2);
      expect(await db.tasksDao.ownSubscriptions(), isEmpty);
      expect(await db.tasksDao.findRow(2), isNull);
    });
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

  test('marking read clears the flag of the row at once, then on the '
      'server', () async {
    await db.tasksDao.storeCommentState(1, commentCount: 2, isUnread: true);
    final flags = <bool?>[];
    write.beforeRequest = (_) async =>
        flags.add((await db.tasksDao.find(1))?.isUnread);

    await repository.markRead(1);

    expect(write.requests, ['markRead 1']);
    expect(flags, [false]);
    expect((await db.tasksDao.find(1))!.commentCount, 2);
  });

  test('a failed mark read leaves the row read: the next details read '
      'says otherwise', () async {
    await db.tasksDao.storeCommentState(1, isUnread: true);
    write.beforeRequest = (_) async =>
        throw const NetworkFailure(NetworkProblem.unreachable);

    await expectLater(repository.markRead(1), throwsA(isA<NetworkFailure>()));

    expect((await db.tasksDao.find(1))!.isUnread, isFalse);
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

  group('comments', () {
    const me = User(id: 1, username: 'me', name: 'Me');

    setUp(() {
      write
        ..serverTasks[1] = read.allTasks.single
        ..commenter = me;
    });

    test('a new comment goes to the server as written and counts on the '
        'row', () async {
      final comment = await repository.addComment(
        1,
        const CommentDraft('<p>Done &amp; dusted</p>'),
      );

      expect(write.requests, ['create comment 1']);
      expect(comment.html, '<p>Done &amp; dusted</p>');
      expect(comment.author, me);
      expect(write.serverComments[1], [comment]);
      expect((await db.tasksDao.find(1))!.commentCount, 1);
    });

    test('a draft without content never leaves the app', () async {
      for (final html in ['', '  ', '<p></p>', ' <p></p>\n']) {
        await expectLater(
          repository.addComment(1, CommentDraft(html)),
          throwsArgumentError,
        );
        await expectLater(
          repository.editComment(1, sampleComment(id: 4), CommentDraft(html)),
          throwsArgumentError,
        );
      }
      expect(write.requests, isEmpty);
    });

    test('an edit keeps the author, the creation and the reactions the '
        'answer leaves out', () async {
      final noonish = DateTime.utc(2026, 10, 20, 9);
      final mine = sampleComment(
        id: 4,
        author: me,
        created: noonish,
        reactions: const {
          '👍': [anna],
        },
      );
      write.serverComments[1] = [mine];

      final edited = await repository.editComment(
        1,
        mine,
        const CommentDraft('<p>Better</p>'),
      );

      expect(write.requests, ['update comment 1 4']);
      expect(edited.html, '<p>Better</p>');
      expect(edited.author, me);
      expect(edited.created, noonish);
      expect(edited.updated, isNot(noonish));
      expect(edited.reactions, mine.reactions);
    });

    test("someone else's comment is not ours to change", () async {
      final theirs = sampleComment(id: 4);
      write.serverComments[1] = [theirs];

      await expectLater(
        repository.editComment(1, theirs, const CommentDraft('<p>No</p>')),
        throwsA(isA<Forbidden>()),
      );
      await expectLater(
        repository.deleteComment(1, 4),
        throwsA(isA<Forbidden>()),
      );
      expect(write.serverComments[1], [theirs]);
    });

    test('a deletion counts down on the row, never below 0, also for a '
        'comment that was gone already', () async {
      write.serverComments[1] = [sampleComment(id: 4, author: me)];
      await db.tasksDao.storeCommentState(1, commentCount: 1);

      await repository.deleteComment(1, 4);
      await repository.deleteComment(1, 4);

      expect(write.requests, ['delete comment 1 4', 'delete comment 1 4']);
      expect(write.serverComments[1], isEmpty);
      expect((await db.tasksDao.find(1))!.commentCount, 0);
    });

    test('a task created here writes under its server id, one not sent yet '
        'not at all', () async {
      await db
          .into(db.taskIdRemaps)
          .insert(
            TaskIdRemapRow(localId: -4, serverId: 1, at: DateTime.utc(2026)),
          );

      await repository.addComment(-4, const CommentDraft('<p>Hi</p>'));
      await expectLater(
        repository.addComment(-5, const CommentDraft('<p>Hi</p>')),
        throwsA(isA<TaskNotSyncedYet>()),
      );
      await expectLater(
        repository.deleteComment(-5, 4),
        throwsA(isA<TaskNotSyncedYet>()),
      );

      expect(write.requests, ['create comment 1']);
    });

    test('a failed write changes nothing here', () async {
      write.beforeRequest = (_) async =>
          throw const DomainError(412, code: 3008);

      await expectLater(
        repository.addComment(1, const CommentDraft('<p>Hi</p>')),
        throwsA(isA<DomainError>()),
      );

      expect((await db.tasksDao.find(1))!.commentCount, 0);
    });
  });

  group('reactions', () {
    setUp(() async {
      await db
          .into(db.taskIdRemaps)
          .insert(
            TaskIdRemapRow(localId: -4, serverId: 1, at: DateTime.utc(2026)),
          );
    });

    test('a task by its server id, a comment by its own id', () async {
      await repository.addReaction(ReactionEntity.task, -4, '👍');
      await repository.addReaction(ReactionEntity.comment, 9, '🎉');
      await repository.removeReaction(ReactionEntity.task, 1, '👍');
      await repository.removeReaction(ReactionEntity.comment, 9, '🎉');

      expect(write.requests, [
        'react tasks 1 👍',
        'react comments 9 🎉',
        'unreact tasks 1 👍',
        'unreact comments 9 🎉',
      ]);
    });

    test('an added value is 1 to 20 code points; a longer one stored by v1 '
        'can still go', () async {
      final family = '👨‍👩‍👧‍👦' * 2;
      await repository.addReaction(ReactionEntity.task, 1, 'x' * 20);
      await repository.addReaction(ReactionEntity.task, 1, family);
      expect(family.runes.length, 14);

      for (final value in ['', 'x' * 21, '😀' * 21]) {
        await expectLater(
          repository.addReaction(ReactionEntity.task, 1, value),
          throwsArgumentError,
        );
      }
      await repository.removeReaction(ReactionEntity.task, 1, 'x' * 21);

      expect(write.requests, [
        'react tasks 1 ${'x' * 20}',
        'react tasks 1 $family',
        'unreact tasks 1 ${'x' * 21}',
      ]);
    });

    test('a task not sent yet cannot get one', () async {
      await expectLater(
        repository.addReaction(ReactionEntity.task, -5, '👍'),
        throwsA(isA<TaskNotSyncedYet>()),
      );
      expect(write.requests, isEmpty);
    });
  });

  test('server changes are the newer updated times of the row, from a '
      'queued create on', () async {
    final local = await db.outboxDao.queueCreate(
      const NewTask(projectId: 7, title: 'Here'),
      now: noon,
    );
    final changes = <DateTime>[];
    final subscription = repository
        .watchServerChanges(local)
        .listen(changes.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    await db.outboxDao.completeCreate(
      (await db.outboxDao.nextInLine())!.id,
      sampleTask(id: 2, title: 'Here', projectId: 7, updated: noon),
      at: noon,
    );
    await pumpEventQueue();
    await db.tasksDao.storeCommentState(2, commentCount: 1);
    await pumpEventQueue();
    final later = noon.add(const Duration(minutes: 1));
    await db.tasksDao.upsertAll([
      sampleTask(id: 2, title: 'Here', projectId: 7, updated: later),
    ]);
    await pumpEventQueue();
    await db.tasksDao.upsertAll([
      sampleTask(id: 2, title: 'Here', projectId: 7, updated: noon),
    ]);
    await pumpEventQueue();

    expect(changes, [later]);
  });
}
