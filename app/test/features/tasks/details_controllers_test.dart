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
  });
}
