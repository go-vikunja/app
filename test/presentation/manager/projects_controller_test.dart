import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';

import '../../helpers/builders.dart';
import '../../helpers/controller_harness.dart';
import '../../helpers/fake_repositories.dart';
import '../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;
  late TestRepositories repos;

  setUp(() {
    final harness = controllerHarness();
    container = harness.container;
    repos = harness.repos;
  });

  ProjectsController notifier() =>
      container.read(projectsControllerProvider.notifier);

  /// Builds the controller and keeps it alive for the rest of the test. Must be
  /// called *after* the repository stubs are in place.
  Future<void> start() async {
    keepAlive(container, projectsControllerProvider);
    await container.read(projectsControllerProvider.future);
  }

  group('loadProjects', () {
    test(
      'keeps only top-level projects and nests the rest beneath them',
      () async {
        repos.project.onGetAll = (_) => ok([
          buildProject(id: 1, title: 'Parent'),
          buildProject(id: 2, title: 'Sub 1', parentProjectId: 1),
          buildProject(id: 3, title: 'Sub 2', parentProjectId: 1),
          buildProject(id: 4, title: 'Independent'),
        ]);

        final response = await notifier().loadProjects();

        final topLevel = response.toSuccess().body;
        expect(topLevel.map((p) => p.id), [1, 4]);
        expect(topLevel.first.subprojects.map((p) => p.id), [2, 3]);
        expect(topLevel.last.subprojects, isEmpty);
      },
    );

    test('nests subprojects recursively', () async {
      repos.project.onGetAll = (_) => ok([
        buildProject(id: 1),
        buildProject(id: 2, parentProjectId: 1),
        buildProject(id: 3, parentProjectId: 2),
      ]);

      final topLevel = (await notifier().loadProjects()).toSuccess().body;

      expect(topLevel.single.subprojects.single.subprojects.single.id, 3);
    });

    test('always asks for the first page', () async {
      repos.project.onGetAll = (_) => ok(<Project>[]);

      await notifier().loadProjects();

      // build() loads page 1 too, so every recorded call must be page 1.
      expect(repos.project.getAllCalls, everyElement(1));
      expect(repos.project.getAllCalls, isNotEmpty);
    });

    test('passes a failed response straight through', () async {
      repos.project.onGetAll = (_) => err<List<Project>>(status: 500);

      expect((await notifier().loadProjects()).isError, isTrue);
    });
  });

  group('build', () {
    test('exposes the grouped projects', () async {
      repos.project.onGetAll = (_) =>
          ok([buildProject(id: 1), buildProject(id: 2, parentProjectId: 1)]);

      keepAlive(container, projectsControllerProvider);
      final model = await container.read(projectsControllerProvider.future);

      expect(model.projects.single.id, 1);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('raises the api error message when the request fails', () async {
      repos.project.onGetAll = (_) =>
          err<List<Project>>(error: {'message': 'forbidden'});

      await expectLater(
        container.read(projectsControllerProvider.future),
        throwsA(isA<Exception>()),
      );
    });

    test('raises the exception message when the request throws', () async {
      repos.project.onGetAll = (_) => boom<List<Project>>();

      await expectLater(
        container.read(projectsControllerProvider.future),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('reload', () {
    test('replaces the state with freshly loaded projects', () async {
      repos.project.onGetAll = (_) => ok([buildProject(id: 1)]);
      await start();

      repos.project.onGetAll = (_) => ok([
        buildProject(id: 1),
        buildProject(id: 9, title: 'Added elsewhere'),
      ]);
      notifier().reload();
      await container.read(projectsControllerProvider.future);

      expect(
        container
            .read(projectsControllerProvider)
            .value!
            .projects
            .map((p) => p.id),
        [1, 9],
      );
    });

    test('moves to an error state when the reload fails', () async {
      repos.project.onGetAll = (_) => ok(<Project>[]);
      await start();

      repos.project.onGetAll = (_) => err<List<Project>>();
      notifier().reload();
      await pumpEventQueue();

      expect(container.read(projectsControllerProvider).hasError, isTrue);
    });

    test('moves to an error state when the reload throws', () async {
      repos.project.onGetAll = (_) => ok(<Project>[]);
      await start();

      repos.project.onGetAll = (_) => boom<List<Project>>();
      notifier().reload();
      await pumpEventQueue();

      expect(container.read(projectsControllerProvider).hasError, isTrue);
    });
  });

  group('create', () {
    test('sends the project and reloads the list', () async {
      repos.project.onGetAll = (_) => ok(<Project>[]);
      await start();

      notifier().create(buildProject(title: 'Brand new'));
      await pumpEventQueue();

      expect(repos.project.createCalls.single.title, 'Brand new');
      expect(repos.project.getAllCalls.length, greaterThan(1));
    });
  });

  group('loadNextPage', () {
    test('appends the next page and clears the loading flag', () async {
      repos.project.onGetAll = (page) => ok([
        buildProject(id: page, title: 'Page $page'),
      ], headers: paginationHeaders(2));
      await start();

      final future = notifier().loadNextPage();
      expect(
        container.read(projectsControllerProvider).value!.isLoadingNextPage,
        isTrue,
        reason:
            'the spinner should show the moment the page is requested, '
            'not once the request comes back',
      );

      await future;

      final model = container.read(projectsControllerProvider).value!;
      expect(model.projects.map((p) => p.id), [1, 2]);
      expect(model.isLoadingNextPage, isFalse);
    });

    test('does nothing when there is only one page', () async {
      repos.project.onGetAll = (_) => ok([buildProject(id: 1)]);
      await start();
      repos.project.getAllCalls.clear();

      await notifier().loadNextPage();

      expect(repos.project.getAllCalls, isEmpty);
    });

    test('clears the loading flag even when the page fetch fails', () async {
      repos.project.onGetAll = (page) => page == 1
          ? ok([buildProject(id: 1)], headers: paginationHeaders(2))
          : err<List<Project>>();
      await start();

      await notifier().loadNextPage();

      final model = container.read(projectsControllerProvider).value!;
      expect(model.isLoadingNextPage, isFalse);
      expect(model.projects, hasLength(1));
    });

    test('does nothing while the controller is in an error state', () async {
      repos.project.onGetAll = (_) => err<List<Project>>();
      keepAlive(container, projectsControllerProvider);
      await expectLater(
        container.read(projectsControllerProvider.future),
        throwsA(anything),
      );
      repos.project.getAllCalls.clear();

      await notifier().loadNextPage();

      expect(repos.project.getAllCalls, isEmpty);
    });
  });

  group('ProjectListModel state', () {
    test('a fresh model is not paging', () {
      expect(ProjectListModel([buildProject()]).isLoadingNextPage, isFalse);
    });
  });
}
