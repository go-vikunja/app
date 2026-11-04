import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';

class FakeSettingsRepository extends Fake implements SettingsRepository {
  @override
  Future<bool> getDisplayDoneTasks(int projectId) async => false;
}

class FakeTaskRepository extends Fake implements TaskRepository {
  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) async => SuccessResponse(<Task>[], 200, {});

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) async => SuccessResponse(<Task>[], 200, {});
}

class FakeBucketRepository extends Fake implements BucketRepository {
  final requestedViews = <int>[];

  @override
  Future<Response<List<Bucket>>> getAllByList(
    int projectId,
    int viewId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    requestedViews.add(viewId);
    return SuccessResponse(
      [
        Bucket(
          id: 10,
          projectViewId: viewId,
          title: 'To-Do',
          limit: 0,
          createdBy: User(username: 'testuser'),
        ),
      ],
      200,
      {},
    );
  }
}

ProjectView view(int id, ViewKind kind, double position) => ProjectView(
  DateTime.utc(2024),
  0,
  0,
  id,
  position,
  1,
  kind.name,
  DateTime.utc(2024),
  null,
  null,
  'manual',
  kind,
);

void main() {
  late FakeBucketRepository buckets;

  ProviderContainer createContainer() {
    buckets = FakeBucketRepository();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
        bucketRepositoryProvider.overrideWithValue(buckets),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads the buckets when the first view is a kanban view', () async {
    final project = Project(
      id: 1,
      title: 'Kanban first',
      views: [view(96, ViewKind.kanban, 50), view(93, ViewKind.list, 100)],
    );
    final container = createContainer();

    final model = await container.read(
      projectControllerProvider(project).future,
    );

    expect(model.viewIndex, 0);
    expect(buckets.requestedViews, [96]);
    expect(model.buckets.map((b) => b.title), ['To-Do']);
  });

  test('does not load buckets when the first view is a list view', () async {
    final project = Project(
      id: 1,
      title: 'List first',
      views: [view(93, ViewKind.list, 100), view(96, ViewKind.kanban, 400)],
    );
    final container = createContainer();

    final model = await container.read(
      projectControllerProvider(project).future,
    );

    expect(buckets.requestedViews, isEmpty);
    expect(model.buckets, isEmpty);
  });
}
