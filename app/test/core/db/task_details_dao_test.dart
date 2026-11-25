import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/daos/task_details_dao.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TaskDetailsDao dao;
  const anna = User(id: 9, username: 'anna', name: 'Anna');
  const ben = User(id: 10, username: 'ben');
  const me = User(id: 1, username: 'me', name: 'Me');
  final morning = DateTime.utc(2026, 11, 19, 8);
  final noon = DateTime.utc(2026, 11, 19, 12);

  setUp(() async {
    db = testDatabase();
    dao = db.taskDetailsDao;
    await db.tasksDao.upsertAll([
      sampleTask(id: 1, title: 'One'),
      sampleTask(id: 2, title: 'Two'),
    ]);
    await db.tasksDao.storeCommentState(1, commentCount: 3);
  });

  Future<Map<String, int>> rowCounts() async => {
    for (final table in [
      'task_detail_loads',
      'task_attachments',
      'task_reactions',
      'task_comments',
      'task_comment_reactions',
    ])
      table:
          (await db
                  .customSelect('SELECT COUNT(*) AS c FROM $table')
                  .getSingle())
              .read<int>('c'),
  };

  group('details', () {
    test('come back as stored: attachments in order with their creator, the '
        'cover, reactions in the order of their values and users, the '
        "row's comment count and the time of the read", () async {
      final pdf = sampleAttachment(
        id: 5,
        name: 'pass.pdf',
        mime: 'application/pdf',
        createdBy: ben,
      );
      final photo = sampleAttachment(id: 3, createdBy: null);
      await dao.storeDetails(
        1,
        TaskDetails(
          attachments: [pdf, photo],
          coverImageAttachmentId: 3,
          reactions: const {
            '🎉': [ben],
            '👍': [anna, me],
          },
          commentCount: 9,
          isUnread: true,
        ),
        at: morning,
      );

      final stored = (await dao.storedDetails(1))!;

      expect(stored.readAt, morning);
      expect(stored.value.attachments, [pdf, photo]);
      expect(stored.value.attachments.first.createdBy, ben);
      expect(stored.value.attachments.first.created, pdf.created);
      expect(stored.value.attachments.last.createdBy, isNull);
      expect(stored.value.coverImageAttachmentId, 3);
      expect(stored.value.reactions.keys, ['🎉', '👍']);
      expect(stored.value.reactions['👍'], [anna, me]);
      expect(stored.value.commentCount, 3);
      expect(stored.value.isUnread, isFalse);
      expect(await dao.storedDetails(2), isNull);
    });

    test('a later read replaces them all', () async {
      await dao.storeDetails(
        1,
        TaskDetails(
          attachments: [sampleAttachment(id: 3), sampleAttachment(id: 5)],
          coverImageAttachmentId: 3,
          reactions: const {
            '👍': [anna],
          },
        ),
        at: morning,
      );
      await dao.storeDetails(
        1,
        TaskDetails(attachments: [sampleAttachment(id: 5)]),
        at: noon,
      );

      final stored = (await dao.storedDetails(1))!;
      expect(stored.readAt, noon);
      expect(stored.value.attachments.map((a) => a.id), [5]);
      expect(stored.value.coverImageAttachmentId, 0);
      expect(stored.value.reactions, isEmpty);
    });

    test('a task not stored here keeps nothing', () async {
      await dao.storeDetails(
        8,
        TaskDetails(attachments: [sampleAttachment(id: 3)]),
        at: morning,
      );

      expect(await dao.storedDetails(8), isNull);
      expect((await rowCounts()).values, everyElement(0));
    });

    test('attachment writes follow the server: added last, deleted with '
        'the cover they were, the cover set; none before a read', () async {
      await dao.addAttachment(1, sampleAttachment(id: 7));
      await dao.storeCover(1, 7);
      expect(await dao.storedDetails(1), isNull);

      await dao.storeDetails(
        1,
        TaskDetails(
          attachments: [sampleAttachment(id: 5), sampleAttachment(id: 3)],
          coverImageAttachmentId: 3,
        ),
        at: morning,
      );
      await dao.addAttachment(1, sampleAttachment(id: 4));
      await dao.addAttachment(1, sampleAttachment(id: 4));
      await dao.removeAttachment(1, 3);
      var stored = (await dao.storedDetails(1))!;
      expect(stored.value.attachments.map((a) => a.id), [5, 4]);
      expect(stored.value.coverImageAttachmentId, 0);
      expect(stored.readAt, morning);

      await dao.storeCover(1, 5);
      await dao.removeAttachment(1, 4);
      stored = (await dao.storedDetails(1))!;
      expect(stored.value.coverImageAttachmentId, 5);
      expect(await dao.storedAttachment(1, 5), sampleAttachment(id: 5));
      expect(await dao.storedAttachment(1, 4), isNull);
      expect(await dao.storedAttachment(2, 5), isNull);
    });

    test("the task's reactions follow a write: the user last in a value, a "
        'new value last, an empty one gone; none before a read', () async {
      await dao.toggleReaction(ReactionEntity.task, 1, '👍', me, add: true);
      expect(await dao.storedDetails(1), isNull);

      await dao.storeDetails(
        1,
        const TaskDetails(
          reactions: {
            '👍': [anna],
            '🎉': [ben],
          },
        ),
        at: morning,
      );
      await dao.toggleReaction(ReactionEntity.task, 1, '👍', me, add: true);
      await dao.toggleReaction(ReactionEntity.task, 1, '👍', me, add: true);
      await dao.toggleReaction(ReactionEntity.task, 1, '🚀', me, add: true);
      await dao.toggleReaction(ReactionEntity.task, 1, '🎉', ben, add: false);

      expect((await dao.storedDetails(1))!.value.reactions, {
        '👍': [anna, me],
        '🚀': [me],
      });
    });
  });

  group('comments', () {
    test('a first page replaces what is stored, a later one joins it; they '
        'come back oldest first with their authors and reactions', () async {
      final early = DateTime.utc(2026, 10, 1, 9);
      await dao.storeComments(
        1,
        [sampleComment(id: 1), sampleComment(id: 2)],
        replace: true,
        at: morning,
      );
      await dao.storeComments(
        1,
        [
          sampleComment(
            id: 7,
            created: early,
            author: ben,
            reactions: const {
              '❤️': [anna, me],
              '👍': [ben],
            },
          ),
          sampleComment(id: 6, created: early),
          sampleComment(id: 4, html: '<p>Done</p>'),
        ],
        replace: true,
        at: noon,
      );
      await dao.storeComments(
        1,
        [sampleComment(id: 9), sampleComment(id: 4, html: '<p>Done!</p>')],
        replace: false,
        at: noon,
      );

      final stored = (await dao.storedComments(1))!;
      expect(stored.readAt, noon);
      expect(stored.value.map((c) => c.id), [6, 7, 4, 9]);
      final seven = stored.value[1];
      expect(
        seven,
        sampleComment(
          id: 7,
          created: early,
          author: ben,
          reactions: const {
            '❤️': [anna, me],
            '👍': [ben],
          },
        ),
      );
      expect(seven.reactions.keys, ['❤️', '👍']);
      expect(stored.value[2].html, '<p>Done!</p>');
      expect(await dao.storedComments(2), isNull);
      expect(await dao.storedDetails(1), isNull);
    });

    test('a page read again keeps its comments once, with their reactions '
        'as read', () async {
      final liked = sampleComment(
        id: 4,
        reactions: const {
          '👍': [anna],
        },
      );
      await dao.storeComments(1, [liked], replace: true, at: morning);
      await dao.storeComments(
        1,
        [liked.copyWith(reactions: const {})],
        replace: false,
        at: noon,
      );

      expect((await dao.storedComments(1))!.value, [
        liked.copyWith(reactions: const {}),
      ]);
      expect((await rowCounts())['task_comment_reactions'], 0);
    });

    test('writes follow the server: a new comment joins stored ones only, an '
        'edit keeps the reactions, a deletion takes them along', () async {
      await dao.putComment(1, sampleComment(id: 3));
      expect(await dao.storedComments(1), isNull);

      final liked = sampleComment(
        id: 4,
        reactions: const {
          '👍': [anna],
        },
      );
      await dao.storeComments(1, [liked], replace: true, at: morning);
      await dao.putComment(1, sampleComment(id: 5, author: me));
      await dao.editComment(1, 4, html: '<p>Better</p>', updated: noon);
      var stored = (await dao.storedComments(1))!;
      expect(stored.value.map((c) => c.id), [4, 5]);
      expect(stored.value.first.html, '<p>Better</p>');
      expect(stored.value.first.updated, noon);
      expect(stored.value.first.reactions, liked.reactions);
      expect(stored.readAt, morning);

      await dao.removeComment(1, 4);
      stored = (await dao.storedComments(1))!;
      expect(stored.value.map((c) => c.id), [5]);
      expect((await rowCounts())['task_comment_reactions'], 0);
    });

    test("a comment's reactions follow a write by the comment's id; one "
        'not stored is left alone', () async {
      await dao.storeComments(
        1,
        [
          sampleComment(
            id: 4,
            reactions: const {
              '👍': [anna],
            },
          ),
        ],
        replace: true,
        at: morning,
      );

      await dao.toggleReaction(ReactionEntity.comment, 4, '👍', me, add: true);
      await dao.toggleReaction(ReactionEntity.comment, 4, '🎉', me, add: true);
      await dao.toggleReaction(
        ReactionEntity.comment,
        4,
        '👍',
        anna,
        add: false,
      );
      await dao.toggleReaction(ReactionEntity.comment, 8, '👍', me, add: true);

      expect((await dao.storedComments(1))!.value.single.reactions, {
        '👍': [me],
        '🎉': [me],
      });
      expect((await rowCounts())['task_comment_reactions'], 2);
    });
  });

  test('a read stores nothing once a write to what it would replace came '
      'after it started; reads stay apart from the other kind of write and '
      'from other tasks', () async {
    final photo = sampleAttachment(id: 3);
    final liked = sampleComment(
      id: 4,
      reactions: const {
        '👍': [anna],
      },
    );
    await dao.storeDetails(1, TaskDetails(attachments: [photo]), at: morning);
    await dao.storeComments(1, [liked], replace: true, at: morning);
    final writes = <(String, bool), Future<void> Function()>{
      ('comment reaction', false): () =>
          dao.toggleReaction(ReactionEntity.comment, 4, '🎉', me, add: true),
      ('new comment', false): () => dao.putComment(1, sampleComment(id: 5)),
      ('edit', false): () =>
          dao.editComment(1, 4, html: '<p>Edited</p>', updated: noon),
      ('deletion', false): () => dao.removeComment(1, 5),
      ('task reaction', true): () =>
          dao.toggleReaction(ReactionEntity.task, 1, '🎉', me, add: true),
      ('new attachment', true): () =>
          dao.addAttachment(1, sampleAttachment(id: 6)),
      ('cover', true): () => dao.storeCover(1, 3),
      ('attachment deletion', true): () => dao.removeAttachment(1, 6),
    };

    for (final MapEntry(key: (name, details), value: write) in writes.entries) {
      final detailsVersion = dao.detailsVersion(1);
      final commentsVersion = dao.commentsVersion(1);
      final otherTask = (dao.detailsVersion(2), dao.commentsVersion(2));
      await write();
      expect(dao.detailsVersion(1) != detailsVersion, details, reason: name);
      expect(dao.commentsVersion(1) != commentsVersion, !details, reason: name);
      expect((dao.detailsVersion(2), dao.commentsVersion(2)), otherTask);
    }

    final details = (await dao.storedDetails(1))!;
    final comments = (await dao.storedComments(1))!;
    await dao.storeDetails(
      1,
      const TaskDetails(),
      at: noon,
      version: dao.detailsVersion(1) - 1,
    );
    await dao.storeComments(
      1,
      const [],
      replace: true,
      at: noon,
      version: dao.commentsVersion(1) - 1,
    );
    final kept = (await dao.storedDetails(1))!;
    expect(kept.readAt, morning);
    expect(kept.value.attachments, details.value.attachments);
    expect(kept.value.coverImageAttachmentId, 3);
    expect(kept.value.reactions, details.value.reactions);
    expect(details.value.reactions, isNotEmpty);
    final keptComments = (await dao.storedComments(1))!;
    expect(keptComments.readAt, morning);
    expect(keptComments.value, comments.value);
    expect(comments.value, isNotEmpty);

    await dao.storeDetails(
      1,
      const TaskDetails(),
      at: noon,
      version: dao.detailsVersion(1),
    );
    await dao.storeComments(
      1,
      const [],
      replace: true,
      at: noon,
      version: dao.commentsVersion(1),
    );
    expect((await dao.storedDetails(1))!.value.attachments, isEmpty);
    expect((await dao.storedComments(1))!.value, isEmpty);
  });

  test('a comment count read across a comment written or deleted here does '
      'not hold, nor one read while it is on its way; one read after it '
      'does, also after a failed write', () async {
    final before = dao.commentsVersion(1);
    final sent = Completer<void>();
    final writing = dao.writingComment(1, () => sent.future);
    final during = dao.commentsVersion(1);

    expect(dao.commentCountHolds(1, before), isFalse);
    expect(dao.commentCountHolds(1, during), isFalse);
    expect(dao.commentCountHolds(2, dao.commentsVersion(2)), isTrue);

    sent.complete();
    await writing;
    expect(dao.commentCountHolds(1, before), isFalse);
    expect(dao.commentCountHolds(1, during), isFalse);
    expect(dao.commentCountHolds(1, dao.commentsVersion(1)), isTrue);

    final after = dao.commentsVersion(1);
    await expectLater(
      dao.writingComment<void>(
        1,
        () async => throw const NetworkFailure(NetworkProblem.unreachable),
      ),
      throwsA(isA<NetworkFailure>()),
    );
    expect(dao.commentCountHolds(1, after), isFalse);
    expect(dao.commentCountHolds(1, dao.commentsVersion(1)), isTrue);
  });

  test('everything stored goes with its task', () async {
    await dao.storeDetails(
      1,
      TaskDetails(
        attachments: [sampleAttachment(id: 3)],
        reactions: const {
          '👍': [anna],
        },
      ),
      at: morning,
    );
    await dao.storeComments(
      1,
      [
        sampleComment(
          id: 4,
          reactions: const {
            '👍': [anna],
          },
        ),
      ],
      replace: true,
      at: morning,
    );
    expect((await rowCounts()).values, everyElement(1));

    await (db.delete(db.tasks)..where((t) => t.id.equals(1))).go();

    expect((await rowCounts()).values, everyElement(0));
  });
}
