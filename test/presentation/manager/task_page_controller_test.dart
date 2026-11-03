import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/plugin_mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;
  late TestRepositories repos;

  setUp(() {
    // `_createPageModel` calls `updateWidget()`, which reaches for secure
    // storage directly; with no server stored it bails out immediately.
    mockPlatformPlugins();
    final harness = controllerHarness(
      user: buildUser(settings: buildUserSettings(defaultProjectId: 4)),
    );
    container = harness.container;
    repos = harness.repos;
  });

  TaskPageController notifier() =>
      container.read(taskPageControllerProvider.notifier);

  Future<void> start() async {
    keepAlive(container, taskPageControllerProvider);
    await container.read(taskPageControllerProvider.future);
  }

  group('build', () {
    test('loads open tasks and exposes the default project', () async {
      repos.task.onGetByFilterString = (_, _) => ok([buildTask(id: 1)]);

      await start();

      final model = container.read(taskPageControllerProvider).value!;
      expect(model.tasks.single.id, 1);
      expect(model.defaultProjectId, 4);
      expect(model.onlyDueDate, isFalse);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('filters to open tasks and sorts by due date', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);

      await start();

      expect(repos.task.filterCalls.single, 'done = false');
      expect(repos.task.filterQueryCalls.single, {
        'sort_by': ['due_date', 'id'],
        'order_by': ['asc', 'desc'],
        'filter_include_nulls': ['false'],
        'page': ['1'],
      });
    });

    test(
      'adds a due-date clause when the due-date-only setting is on',
      () async {
        repos.settings.landingPageOnlyDueDateTasks = true;
        repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);

        await start();

        expect(
          repos.task.filterCalls.single,
          'done = false && due_date > 0001-01-01 00:00',
        );
        expect(
          container.read(taskPageControllerProvider).value!.onlyDueDate,
          isTrue,
        );
      },
    );

    test(
      'uses the saved overview filter project when the user has one',
      () async {
        final harness = controllerHarness(
          user: buildUser(
            settings: buildUserSettings(
              frontendSettings: {'filter_id_used_on_overview': 12},
            ),
          ),
        );
        container = harness.container;
        repos = harness.repos;
        repos.task.onGetAllByProject = (_, _) => ok([buildTask(id: 5)]);

        await start();

        expect(repos.task.filterCalls, isEmpty);
        expect(
          container.read(taskPageControllerProvider).value!.tasks.single.id,
          5,
        );
      },
    );

    test('ignores an overview filter id of zero', () async {
      final harness = controllerHarness(
        user: buildUser(
          settings: buildUserSettings(
            frontendSettings: {'filter_id_used_on_overview': 0},
          ),
        ),
      );
      container = harness.container;
      repos = harness.repos;
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);

      await start();

      expect(repos.task.filterCalls, hasLength(1));
    });

    test('attaches each task to the project it belongs to', () async {
      repos.project.onGetAll = (_) => ok([
        buildProject(id: 1, title: 'Alpha'),
        buildProject(id: 2, title: 'Beta'),
      ]);
      repos.task.onGetByFilterString = (_, _) =>
          ok([buildTask(id: 1, projectId: 2), buildTask(id: 2, projectId: 99)]);

      await start();

      final tasks = container.read(taskPageControllerProvider).value!.tasks;
      expect(tasks.first.project!.title, 'Beta');
      expect(tasks.last.project, isNull, reason: 'unknown project stays unset');
    });

    test('raises when the task request fails', () async {
      repos.task.onGetByFilterString = (_, _) => err<List<Task>>();

      keepAlive(container, taskPageControllerProvider);

      await expectLater(
        container.read(taskPageControllerProvider.future),
        throwsA(anything),
      );
    });

    test('raises when the task request throws', () async {
      repos.task.onGetByFilterString = (_, _) => boom<List<Task>>();

      keepAlive(container, taskPageControllerProvider);

      await expectLater(
        container.read(taskPageControllerProvider.future),
        throwsA(anything),
      );
    });
  });

  group('reload', () {
    test('replaces the task list', () async {
      repos.task.onGetByFilterString = (_, _) => ok([buildTask(id: 1)]);
      await start();

      repos.task.onGetByFilterString = (_, _) =>
          ok([buildTask(id: 1), buildTask(id: 2)]);
      notifier().reload();
      await pumpEventQueue();

      expect(
        container
            .read(taskPageControllerProvider)
            .value!
            .tasks
            .map((t) => t.id),
        [1, 2],
      );
    });

    test('moves to an error state when the reload fails', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();

      repos.task.onGetByFilterString = (_, _) => err<List<Task>>();
      notifier().reload();
      await pumpEventQueue();

      expect(container.read(taskPageControllerProvider).hasError, isTrue);
    });

    test('moves to an error state when the reload throws', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();

      repos.task.onGetByFilterString = (_, _) => boom<List<Task>>();
      notifier().reload();
      await pumpEventQueue();

      expect(container.read(taskPageControllerProvider).hasError, isTrue);
    });
  });

  group('setLandingPageOnlyDueDateTasks', () {
    test('persists the choice and reloads with the new filter', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();

      await notifier().setLandingPageOnlyDueDateTasks(true);
      await pumpEventQueue();

      expect(repos.settings.landingPageOnlyDueDateTasks, isTrue);
      expect(repos.task.filterCalls.last, contains('due_date >'));
    });
  });

  group('addTask', () {
    test('creates the task, reloads and reports success', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();

      final added = await notifier().addTask(4, buildTask(title: 'Added'));
      await pumpEventQueue();

      expect(added, isTrue);
      expect(repos.task.addCalls.single.title, 'Added');
      expect(repos.task.filterCalls.length, greaterThan(1));
    });

    test('reports failure and does not reload when the create fails', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();
      final callsBefore = repos.task.filterCalls.length;
      repos.task.onAdd = (_, _) => err<Task>();

      expect(await notifier().addTask(4, buildTask()), isFalse);
      expect(repos.task.filterCalls.length, callsBefore);
    });
  });

  group('deleteTask', () {
    test('removes the task from the list and reports success', () async {
      repos.task.onGetByFilterString = (_, _) =>
          ok([buildTask(id: 1), buildTask(id: 2)]);
      await start();

      final deleted = await notifier().deleteTask(1);

      expect(deleted, isTrue);
      expect(repos.task.deleteCalls, [1]);
      expect(
        container
            .read(taskPageControllerProvider)
            .value!
            .tasks
            .map((t) => t.id),
        [2],
      );
    });

    test('leaves the list alone when the delete fails', () async {
      repos.task.onGetByFilterString = (_, _) => ok([buildTask(id: 1)]);
      await start();
      repos.task.onDelete = (_) => err<Object>();

      expect(await notifier().deleteTask(1), isFalse);
      expect(
        container.read(taskPageControllerProvider).value!.tasks,
        hasLength(1),
      );
    });
  });

  group('updateTask', () {
    test('saves the task, reloads and reports success', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();

      final saved = await notifier().updateTask(
        buildTask(id: 1, title: 'Edited'),
      );
      await pumpEventQueue();

      expect(saved, isTrue);
      expect(repos.task.updateCalls.single.title, 'Edited');
      expect(repos.task.filterCalls.length, greaterThan(1));
    });

    test('reports failure when the save fails', () async {
      repos.task.onGetByFilterString = (_, _) => ok(<Task>[]);
      await start();
      repos.task.onUpdate = (_) => err<Task>();

      expect(await notifier().updateTask(buildTask(id: 1)), isFalse);
    });
  });

  group('markAsDone', () {
    test('marks the task done and drops it from the open list', () async {
      final task = buildTask(id: 1);
      repos.task.onGetByFilterString = (_, _) => ok([task, buildTask(id: 2)]);
      await start();

      final done = await notifier().markAsDone(task);

      expect(done, isTrue);
      expect(repos.task.updateCalls.single.done, isTrue);
      expect(
        container
            .read(taskPageControllerProvider)
            .value!
            .tasks
            .map((t) => t.id),
        [2],
      );
    });

    test('leaves the list alone when the update fails', () async {
      final task = buildTask(id: 1);
      repos.task.onGetByFilterString = (_, _) => ok([task]);
      await start();
      repos.task.onUpdate = (_) => err<Task>();

      expect(await notifier().markAsDone(task), isFalse);
      expect(
        container.read(taskPageControllerProvider).value!.tasks,
        hasLength(1),
      );
    });
  });

  group('loadNextPage', () {
    test('appends the next page of tasks', () async {
      repos.task.onGetByFilterString = (_, query) {
        final page = int.parse(query!['page']!.first);
        return ok([buildTask(id: page)], headers: paginationHeaders(2));
      };
      await start();

      await notifier().loadNextPage();

      final model = container.read(taskPageControllerProvider).value!;
      expect(model.tasks.map((t) => t.id), [1, 2]);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('does nothing when there is only one page', () async {
      repos.task.onGetByFilterString = (_, _) => ok([buildTask(id: 1)]);
      await start();
      final callsBefore = repos.task.filterCalls.length;

      await notifier().loadNextPage();

      expect(repos.task.filterCalls.length, callsBefore);
    });
  });
}
