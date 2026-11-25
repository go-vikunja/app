import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/task_details_repository.dart'
    show StoredRead;
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

    test('a failed refresh that overtook the first read is the state, so '
        'Retry shows', () async {
      const offline = NetworkFailure(NetworkProblem.unreachable);
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);

      unawaited(controller.load(1).catchError((_) => const TaskDetails()));
      final refreshed = controller.refresh();
      reads[1].completeError(offline);
      await refreshed;

      expect((controller.value as TaskDetailsFailed).failure, offline);
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

    test('a file uploaded while the first read is under way drops it, which '
        'may not have the file: its answer shows with the file until the '
        'read after it answers; one of another task reads nothing '
        'again', () async {
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      final scan = sampleAttachment(id: 7, name: 'scan.pdf');
      unawaited(controller.load(1));

      controller.addAttachment(sampleAttachment(id: 8, taskId: 2));
      expect(reads, hasLength(1));
      controller.addAttachment(scan);
      expect(reads, hasLength(2));

      reads.first.complete(const TaskDetails(commentCount: 1));
      await pumpEventQueue();
      final early = controller.value as TaskDetailsLoaded;
      expect(early.details.attachments, [scan]);
      expect(early.details.commentCount, 1);
      expect(early.storedAt, isNull);

      reads.last.complete(TaskDetails(attachments: [scan], commentCount: 2));
      await pumpEventQueue();
      final shown = (controller.value as TaskDetailsLoaded).details;
      expect(shown.attachments, [scan]);
      expect(shown.commentCount, 2);
    });

    test('a file uploaded while the first read is under way still shows '
        'with that read when the read after it fails offline', () async {
      const offline = NetworkFailure(NetworkProblem.unreachable);
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      final photo = sampleAttachment(id: 3);
      final scan = sampleAttachment(id: 7, name: 'scan.pdf');
      unawaited(controller.load(1));
      controller.addAttachment(scan);
      expect(reads, hasLength(2));

      reads.first.complete(TaskDetails(attachments: [photo], commentCount: 4));
      reads.last.completeError(offline);
      await pumpEventQueue();

      final shown = controller.value as TaskDetailsLoaded;
      expect(shown.details.attachments, [photo, scan]);
      expect(shown.details.commentCount, 4);
      expect(shown.failure, isNull);
    });

    test("a dropped read's answer gets only the changes made after it "
        'began', () async {
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      final scan = sampleAttachment(id: 7, name: 'scan.pdf');
      unawaited(controller.load(1));
      controller
        ..countComments(1)
        ..addAttachment(scan);
      expect(reads, hasLength(3));

      reads[1].complete(const TaskDetails(commentCount: 1));
      await pumpEventQueue();

      final shown = (controller.value as TaskDetailsLoaded).details;
      expect(shown.attachments, [scan]);
      expect(shown.commentCount, 1);
    });

    test('a dropped read of an earlier opening never shows', () async {
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      unawaited(controller.load(1));
      controller.addAttachment(sampleAttachment(id: 7));
      unawaited(controller.load(1));
      expect(reads, hasLength(3));

      reads[0].complete(const TaskDetails(commentCount: 1));
      reads[1].complete(const TaskDetails(commentCount: 2));
      await pumpEventQueue();
      expect(controller.value, isA<TaskDetailsLoading>());

      reads[2].complete(const TaskDetails(commentCount: 3));
      await pumpEventQueue();
      expect((controller.value as TaskDetailsLoaded).details.commentCount, 3);
    });

    test('a file uploaded while a refresh runs after a failed first read '
        'drops that refresh too, whose answer shows with the file', () async {
      const offline = NetworkFailure(NetworkProblem.unreachable);
      final reads = <Completer<TaskDetails>>[];
      final controller = TaskDetailsController(
        read: (_) => (reads..add(Completer())).last.future,
        markRead: (_) async {},
      );
      addTearDown(controller.dispose);
      final scan = sampleAttachment(id: 7, name: 'scan.pdf');
      final loading = controller.load(1);
      reads.single.completeError(offline);
      await expectLater(loading, throwsA(offline));
      expect(controller.value, isA<TaskDetailsFailed>());

      final refreshing = controller.refresh();
      controller.addAttachment(scan);
      expect(reads, hasLength(3));

      reads[1].complete(const TaskDetails());
      await refreshing;
      expect((controller.value as TaskDetailsLoaded).details.attachments, [
        scan,
      ]);

      reads[2].complete(TaskDetails(attachments: [scan]));
      await pumpEventQueue();
      expect((controller.value as TaskDetailsLoaded).details.attachments, [
        scan,
      ]);
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

    test('oldest first it goes last, after the pages not read yet, which '
        'are read for it', () async {
      all = [for (var id = 1; id <= 5; id++) sampleComment(id: id)];
      final controller = create()..forTask(5);
      await controller.show();
      expect(ids(controller), [1, 2]);

      all = [...all, sampleComment(id: 6)];
      await controller.add(all.last, wasEmpty: false);
      expect(ids(controller), [1, 2, 3, 4, 5, 6]);
      expect(calls, ['5 1 oldest', '5 2 oldest', '5 3 oldest']);
      expect(controller.value.hasMore, isFalse);
      expect(controller.value.loadedPages, 3);
      expect(controller.value.loading, isFalse);

      calls.clear();
      all = [...all, sampleComment(id: 7)];
      await controller.add(all.last, wasEmpty: false);
      expect(ids(controller), [1, 2, 3, 4, 5, 6, 7]);
      expect(calls, isEmpty);
    });

    test('oldest first after a deletion, reading on to a comment written '
        'here skips nothing', () async {
      all = [for (var id = 1; id <= 5; id++) sampleComment(id: id)];
      final controller = create()..forTask(5);
      await controller.show();
      all = all.where((comment) => comment.id != 1).toList();
      controller.remove(1);

      all = [...all, sampleComment(id: 6)];
      await controller.add(all.last, wasEmpty: false);

      expect(ids(controller), [2, 3, 4, 5, 6]);
      expect(calls, ['5 1 oldest', '5 1 oldest', '5 2 oldest', '5 3 oldest']);
    });

    test('a page that comes back empty while the server still says there '
        'are more ends the reading', () async {
      final controller = CommentsController(
        read: (taskId, {required page, required newestFirst}) async {
          calls.add('$page');
          return Page(
            items: page == 1 ? [sampleComment(id: 1)] : const [],
            page: page,
            perPage: 1,
            totalPages: 99,
          );
        },
      )..forTask(5);
      addTearDown(controller.dispose);
      await controller.show();

      await controller.add(sampleComment(id: 2), wasEmpty: false);

      expect(calls, ['1', '2']);
      expect(controller.value.loading, isFalse);
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
        'a read, else the thread is read up to it', () async {
      final empty = create()..forTask(5);
      await empty.add(sampleComment(id: 9), wasEmpty: true);
      expect(empty.value.shown, isTrue);
      expect(ids(empty), [9]);
      expect(calls, isEmpty);

      final filled = create()..forTask(6);
      await filled.add(sampleComment(id: 4), wasEmpty: false);
      expect(calls, ['6 1 oldest', '6 2 oldest']);
      expect(filled.value.shown, isTrue);
      expect(ids(filled), [1, 2, 3]);

      calls.clear();
      final newestFirst = create()
        ..forTask(7)
        ..useDefaultOrder(newestFirst: true);
      await newestFirst.add(sampleComment(id: 4), wasEmpty: false);
      expect(calls, ['7 1 newest']);
      expect(ids(newestFirst), [3, 2]);
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

      test('a reaction here while a later page loads reads the pages again '
          'once it is on the server', () async {
        final more = controller.loadMore();
        final onServer = Completer<void>();
        final write = controller.writing(() async {
          controller.setReactions(1, eyes);
          await onServer.future;
        });
        await release();
        await more;
        expect(ids(controller), [1, 2, 3]);
        expect(held, hasLength(1));

        all = [all[0].copyWith(reactions: eyes), ...all.skip(1)];
        onServer.complete();
        await write;
        await release();
        expect(held, hasLength(3));
        expect(controller.find(1)!.reactions, eyes);
      });

      test('a page arriving after a reaction or a deletion here keeps '
          'both; the pages are read again once the reaction is on the '
          'server', () async {
        final more = controller.loadMore();
        final onServer = Completer<void>();
        final write = controller.writing(() async {
          controller.setReactions(1, eyes);
          await onServer.future;
        });
        all = all.where((comment) => comment.id != 2).toList();
        controller.remove(2);
        await release();
        await more;

        expect(ids(controller), [1, 3]);
        expect(controller.find(1)!.reactions, eyes);
        expect(held, hasLength(1));

        all = [all[0].copyWith(reactions: eyes), ...all.skip(1)];
        onServer.complete();
        await write;
        await release();
        expect(held, hasLength(3));
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

  group('stored details and comments', () {
    const offline = NetworkFailure(NetworkProblem.unreachable);
    // What a captive portal, a failing proxy or a server in trouble answers.
    const passing = <VikunjaFailure>[
      offline,
      ServerFailure(502),
      RateLimited(),
      UnexpectedResponse(200),
      NotJsonResponse(200, message: 'text/html'),
      RefreshRaceLost(),
      TokenRejected(),
    ];
    const final_ = <VikunjaFailure>[NotFound(code: 4002), Forbidden()];
    final morning = DateTime.utc(2026, 11, 19, 8);
    final storedDetails = TaskDetails(
      attachments: [sampleAttachment(id: 3, name: 'pass.pdf')],
      commentCount: 2,
    );
    List<int> idsOf(CommentsController controller) => [
      for (final comment in controller.value.comments) comment.id,
    ];

    group('TaskDetailsController', () {
      late List<Completer<TaskDetails>> reads;
      late Completer<StoredRead<TaskDetails>?> stored;
      late TaskDetailsController controller;

      setUp(() {
        reads = [];
        stored = Completer();
        controller = TaskDetailsController(
          read: (_) => (reads..add(Completer())).last.future,
          markRead: (_) async {},
          stored: (_) => stored.future,
        );
        addTearDown(controller.dispose);
      });

      TaskDetailsLoaded shown() => controller.value as TaskDetailsLoaded;

      test('what is stored shows while the read runs and gives way to its '
          'answer', () async {
        unawaited(controller.load(1));
        stored.complete((value: storedDetails, readAt: morning));
        await pumpEventQueue();

        expect(shown().details, same(storedDetails));
        expect(shown().storedAt, morning);
        expect(shown().failure, isNull);

        const answer = TaskDetails(commentCount: 3);
        reads.last.complete(answer);
        await pumpEventQueue();

        expect(shown().details, same(answer));
        expect(shown().storedAt, isNull);
      });

      test('offline it stays with the failure, also when that comes first; '
          'Retry keeps it while it reads', () async {
        unawaited(controller.load(1).catchError((_) => storedDetails));
        reads.last.completeError(offline);
        await pumpEventQueue();
        expect(controller.value, isA<TaskDetailsFailed>());

        stored.complete((value: storedDetails, readAt: morning));
        await pumpEventQueue();
        expect(shown().details, same(storedDetails));
        expect(shown().failure, offline);

        final states = <TaskDetailsState>[];
        controller.addListener(() => states.add(controller.value));
        unawaited(controller.load(1).catchError((_) => storedDetails));
        await pumpEventQueue();
        expect(shown().storedAt, morning);
        expect(shown().failure, isNull);

        reads.last.completeError(offline);
        await pumpEventQueue();
        expect(shown().failure, offline);
        expect(states, everyElement(isA<TaskDetailsLoaded>()));
      });

      test('they stay with every failure that may pass, whichever comes '
          'first', () async {
        stored.complete((value: storedDetails, readAt: morning));
        for (final failure in passing) {
          unawaited(controller.load(1).catchError((_) => storedDetails));
          reads.last.completeError(failure);
          await pumpEventQueue();
          expect(shown().details, same(storedDetails), reason: '$failure');
          expect(shown().storedAt, morning, reason: '$failure');
          expect(shown().failure, failure, reason: '$failure');

          final refreshed = controller.refresh();
          reads.last.completeError(failure);
          await refreshed;
          expect(shown().failure, failure, reason: '$failure');
        }
      });

      test('they stay when the read failed for a reason that may pass before '
          'they were read', () async {
        unawaited(controller.load(1).catchError((_) => storedDetails));
        reads.last.completeError(const ServerFailure(503));
        await pumpEventQueue();
        stored.complete((value: storedDetails, readAt: morning));
        await pumpEventQueue();

        expect(shown().details, same(storedDetails));
        expect(shown().failure, const ServerFailure(503));
      });

      test(
        'a task that is gone or may no longer be read shows as such',
        () async {
          stored.complete((value: storedDetails, readAt: morning));
          for (final failure in final_) {
            unawaited(controller.load(1).catchError((_) => storedDetails));
            await pumpEventQueue();
            expect(shown().storedAt, morning);

            reads.last.completeError(failure);
            await pumpEventQueue();

            expect(
              (controller.value as TaskDetailsFailed).failure,
              same(failure),
            );
          }
        },
      );

      test('changes made here keep them marked as stored; a refresh brings '
          "the server's or keeps them offline", () async {
        unawaited(controller.load(1).catchError((_) => storedDetails));
        stored.complete((value: storedDetails, readAt: morning));
        reads.last.completeError(offline);
        await pumpEventQueue();

        controller.setCover(3);
        expect(shown().details.coverImageAttachmentId, 3);
        expect(shown().storedAt, morning);
        expect(shown().failure, offline);

        final failing = controller.refresh();
        reads.last.completeError(offline);
        await failing;
        expect(shown().storedAt, morning);
        expect(shown().failure, offline);

        final refreshed = controller.refresh();
        reads.last.complete(const TaskDetails(commentCount: 5));
        await refreshed;
        expect(shown().storedAt, isNull);
        expect(shown().details.commentCount, 5);
      });

      test('nothing stored: the failure is the state as before', () async {
        unawaited(controller.load(1).catchError((_) => storedDetails));
        stored.complete(null);
        reads.last.completeError(offline);
        await pumpEventQueue();

        expect((controller.value as TaskDetailsFailed).failure, offline);
      });

      test('a change made while they stand in drops the first read, which '
          'may not have it: its answer shows with the change, and the '
          'details are read again once written', () async {
        const mine = {
          '👍': [User(id: 1, username: 'me')],
        };
        unawaited(controller.load(1));
        stored.complete((value: storedDetails, readAt: morning));
        await pumpEventQueue();

        final reacting = controller.writing(() async {
          controller.setReactions(mine);
        });
        reads.first.complete(const TaskDetails());
        await reacting;
        await pumpEventQueue();

        expect(reads, hasLength(2));
        expect(shown().details.reactions, mine);
        expect(shown().storedAt, isNull);

        reads.last.complete(const TaskDetails(reactions: mine));
        await pumpEventQueue();
        expect(shown().details.reactions, mine);
        expect(shown().storedAt, isNull);
      });

      test('a change made before what is stored shows drops the first read; '
          'what is stored stands in until that read answers, which then '
          'shows with the change, also when the next one fails '
          'offline', () async {
        final upload = sampleAttachment(id: 9);
        unawaited(controller.load(1).catchError((_) => storedDetails));
        controller.addAttachment(upload);
        expect(reads, hasLength(2));

        stored.complete((value: storedDetails, readAt: morning));
        await pumpEventQueue();
        expect(shown().details, same(storedDetails));
        expect(shown().storedAt, morning);

        reads.first.complete(const TaskDetails());
        await pumpEventQueue();
        expect(shown().storedAt, isNull);
        expect(shown().details.attachments, [upload]);

        reads.last.completeError(offline);
        await pumpEventQueue();
        expect(shown().details.attachments, [upload]);
        expect(shown().failure, isNull);
      });

      test('a change made while what is stored shows after a failure keeps '
          'it, changed and with the failure, when the reads after it fail '
          'too', () async {
        stored.complete((value: storedDetails, readAt: morning));
        unawaited(controller.load(1).catchError((_) => storedDetails));
        reads.last.completeError(offline);
        await pumpEventQueue();
        expect(shown().failure, offline);

        final refreshing = controller.refresh();
        controller.countComments(1);
        reads[1].completeError(offline);
        await refreshing;
        reads.last.completeError(offline);
        await pumpEventQueue();
        expect(shown().storedAt, morning);
        expect(shown().failure, offline);
        expect(shown().details.commentCount, 3);
      });
    });

    group('CommentsController', () {
      late List<TaskComment> all;
      late Exception? failure;
      late List<String> calls;
      StoredRead<List<TaskComment>>? kept;

      CommentsController create() {
        final controller = CommentsController(
          read: (taskId, {required page, required newestFirst}) async {
            calls.add('$page ${newestFirst ? 'newest' : 'oldest'}');
            if (failure case final failure?) throw failure;
            final ordered = newestFirst ? all.reversed.toList() : all;
            return Page(
              items: ordered.skip((page - 1) * 2).take(2).toList(),
              page: page,
              perPage: 2,
              totalPages: (ordered.length / 2).ceil(),
            );
          },
          stored: (_) async => kept,
        )..forTask(5);
        addTearDown(controller.dispose);
        return controller;
      }

      setUp(() {
        all = [for (var id = 1; id <= 3; id++) sampleComment(id: id)];
        failure = null;
        calls = [];
        kept = (
          value: [sampleComment(id: 1), sampleComment(id: 2)],
          readAt: morning,
        );
      });

      test('offline they show in the order chosen, with the failure and '
          "without more to load; Retry brings the server's", () async {
        failure = offline;
        final controller = create()..useDefaultOrder(newestFirst: true);

        await controller.show();
        expect(idsOf(controller), [2, 1]);
        expect(controller.value.storedAt, morning);
        expect(controller.value.failure, offline);
        expect(controller.value.shown, isTrue);
        expect(controller.value.hasMore, isFalse);

        await controller.toggleOrder();
        expect(idsOf(controller), [1, 2]);
        expect(controller.value.storedAt, morning);

        failure = null;
        await controller.retry();
        expect(idsOf(controller), [1, 2]);
        expect(controller.value.storedAt, isNull);
        expect(controller.value.failure, isNull);
        expect(controller.value.hasMore, isTrue);
        await controller.loadMore();
        expect(idsOf(controller), [1, 2, 3]);
      });

      test('a reaction made on them while the first page loads is read '
          'again once that page is in', () async {
        const mine = {
          '👍': [User(id: 1, username: 'me')],
        };
        final first = Completer<void>();
        var reads = 0;
        final controller = CommentsController(
          read: (taskId, {required page, required newestFirst}) async {
            reads++;
            if (reads == 1) await first.future;
            return Page(
              items: [
                sampleComment(id: 1, reactions: reads == 1 ? const {} : mine),
              ],
              page: 1,
              perPage: 2,
              totalPages: 1,
            );
          },
          stored: (_) async => kept,
        )..forTask(5);
        addTearDown(controller.dispose);

        final showing = controller.show();
        await pumpEventQueue();
        await controller.writing(() async {
          controller.setReactions(1, mine);
        });
        first.complete();
        await showing;
        await pumpEventQueue();

        expect(reads, 2);
        expect(controller.find(1)!.reactions, mine);
        expect(controller.value.storedAt, isNull);
      });

      test('a comment deleted while the first page loads, which may have been '
          'read before, is read again once that page is in', () async {
        final first = Completer<void>();
        var reads = 0;
        final controller = CommentsController(
          read: (taskId, {required page, required newestFirst}) async {
            reads++;
            if (reads == 1) await first.future;
            return Page(
              items: [
                sampleComment(id: 1),
                if (reads == 1) sampleComment(id: 2),
              ],
              page: 1,
              perPage: 2,
              totalPages: 1,
            );
          },
          stored: (_) async => kept,
        )..forTask(5);
        addTearDown(controller.dispose);

        final showing = controller.show();
        await pumpEventQueue();
        expect(controller.value.storedAt, morning);
        controller.remove(2);
        expect(idsOf(controller), [1]);
        first.complete();
        await showing;
        await pumpEventQueue();

        expect(reads, 2);
        expect(idsOf(controller), [1]);
        expect(controller.value.storedAt, isNull);
      });

      test('a comment deleted while a load fails is not read again on top of '
          'the next load', () async {
        final controller = create();
        await controller.show();
        calls.clear();

        failure = offline;
        final more = controller.loadMore();
        controller.remove(2);
        await more;
        failure = null;
        all = [sampleComment(id: 1), sampleComment(id: 3)];
        await controller.retry();
        await pumpEventQueue();

        expect(calls, ['2 oldest', '1 oldest', '2 oldest']);
      });

      test('a comment deleted while a later page loads reads the pages again '
          'once it is in', () async {
        final controller = create();
        await controller.show();
        calls.clear();

        final more = controller.loadMore();
        all = [sampleComment(id: 1), sampleComment(id: 3)];
        controller.remove(2);
        await more;
        await pumpEventQueue();

        expect(calls, ['2 oldest', '1 oldest', '2 oldest']);
        expect(idsOf(controller), [1, 3]);
      });

      test('they stand in while the first page loads', () async {
        final answer = Completer<void>();
        final held = CommentsController(
          read: (taskId, {required page, required newestFirst}) async {
            await answer.future;
            return Page(
              items: [sampleComment(id: 9)],
              page: 1,
              perPage: 2,
              totalPages: 1,
            );
          },
          stored: (_) async => kept,
        )..forTask(5);
        addTearDown(held.dispose);

        final showing = held.show();
        await pumpEventQueue();
        expect(idsOf(held), [1, 2]);
        expect(held.value.loading, isTrue);
        expect(held.value.storedAt, morning);

        answer.complete();
        await showing;
        expect(idsOf(held), [9]);
        expect(held.value.storedAt, isNull);
      });

      test(
        'every failure that may pass keeps them, with the failure',
        () async {
          for (final failing in passing) {
            failure = failing;
            final controller = create();
            await controller.show();
            expect(idsOf(controller), [1, 2], reason: '$failing');
            expect(controller.value.storedAt, morning, reason: '$failing');
            expect(controller.value.failure, failing, reason: '$failing');
          }
        },
      );

      test('a task that is gone or may no longer be read, or nothing stored, '
          'is the failure as before', () async {
        for (final failing in final_) {
          failure = failing;
          final controller = create();
          await controller.show();
          expect(controller.value.comments, isEmpty);
          expect(controller.value.storedAt, isNull);
          expect(controller.value.failure, same(failing));
        }

        failure = offline;
        kept = null;
        final controller = create();
        await controller.show();
        expect(controller.value.comments, isEmpty);
        expect(controller.value.failure, offline);
      });

      test('a later page that fails keeps the pages of the server', () async {
        final controller = create();
        await controller.show();
        failure = offline;

        await controller.loadMore();

        expect(idsOf(controller), [1, 2]);
        expect(controller.value.storedAt, isNull);
        expect(controller.value.failure, offline);
      });

      test('a comment written while they show reads the thread; a change '
          'from the server tries the first page again', () async {
        failure = offline;
        final controller = create();
        await controller.show();
        expect(controller.value.storedAt, morning);

        failure = null;
        await controller.refreshLoaded();
        expect(idsOf(controller), [1, 2]);
        expect(controller.value.storedAt, isNull);

        failure = offline;
        await controller.toggleOrder();
        expect(controller.value.storedAt, morning);
        failure = null;
        all = [...all, sampleComment(id: 4)];
        await controller.add(sampleComment(id: 4), wasEmpty: false);

        expect(idsOf(controller), [4, 3]);
        expect(controller.value.storedAt, isNull);
        expect(calls.last, '1 newest');
      });
    });
  });
}
