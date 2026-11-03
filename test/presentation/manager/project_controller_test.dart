import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;
  late TestRepositories repos;
  late Project listProject;
  late Project kanbanProject;
  late Project kanbanOnlyProject;

  setUp(() {
    final harness = controllerHarness(user: buildUser());
    container = harness.container;
    repos = harness.repos;
    listProject = buildProject(id: 1, views: [buildView(id: 10, projectId: 1)]);
    kanbanProject = buildProject(
      id: 2,
      views: [
        buildView(id: 20, projectId: 2),
        buildView(id: 21, projectId: 2, kind: ViewKind.kanban, title: 'Kanban'),
      ],
    );
    kanbanOnlyProject = buildProject(
      id: 4,
      views: [
        buildView(id: 40, projectId: 4, kind: ViewKind.kanban, title: 'Kanban'),
      ],
    );
  });

  ProjectController notifier(Project project) =>
      container.read(projectControllerProvider(project).notifier);

  Future<void> start(Project project) async {
    keepAlive(container, projectControllerProvider(project));
    await container.read(projectControllerProvider(project).future);
  }

  ProjectPageModel? state(Project project) =>
      container.read(projectControllerProvider(project)).value;

  group('build', () {
    test('loads the tasks of the first list view', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok([buildTask(id: 1)]);

      await start(listProject);

      final model = state(listProject)!;
      expect(model.tasks.single.id, 1);
      expect(model.viewIndex, 0);
      expect(model.buckets, isEmpty);
      expect(model.displayDoneTask, isFalse);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('sorts a list view by position', () async {
      Map<String, List<String>>? seen;
      repos.task.onGetAllByProjectView = (_, _, query) {
        seen = query;
        return ok(<Task>[]);
      };

      await start(listProject);

      expect(seen, {
        'sort_by': ['position'],
        'order_by': ['asc'],
        'page': ['1'],
        'filter': ['done=false'],
      });
    });

    test('drops the done filter when done tasks should be shown', () async {
      repos.settings.displayDoneTasks[1] = true;
      Map<String, List<String>>? seen;
      repos.task.onGetAllByProjectView = (_, _, query) {
        seen = query;
        return ok(<Task>[]);
      };

      await start(listProject);

      expect(seen!.containsKey('filter'), isFalse);
      expect(state(listProject)!.displayDoneTask, isTrue);
    });

    test('raises when the task request fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => err<List<Task>>();
      keepAlive(container, projectControllerProvider(listProject));

      await expectLater(
        container.read(projectControllerProvider(listProject).future),
        throwsA(isA<Exception>()),
      );
    });

    test('raises when the task request throws', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => boom<List<Task>>();
      keepAlive(container, projectControllerProvider(listProject));

      await expectLater(
        container.read(projectControllerProvider(listProject).future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('loadForView', () {
    test('loads buckets when switching to a kanban view', () async {
      repos.bucket.onGetAllByList = (_, _, _) => ok([
        buildBucket(id: 50, title: 'Todo'),
        buildBucket(id: 51, title: 'Doing'),
      ]);
      await start(kanbanProject);

      await notifier(kanbanProject).loadForView(kanbanProject, 1);

      expect(state(kanbanProject)!.buckets.map((b) => b.title), [
        'Todo',
        'Doing',
      ]);
    });

    test('loads no buckets for a list view', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);

      await notifier(listProject).loadForView(listProject, 0);

      expect(state(listProject)!.buckets, isEmpty);
    });

    test('records the view index it switched to', () async {
      final twoViewProject = buildProject(
        id: 3,
        views: [
          buildView(id: 30, projectId: 3),
          buildView(id: 31, projectId: 3, kind: ViewKind.kanban),
        ],
      );
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(twoViewProject);

      await notifier(twoViewProject).loadForView(twoViewProject, 1);

      expect(state(twoViewProject)!.viewIndex, 1);
    });

    test('moves to an error state when the task request fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);

      repos.task.onGetAllByProjectView = (_, _, _) => err<List<Task>>();
      await notifier(listProject).loadForView(listProject, 0);

      expect(
        container.read(projectControllerProvider(listProject)).hasError,
        isTrue,
      );
    });

    test('moves to an error state when the task request throws', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);

      repos.task.onGetAllByProjectView = (_, _, _) => boom<List<Task>>();
      await notifier(listProject).loadForView(listProject, 0);

      expect(
        container.read(projectControllerProvider(listProject)).hasError,
        isTrue,
      );
    });

    test('moves to an error state when the bucket request fails', () async {
      await start(kanbanProject);

      repos.bucket.onGetAllByList = (_, _, _) => err<List<Bucket>>();
      await notifier(kanbanProject).loadForView(kanbanProject, 1);

      expect(
        container.read(projectControllerProvider(kanbanProject)).hasError,
        isTrue,
      );
    });

    test('moves to an error state when the bucket request throws', () async {
      await start(kanbanProject);

      repos.bucket.onGetAllByList = (_, _, _) => boom<List<Bucket>>();
      await notifier(kanbanProject).loadForView(kanbanProject, 1);

      expect(
        container.read(projectControllerProvider(kanbanProject)).hasError,
        isTrue,
      );
    });
  });

  group('reload', () {
    test('reloads the current view', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok([buildTask(id: 1)]);
      await start(listProject);

      repos.task.onGetAllByProjectView = (_, _, _) =>
          ok([buildTask(id: 1), buildTask(id: 2)]);
      notifier(listProject).reload();
      await pumpEventQueue();

      expect(state(listProject)!.tasks, hasLength(2));
    });
  });

  group('addTask', () {
    test('appends the created task and reports success', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);
      repos.task.onAdd = (_, task) => ok(buildTask(id: 77, title: task.title));

      final added = await notifier(
        listProject,
      ).addTask(listProject, buildTask(title: 'Fresh'));

      expect(added, isTrue);
      expect(state(listProject)!.tasks.single.id, 77);
    });

    test('reports failure and adds nothing when the create fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);
      repos.task.onAdd = (_, _) => err<Task>();

      expect(
        await notifier(listProject).addTask(listProject, buildTask()),
        isFalse,
      );
      expect(state(listProject)!.tasks, isEmpty);
    });
  });

  group('markAsDone', () {
    test('marks the task done and drops it from the list', () async {
      final task = buildTask(id: 1);
      repos.task.onGetAllByProjectView = (_, _, _) =>
          ok([task, buildTask(id: 2)]);
      await start(listProject);

      final done = await notifier(listProject).markAsDone(task);

      expect(done, isTrue);
      expect(repos.task.updateCalls.single.done, isTrue);
      expect(state(listProject)!.tasks.map((t) => t.id), [2]);
    });

    test('reports failure when the update fails', () async {
      final task = buildTask(id: 1);
      repos.task.onGetAllByProjectView = (_, _, _) => ok([task]);
      await start(listProject);
      repos.task.onUpdate = (_) => err<Task>();

      expect(await notifier(listProject).markAsDone(task), isFalse);
      expect(state(listProject)!.tasks, hasLength(1));
    });
  });

  group('bucket management', () {
    test('addBucket appends the new bucket', () async {
      await start(kanbanProject);

      final added = await notifier(kanbanProject).addBucket(
        newBucket: buildBucket(id: 60, title: 'New'),
        project: kanbanProject,
        viewId: 21,
      );

      expect(added, isTrue);
      expect(repos.bucket.addCalls.single.title, 'New');
      expect(state(kanbanProject)!.buckets.single.id, 60);
    });

    test('addBucket reports failure without changing the state', () async {
      await start(kanbanProject);
      repos.bucket.onAdd = (_) => err<Bucket>();

      final added = await notifier(
        kanbanProject,
      ).addBucket(newBucket: buildBucket(), project: kanbanProject, viewId: 21);

      expect(added, isFalse);
      expect(state(kanbanProject)!.buckets, isEmpty);
    });

    test('deleteBucket removes the bucket from the board', () async {
      repos.bucket.onGetAllByList = (_, _, _) =>
          ok([buildBucket(id: 50), buildBucket(id: 51)]);
      await start(kanbanProject);
      await notifier(kanbanProject).loadForView(kanbanProject, 1);

      final deleted = await notifier(
        kanbanProject,
      ).deleteBucket(bucket: buildBucket(id: 50), project: kanbanProject);

      expect(deleted, isTrue);
      expect(repos.bucket.deleteCalls, [50]);
      expect(state(kanbanProject)!.buckets.map((b) => b.id), [51]);
    });

    test('deleteBucket reports failure without changing the board', () async {
      repos.bucket.onGetAllByList = (_, _, _) => ok([buildBucket(id: 50)]);
      await start(kanbanProject);
      await notifier(kanbanProject).loadForView(kanbanProject, 1);
      repos.bucket.onDelete = (_) => err<Object>();

      final deleted = await notifier(
        kanbanProject,
      ).deleteBucket(bucket: buildBucket(id: 50), project: kanbanProject);

      expect(deleted, isFalse);
      expect(state(kanbanProject)!.buckets, hasLength(1));
    });

    test('updateBucket replaces the stored bucket', () async {
      repos.bucket.onGetAllByList = (_, _, _) =>
          ok([buildBucket(id: 50, title: 'Old')]);
      await start(kanbanProject);
      await notifier(kanbanProject).loadForView(kanbanProject, 1);

      final updated = await notifier(kanbanProject).updateBucket(
        bucket: buildBucket(id: 50, title: 'Renamed'),
        project: kanbanProject,
      );

      expect(updated, isTrue);
      expect(state(kanbanProject)!.buckets.single.title, 'Renamed');
    });

    test('updateBucket reports failure without changing the board', () async {
      repos.bucket.onGetAllByList = (_, _, _) =>
          ok([buildBucket(id: 50, title: 'Old')]);
      await start(kanbanProject);
      await notifier(kanbanProject).loadForView(kanbanProject, 1);
      repos.bucket.onUpdate = (_) => err<Bucket>();

      final updated = await notifier(kanbanProject).updateBucket(
        bucket: buildBucket(id: 50, title: 'Renamed'),
        project: kanbanProject,
      );

      expect(updated, isFalse);
      expect(state(kanbanProject)!.buckets.single.title, 'Old');
    });
  });

  group('done and default bucket selection', () {
    test('updateDoneBucket marks a column as the done column', () async {
      await start(kanbanProject);

      final updated = await notifier(
        kanbanProject,
      ).updateDoneBucket(kanbanProject, 51, false);

      expect(updated, isTrue);
      expect(repos.projectView.updateCalls.single.doneBucketId, 51);
    });

    test(
      'updateDoneBucket clears the done column when it is already set',
      () async {
        await start(kanbanProject);

        await notifier(kanbanProject).updateDoneBucket(kanbanProject, 51, true);

        expect(repos.projectView.updateCalls.single.doneBucketId, 0);
      },
    );

    test('updateDoneBucket reports failure when the save fails', () async {
      await start(kanbanProject);
      repos.projectView.onUpdate = (_) => err<ProjectView>();

      expect(
        await notifier(
          kanbanProject,
        ).updateDoneBucket(kanbanProject, 51, false),
        isFalse,
      );
    });

    test('selectDefaultBucket marks a column as the default column', () async {
      await start(kanbanProject);

      final updated = await notifier(
        kanbanProject,
      ).selectDefaultBucket(kanbanProject, 52, false);

      expect(updated, isTrue);
      expect(repos.projectView.updateCalls.single.defaultBucketId, 52);
    });

    test(
      'selectDefaultBucket clears it when it is already the default',
      () async {
        await start(kanbanProject);

        await notifier(
          kanbanProject,
        ).selectDefaultBucket(kanbanProject, 52, true);

        expect(repos.projectView.updateCalls.single.defaultBucketId, 0);
      },
    );

    test('selectDefaultBucket reports failure when the save fails', () async {
      await start(kanbanProject);
      repos.projectView.onUpdate = (_) => err<ProjectView>();

      expect(
        await notifier(
          kanbanProject,
        ).selectDefaultBucket(kanbanProject, 52, false),
        isFalse,
      );
    });
  });

  group('moveTask', () {
    test('updates the bucket and the position', () async {
      await start(kanbanProject);

      final moved = await notifier(
        kanbanProject,
      ).moveTask(kanbanProject, buildTask(id: 7), buildBucket(id: 51), 128.0);

      expect(moved, isTrue);
      expect(repos.bucket.taskBucketCalls.single, (taskId: 7, bucketId: 51));
      expect(repos.bucket.positionCalls.single.position, 128.0);
    });

    test('reports failure when the bucket update fails', () async {
      await start(kanbanProject);
      repos.bucket.onUpdateTaskBucket = (_, _) => err<Object>();

      expect(
        await notifier(
          kanbanProject,
        ).moveTask(kanbanProject, buildTask(id: 7), buildBucket(id: 51), 128.0),
        isFalse,
      );
    });

    test('reports failure when the position update fails', () async {
      await start(kanbanProject);
      repos.bucket.onUpdateTaskPosition = (_, _, _) => err<Object>();

      expect(
        await notifier(
          kanbanProject,
        ).moveTask(kanbanProject, buildTask(id: 7), buildBucket(id: 51), 128.0),
        isFalse,
      );
    });
  });

  group('reorderTasks', () {
    test('applies the new order immediately and saves the position', () async {
      repos.task.onGetAllByProjectView = (_, _, _) =>
          ok([buildTask(id: 1), buildTask(id: 2)]);
      await start(listProject);

      final reordered = await notifier(listProject).reorderTasks(
        project: listProject,
        newOrderedTasks: [buildTask(id: 2), buildTask(id: 1)],
        movedTaskId: 2,
        newPosition: 32.0,
      );

      expect(reordered, isTrue);
      expect(state(listProject)!.tasks.map((t) => t.id), [2, 1]);
      expect(repos.bucket.positionCalls.single, (
        taskId: 2,
        viewId: 10,
        position: 32.0,
      ));
    });

    test('skips the save when the project has no list view', () async {
      await start(kanbanOnlyProject);

      final reordered = await notifier(kanbanOnlyProject).reorderTasks(
        project: kanbanOnlyProject,
        newOrderedTasks: [],
        movedTaskId: 1,
        newPosition: 1.0,
      );

      expect(reordered, isTrue);
      expect(repos.bucket.positionCalls, isEmpty);
    });

    test('reloads and reports failure when the save fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok([buildTask(id: 1)]);
      await start(listProject);
      repos.bucket.onUpdateTaskPosition = (_, _, _) => err<Object>();

      final reordered = await notifier(listProject).reorderTasks(
        project: listProject,
        newOrderedTasks: [buildTask(id: 1)],
        movedTaskId: 1,
        newPosition: 32.0,
      );
      await pumpEventQueue();

      expect(reordered, isFalse);
    });
  });

  group('setDisplayDoneTasks', () {
    test('persists the choice and reloads without the done filter', () async {
      final queries = <Map<String, List<String>>?>[];
      repos.task.onGetAllByProjectView = (_, _, query) {
        queries.add(query);
        return ok(<Task>[]);
      };
      await start(listProject);

      final changed = await notifier(listProject).setDisplayDoneTasks(true);

      expect(changed, isTrue);
      expect(repos.settings.displayDoneTasks[1], isTrue);
      expect(queries.first!.containsKey('filter'), isTrue);
      expect(queries.last!.containsKey('filter'), isFalse);
      expect(state(listProject)!.displayDoneTask, isTrue);
    });

    test('reports failure when the reload fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);

      repos.task.onGetAllByProjectView = (_, _, _) => err<List<Task>>();

      expect(await notifier(listProject).setDisplayDoneTasks(true), isFalse);
    });
  });

  group('updateProject', () {
    test('sends the project to the api', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);

      await notifier(
        listProject,
      ).updateProject(buildProject(id: 1, title: 'Renamed'));

      expect(repos.project.updateCalls.single.title, 'Renamed');
    });

    test('reports failure when the save fails', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok(<Task>[]);
      await start(listProject);
      repos.project.onUpdate = (_) => err<Project>();

      expect(await notifier(listProject).updateProject(listProject), isFalse);
    });
  });

  group('loadNextPage', () {
    test('appends the next page of list-view tasks', () async {
      repos.task.onGetAllByProjectView = (_, _, query) {
        final page = int.parse(query!['page']!.first);
        return ok([buildTask(id: page)], headers: paginationHeaders(2));
      };
      await start(listProject);

      await notifier(listProject).loadNextPage();

      final model = state(listProject)!;
      expect(model.tasks.map((t) => t.id), [1, 2]);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('does nothing when there is only one page', () async {
      repos.task.onGetAllByProjectView = (_, _, _) => ok([buildTask(id: 1)]);
      await start(listProject);

      await notifier(listProject).loadNextPage();

      expect(state(listProject)!.tasks, hasLength(1));
    });
  });
}
