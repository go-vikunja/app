import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/task_details_controller.dart';

import '../../helpers/sample_data.dart';

void main() {
  group('TaskDetailsController', () {
    test('a read overtaken by a newer one is dropped', () async {
      final reads = <int, Completer<TaskDetails>>{};
      final controller = TaskDetailsController(
        read: (id) => (reads[id] = Completer()).future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);

      unawaited(controller.load(1).catchError((_) => const TaskDetails()));
      unawaited(controller.load(2));
      reads[2]!.complete(const TaskDetails(commentCount: 2));
      reads[1]!.completeError(const NetworkFailure(NetworkProblem.unreachable));
      await pumpEventQueue();

      expect(controller.id, 2);
      expect((controller.value as TaskDetailsLoaded).details.commentCount, 2);
    });

    test('marks an unread task read once, and only then', () async {
      final marked = <int>[];
      var details = const TaskDetails(isUnread: true);
      final controller = TaskDetailsController(
        read: (_) async => details,
        markRead: (id) async => marked.add(id),
      );
      addTearDown(controller.dispose);

      await controller.load(3);
      await pumpEventQueue();
      details = const TaskDetails();
      await controller.load(3);
      await pumpEventQueue();

      expect(marked, [3]);
    });

    test('a failure is the state and the returned error', () async {
      const offline = NetworkFailure(NetworkProblem.unreachable);
      final controller = TaskDetailsController(
        read: (_) async => throw offline,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);

      await expectLater(controller.load(1), throwsA(offline));
      expect((controller.value as TaskDetailsFailed).failure, offline);
    });

    test('attachment changes apply at once; a refresh keeps the details '
        'shown while it reads and when it fails', () async {
      final photo = sampleAttachment(id: 3);
      final pdf = sampleAttachment(id: 5, name: 'a.pdf');
      TaskDetails? read = TaskDetails(
        attachments: [photo],
        coverImageAttachmentId: 3,
        commentCount: 4,
      );
      final reading = <Completer<void>>[];
      final controller = TaskDetailsController(
        read: (_) async {
          final hold = Completer<void>();
          reading.add(hold);
          await hold.future;
          return read ??
              (throw const NetworkFailure(NetworkProblem.unreachable));
        },
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      TaskDetails shown() => (controller.value as TaskDetailsLoaded).details;

      unawaited(controller.load(1));
      reading.last.complete();
      await pumpEventQueue();

      controller
        ..addAttachment(pdf)
        ..addAttachment(pdf)
        ..addAttachment(sampleAttachment(id: 8, taskId: 2));
      expect(shown().attachments, [photo, pdf]);
      controller.setCover(5);
      expect(shown().coverImageAttachmentId, 5);
      controller.removeAttachment(5);
      expect(shown().attachments, [photo]);
      expect(shown().coverImageAttachmentId, 0);
      expect(shown().commentCount, 4);

      read = TaskDetails(attachments: [photo, pdf]);
      final refreshed = controller.refresh();
      expect(controller.value, isA<TaskDetailsLoaded>());
      reading.last.complete();
      await refreshed;
      expect(shown().attachments, [photo, pdf]);

      read = null;
      final failing = controller.refresh();
      reading.last.complete();
      await failing;
      expect(shown().attachments, [photo, pdf]);
    });
  });

  group('TaskDetailsController changes', () {
    const anna = User(id: 9, username: 'anna', name: 'Anna');

    test('reactions and the comment count apply at once and keep the '
        'rest', () async {
      final controller = TaskDetailsController(
        read: (_) async => TaskDetails(
          attachments: [sampleAttachment(id: 3)],
          commentCount: 1,
          maxPermission: Permission.write,
        ),
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      await controller.load(1);
      TaskDetails shown() => (controller.value as TaskDetailsLoaded).details;

      controller
        ..setReactions(const {
          '👍': [anna],
        })
        ..countComments(1)
        ..countComments(-1)
        ..countComments(-1)
        ..countComments(-1);

      expect(shown().reactions.keys, ['👍']);
      expect(shown().commentCount, 0);
      expect(shown().attachments, hasLength(1));
      expect(shown().maxPermission, Permission.write);
    });

    test('a refresh under way when a reaction changes is dropped and read '
        'again once the reaction is on the server', () async {
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      TaskDetails shown() => (controller.value as TaskDetailsLoaded).details;
      unawaited(controller.load(1));
      reads.last.complete(const TaskDetails());
      await pumpEventQueue();
      const thumbsUp = {
        '👍': [anna],
      };

      final stale = controller.refresh();
      final onServer = Completer<void>();
      final write = controller.writing(() async {
        controller.setReactions(thumbsUp);
        await onServer.future;
      });
      reads[1].complete(const TaskDetails());
      await stale;
      expect(shown().reactions, thumbsUp);

      unawaited(controller.refresh());
      expect(reads, hasLength(2));
      onServer.complete();
      await write;
      expect(reads, hasLength(3));
      reads.last.complete(
        const TaskDetails(reactions: thumbsUp, commentCount: 1),
      );
      await pumpEventQueue();
      expect(shown().commentCount, 1);
      expect(shown().reactions, thumbsUp);
    });

    test('a refresh under way when a comment is counted here is read again '
        'at once', () async {
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      TaskDetails shown() => (controller.value as TaskDetailsLoaded).details;
      unawaited(controller.load(1));
      reads.last.complete(const TaskDetails(commentCount: 1));
      await pumpEventQueue();

      final stale = controller.refresh();
      controller.countComments(1);
      expect(reads, hasLength(3));
      reads[1].complete(const TaskDetails(commentCount: 1));
      await stale;
      expect(shown().commentCount, 2);

      reads.last.complete(const TaskDetails(commentCount: 2));
      await pumpEventQueue();
      expect(shown().commentCount, 2);
    });

    test('a refresh that finds the task unread again marks it read', () async {
      final marked = <int>[];
      var details = const TaskDetails();
      final controller = TaskDetailsController(
        read: (_) async => details,
        markRead: (id) async => marked.add(id),
      );
      addTearDown(controller.dispose);
      await controller.load(4);
      expect(marked, isEmpty);

      details = const TaskDetails(commentCount: 1, isUnread: true);
      await controller.refresh();
      await pumpEventQueue();

      expect(marked, [4]);
    });
  });

  group('CommentsController', () {
    late List<String> calls;
    late List<TaskComment> all;

    CommentsController create({int perPage = 2}) {
      final controller = CommentsController(
        read: (taskId, {required page, required newestFirst}) async {
          calls.add('$taskId $page ${newestFirst ? 'newest' : 'oldest'}');
          final ordered = newestFirst ? all.reversed.toList() : all;
          final start = (page - 1) * perPage;
          return Page(
            items: ordered.skip(start).take(perPage).toList(),
            page: page,
            perPage: perPage,
            totalPages: (ordered.length / perPage).ceil(),
          );
        },
      );
      addTearDown(controller.dispose);
      return controller;
    }

    setUp(() {
      calls = [];
      all = [for (var id = 1; id <= 3; id++) sampleComment(id: id)];
    });

    test('reads nothing until shown, then page by page', () async {
      final controller = create()..forTask(5);
      expect(calls, isEmpty);

      await controller.show();
      expect(controller.value.comments.map((comment) => comment.id), [1, 2]);
      expect(controller.value.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.value.comments.map((comment) => comment.id), [1, 2, 3]);
      expect(controller.value.hasMore, isFalse);
      expect(calls, ['5 1 oldest', '5 2 oldest']);
    });

    test(
      'a comment that moved to the next page meanwhile shows once',
      () async {
        final controller = create()..forTask(5);
        await controller.show();
        all = [sampleComment(id: 0), ...all];

        await controller.loadMore();

        expect(controller.value.comments.map((comment) => comment.id), [
          1,
          2,
          3,
        ]);
      },
    );

    test('the settings order applies until the user turns it', () async {
      final controller = create()
        ..forTask(5)
        ..useDefaultOrder(newestFirst: true);
      await controller.show();
      expect(calls, ['5 1 newest']);

      await controller.toggleOrder();
      controller.useDefaultOrder(newestFirst: true);

      expect(controller.value.newestFirst, isFalse);
      expect(controller.value.comments.first.id, 1);
      expect(calls.last, '5 1 oldest');
    });

    test('a new task id starts over, keeping the order', () async {
      final controller = create()
        ..forTask(5)
        ..useDefaultOrder(newestFirst: true);
      await controller.show();

      controller.forTask(6);

      expect(controller.value.shown, isFalse);
      expect(controller.value.comments, isEmpty);
      expect(controller.value.newestFirst, isTrue);
    });

    test('a failed page keeps the ones before and retries', () async {
      var fail = false;
      final controller = CommentsController(
        read: (taskId, {required page, required newestFirst}) async {
          if (fail) throw const NetworkFailure(NetworkProblem.unreachable);
          return Page(
            items: [sampleComment(id: page)],
            page: page,
            perPage: 1,
            totalPages: 2,
          );
        },
      )..forTask(5);
      addTearDown(controller.dispose);
      await controller.show();
      fail = true;

      await controller.loadMore();
      expect(controller.value.failure, isA<NetworkFailure>());
      expect(controller.value.comments.map((comment) => comment.id), [1]);

      fail = false;
      await controller.retry();
      expect(controller.value.failure, isNull);
      expect(controller.value.comments.map((comment) => comment.id), [1, 2]);
    });

    List<int> ids(CommentsController controller) =>
        controller.value.comments.map((comment) => comment.id).toList();

    test('a comment written here goes first when newest first', () async {
      final controller = create()
        ..forTask(5)
        ..useDefaultOrder(newestFirst: true);
      await controller.show();
      expect(ids(controller), [3, 2]);

      all = [...all, sampleComment(id: 4)];
      await controller.add(all.last, wasEmpty: false);
      expect(ids(controller), [4, 3, 2]);

      // The server's next page repeats the one pushed down.
      await controller.loadMore();
      expect(ids(controller), [4, 3, 2, 1]);
      expect(calls.last, '5 2 newest');
    });

    test('oldest first it goes last once every page is shown, and waits '
        'for its page before that', () async {
      final controller = create()..forTask(5);
      await controller.show();

      all = [...all, sampleComment(id: 4)];
      await controller.add(all.last, wasEmpty: false);
      expect(ids(controller), [1, 2]);

      await controller.loadMore();
      expect(ids(controller), [1, 2, 3, 4]);

      all = [...all, sampleComment(id: 5)];
      await controller.add(all.last, wasEmpty: false);
      expect(ids(controller), [1, 2, 3, 4, 5]);
    });

    test('oldest first, a comment that opens a page stays through a '
        'refresh', () async {
      all = [sampleComment(id: 1), sampleComment(id: 2)];
      final controller = create()..forTask(5);
      await controller.show();
      expect(controller.value.hasMore, isFalse);

      all = [...all, sampleComment(id: 3)];
      await controller.add(all.last, wasEmpty: false);
      calls.clear();
      await controller.refreshLoaded();

      expect(calls, ['5 1 oldest', '5 2 oldest']);
      expect(ids(controller), [1, 2, 3]);
      expect(controller.value.hasMore, isFalse);
    });

    test('not shown yet: the first comment of an empty thread shows without '
        'a read, else the first page is read', () async {
      final empty = create()..forTask(5);
      await empty.add(sampleComment(id: 9), wasEmpty: true);
      expect(empty.value.shown, isTrue);
      expect(ids(empty), [9]);
      expect(calls, isEmpty);

      final filled = create()..forTask(6);
      await filled.add(sampleComment(id: 4), wasEmpty: false);
      expect(calls, ['6 1 oldest']);
      expect(filled.value.shown, isTrue);
    });

    test('an edit changes the text and the time, nothing else', () async {
      const anna = User(id: 9, username: 'anna', name: 'Anna');
      all = [
        sampleComment(
          id: 1,
          reactions: const {
            '👍': [anna],
          },
        ),
      ];
      final controller = create()..forTask(5);
      await controller.show();
      final before = controller.value.comments.single;

      controller.applyEdit(
        TaskComment(
          id: 1,
          html: '<p>New</p>',
          author: const User(id: 0, username: ''),
          updated: DateTime.utc(2026, 10, 21, 12),
        ),
      );

      final after = controller.value.comments.single;
      expect(after.html, '<p>New</p>');
      expect(after.updated, DateTime.utc(2026, 10, 21, 12));
      expect(after.author, before.author);
      expect(after.created, before.created);
      expect(after.reactions, before.reactions);

      controller.setReactions(1, const {});
      expect(controller.value.comments.single.reactions, isEmpty);
    });

    test('after a deletion "Load more" reads the last page again so that '
        'nothing is skipped', () async {
      final controller = create()..forTask(5);
      await controller.show();

      all = all.where((comment) => comment.id != 1).toList();
      controller.remove(1);
      expect(ids(controller), [2]);

      await controller.loadMore();
      expect(calls, ['5 1 oldest', '5 1 oldest', '5 2 oldest']);
      expect(ids(controller), [2, 3]);
    });

    group('changes made here while the server is read', () {
      late List<Completer<void>> held;
      late CommentsController controller;
      const eyes = {
        '👀': [User(id: 9, username: 'anna', name: 'Anna')],
      };

      setUp(() async {
        held = [];
        var hold = false;
        controller = CommentsController(
          read: (taskId, {required page, required newestFirst}) async {
            // What the server had when it was asked.
            final ordered = [...all];
            if (hold) await (held..add(Completer())).last.future;
            final start = (page - 1) * 2;
            return Page(
              items: ordered.skip(start).take(2).toList(),
              page: page,
              perPage: 2,
              totalPages: (ordered.length / 2).ceil(),
            );
          },
        )..forTask(5);
        addTearDown(controller.dispose);
        await controller.show();
        hold = true;
      });

      Future<void> release() async {
        for (var i = 0; i < held.length; i++) {
          if (!held[i].isCompleted) held[i].complete();
          await pumpEventQueue();
        }
      }

      test('a deletion stays through a refresh that read before it', () async {
        final stale = controller.refreshLoaded();
        all = all.where((comment) => comment.id != 1).toList();
        controller.remove(1);
        held.first.complete();
        await stale;
        expect(ids(controller), [2]);

        await release();
        expect(held, hasLength(2));
        expect(ids(controller), [2, 3]);
      });

      test('a reaction stays through a refresh that read before it, which '
          'is read again once the reaction is on the server', () async {
        final stale = controller.refreshLoaded();
        final onServer = Completer<void>();
        final write = controller.writing(() async {
          controller.setReactions(2, eyes);
          await onServer.future;
        });
        held.first.complete();
        await stale;
        expect(controller.find(2)!.reactions, eyes);
        expect(held, hasLength(1));

        all = [all[0], all[1].copyWith(reactions: eyes), all[2]];
        onServer.complete();
        await write;
        expect(held, hasLength(2));
        await release();
        expect(controller.find(2)!.reactions, eyes);
      });

      test('a page arriving after a reaction or a deletion here keeps '
          'both', () async {
        final more = controller.loadMore();
        controller.setReactions(1, eyes);
        all = all.where((comment) => comment.id != 2).toList();
        controller.remove(2);
        await release();
        await more;

        expect(ids(controller), [1, 3]);
        expect(controller.find(1)!.reactions, eyes);
      });
    });

    test('the shown pages again, quietly; a failure keeps them', () async {
      var fail = false;
      final reads = <int>[];
      final controller = CommentsController(
        read: (taskId, {required page, required newestFirst}) async {
          reads.add(page);
          if (fail) throw const NetworkFailure(NetworkProblem.unreachable);
          final start = (page - 1) * 2;
          return Page(
            items: all.skip(start).take(2).toList(),
            page: page,
            perPage: 2,
            totalPages: (all.length / 2).ceil(),
          );
        },
      )..forTask(5);
      addTearDown(controller.dispose);
      await controller.refreshLoaded();
      expect(reads, isEmpty);

      await controller.show();
      await controller.loadMore();
      all = [sampleComment(id: 1, html: '<p>Edited</p>'), ...all.skip(2)];
      reads.clear();
      final states = <CommentsState>[];
      controller.addListener(() => states.add(controller.value));

      await controller.refreshLoaded();
      expect(reads, [1, 2]);
      expect(states.any((state) => state.loading), isFalse);
      expect(ids(controller), [1, 3]);
      expect(controller.value.comments.first.html, '<p>Edited</p>');

      fail = true;
      await controller.refreshLoaded();
      expect(ids(controller), [1, 3]);
    });
  });
}
