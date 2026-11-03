import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

void main() {
  const taskId = 100;

  late ProviderContainer container;
  late TestRepositories repos;

  void buildHarness({bool signedIn = true}) {
    final harness = controllerHarness(user: signedIn ? buildUser(id: 1) : null);
    container = harness.container;
    repos = harness.repos;
  }

  setUp(buildHarness);

  TaskCommentsController notifier() =>
      container.read(taskCommentsControllerProvider(taskId).notifier);

  Future<void> start() async {
    keepAlive(container, taskCommentsControllerProvider(taskId));
    await container.read(taskCommentsControllerProvider(taskId).future);
  }

  group('build', () {
    test('exposes the comments for the task', () async {
      repos.comment.onGetAll = (_) =>
          ok([buildComment(id: 7), buildComment(id: 8)]);

      await start();

      expect(
        container
            .read(taskCommentsControllerProvider(taskId))
            .value!
            .map((c) => c.id),
        [7, 8],
      );
    });

    test('raises when the request fails', () async {
      repos.comment.onGetAll = (_) => err<List<TaskComment>>();
      keepAlive(container, taskCommentsControllerProvider(taskId));

      await expectLater(
        container.read(taskCommentsControllerProvider(taskId).future),
        throwsA(isA<Exception>()),
      );
    });

    test('raises when the request throws', () async {
      repos.comment.onGetAll = (_) => boom<List<TaskComment>>();
      keepAlive(container, taskCommentsControllerProvider(taskId));

      await expectLater(
        container.read(taskCommentsControllerProvider(taskId).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('reload', () {
    test('replaces the comment list', () async {
      repos.comment.onGetAll = (_) => ok([buildComment(id: 7)]);
      await start();

      repos.comment.onGetAll = (_) =>
          ok([buildComment(id: 7), buildComment(id: 8)]);
      await notifier().reload();

      expect(
        container.read(taskCommentsControllerProvider(taskId)).value,
        hasLength(2),
      );
    });

    test('moves to an error state when the reload fails', () async {
      repos.comment.onGetAll = (_) => ok(<TaskComment>[]);
      await start();

      repos.comment.onGetAll = (_) => err<List<TaskComment>>();
      await notifier().reload();

      expect(
        container.read(taskCommentsControllerProvider(taskId)).hasError,
        isTrue,
      );
    });

    test('moves to an error state when the reload throws', () async {
      repos.comment.onGetAll = (_) => ok(<TaskComment>[]);
      await start();

      repos.comment.onGetAll = (_) => boom<List<TaskComment>>();
      await notifier().reload();

      expect(
        container.read(taskCommentsControllerProvider(taskId)).hasError,
        isTrue,
      );
    });
  });

  group('addComment', () {
    test('posts the comment as the signed-in user and reloads', () async {
      repos.comment.onGetAll = (_) => ok(<TaskComment>[]);
      await start();

      final added = await notifier().addComment('<p>Looks good</p>');

      expect(added, isTrue);
      expect(repos.comment.createCalls.single.comment, '<p>Looks good</p>');
      expect(repos.comment.createCalls.single.author.id, 1);
      expect(repos.comment.getAllCount, greaterThan(1));
    });

    test('refuses to post when nobody is signed in', () async {
      buildHarness(signedIn: false);
      repos.comment.onGetAll = (_) => ok(<TaskComment>[]);
      await start();

      expect(await notifier().addComment('<p>Hi</p>'), isFalse);
      expect(repos.comment.createCalls, isEmpty);
    });

    test('reports failure and does not reload when the post fails', () async {
      repos.comment.onGetAll = (_) => ok(<TaskComment>[]);
      await start();
      final reloadsBefore = repos.comment.getAllCount;
      repos.comment.onCreate = (_, _) => err<TaskComment>();

      expect(await notifier().addComment('<p>Hi</p>'), isFalse);
      expect(repos.comment.getAllCount, reloadsBefore);
    });
  });

  group('updateComment', () {
    test(
      'keeps the id, author and creation time while changing the text',
      () async {
        final original = buildComment(
          id: 7,
          comment: '<p>Old</p>',
          author: buildUser(id: 3, username: 'author'),
          created: DateTime.utc(2024, 1, 1),
        );
        repos.comment.onGetAll = (_) => ok([original]);
        await start();

        final updated = await notifier().updateComment(original, '<p>New</p>');

        expect(updated, isTrue);
        final sent = repos.comment.updateCalls.single;
        expect(sent.id, 7);
        expect(sent.comment, '<p>New</p>');
        expect(sent.author.id, 3);
        expect(sent.created, DateTime.utc(2024, 1, 1));
      },
    );

    test('reloads after a successful edit', () async {
      repos.comment.onGetAll = (_) => ok([buildComment(id: 7)]);
      await start();
      final reloadsBefore = repos.comment.getAllCount;

      await notifier().updateComment(buildComment(id: 7), '<p>New</p>');

      expect(repos.comment.getAllCount, greaterThan(reloadsBefore));
    });

    test('reports failure when the edit fails', () async {
      repos.comment.onGetAll = (_) => ok([buildComment(id: 7)]);
      await start();
      repos.comment.onUpdate = (_, _) => err<TaskComment>();

      expect(
        await notifier().updateComment(buildComment(id: 7), '<p>New</p>'),
        isFalse,
      );
    });
  });

  group('deleteComment', () {
    test('deletes the comment and reloads', () async {
      repos.comment.onGetAll = (_) => ok([buildComment(id: 7)]);
      await start();
      final reloadsBefore = repos.comment.getAllCount;

      final deleted = await notifier().deleteComment(7);

      expect(deleted, isTrue);
      expect(repos.comment.deleteCalls, [7]);
      expect(repos.comment.getAllCount, greaterThan(reloadsBefore));
    });

    test('reports failure and does not reload when the delete fails', () async {
      repos.comment.onGetAll = (_) => ok([buildComment(id: 7)]);
      await start();
      final reloadsBefore = repos.comment.getAllCount;
      repos.comment.onDelete = (_, _) => err<Object>();

      expect(await notifier().deleteComment(7), isFalse);
      expect(repos.comment.getAllCount, reloadsBefore);
    });
  });
}
