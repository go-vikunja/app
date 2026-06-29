import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';

class MockProjectRepository implements ProjectRepository {
  Future<Response<List<Project>>> Function({int page})? getAllStub;

  @override
  Future<Response<List<Project>>> getAll({int page = 1}) {
    return getAllStub!(page: page);
  }

  @override
  Future<Response<Project>> create(Project p) {
    throw UnimplementedError();
  }

  @override
  Future<Response<Project>> update(Project p) {
    throw UnimplementedError();
  }
}

void main() {
  late MockProjectRepository mockProjectRepository;

  setUp(() {
    mockProjectRepository = MockProjectRepository();
  });

  ProviderContainer createContainer({List<Override> overrides = const []}) {
    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockProjectRepository),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loadProjects correctly groups subprojects', () async {
    final projects = [
      Project(id: 1, title: 'Parent Project', parentProjectId: 0),
      Project(id: 2, title: 'Subproject 1', parentProjectId: 1),
      Project(id: 3, title: 'Subproject 2', parentProjectId: 1),
      Project(id: 4, title: 'Independent Project', parentProjectId: 0),
    ];

    mockProjectRepository.getAllStub = ({int page = 1}) async =>
        SuccessResponse(projects, 200, {});

    final container = createContainer();
    final controller = container.read(projectsControllerProvider.notifier);

    final response = await controller.loadProjects();

    expect(response.isSuccessful, isTrue);
    final topLevelProjects = response.toSuccess().body as List<Project>;

    expect(topLevelProjects.length, 2);
    expect(topLevelProjects[0].id, 1);
    expect(topLevelProjects[1].id, 4);

    expect(topLevelProjects[0].subprojects.length, 2);
    expect(topLevelProjects[0].subprojects.first.id, 2);
    expect(topLevelProjects[0].subprojects.last.id, 3);
  });
}
