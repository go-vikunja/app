import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/widget_launch_controller.dart';

class MockTaskRepository implements TaskRepository {
  Future<Response<Task>> Function(Task task)? updateStub;
  Future<Response<Task>> Function(int projectId, Task task)? addStub;
  Future<Response<Task>> Function(int id)? getTaskStub;
  Future<Response<List<Task>>> Function(
    String filterString,
    Map<String, List<String>>? queryParameters,
  )?
  getByFilterStringStub;
  Future<Response<List<Task>>> Function(
    int projectId,
    Map<String, List<String>>? queryParameters,
  )?
  getAllByProjectStub;
  Future Function(int taskId)? deleteStub;
  List<int> getTaskCalls = [];

  @override
  Future<Response<Task>> add(int projectId, Task task) {
    return addStub!(projectId, task);
  }

  @override
  Future delete(int taskId) {
    return deleteStub!(taskId);
  }

  @override
  Future<Response<Task>> update(Task task) {
    return updateStub!(task);
  }

  @override
  Future<Response<Task>> getTask(int id) {
    getTaskCalls.add(id);
    return getTaskStub!(id);
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return getAllByProjectStub!(projectId, queryParameters);
  }

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) {
    return getByFilterStringStub!(filterString, queryParameters);
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) {
    throw UnimplementedError();
  }
}

void main() {
  late MockTaskRepository mockTaskRepository;

  Task buildTask({int id = 1}) {
    return Task(
      id: id,
      title: 'Task $id',
      createdBy: User(username: 'testuser'),
      projectId: 1,
    );
  }

  setUp(() {
    mockTaskRepository = MockTaskRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(mockTaskRepository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('openTask fetches and returns the task for a widget row id', () async {
    final task = buildTask(id: 42);
    mockTaskRepository.getTaskStub = (id) async =>
        SuccessResponse(task, 200, {});

    final container = createContainer();
    final controller = container.read(widgetLaunchControllerProvider);

    final result = await controller.openTask('42');

    expect(result, same(task));
    expect(mockTaskRepository.getTaskCalls, [42]);
  });

  test('openTask returns null when the fetch fails', () async {
    mockTaskRepository.getTaskStub = (id) async =>
        ErrorResponse(500, {}, {'message': 'server error'});

    final container = createContainer();
    final controller = container.read(widgetLaunchControllerProvider);

    final result = await controller.openTask('42');

    expect(result, isNull);
  });

  test('openTask ignores task ids that are not positive integers', () async {
    final container = createContainer();
    final controller = container.read(widgetLaunchControllerProvider);

    for (final invalid in [null, '', 'not-a-number', '0', '-1']) {
      final result = await controller.openTask(invalid);
      expect(result, isNull, reason: 'id "$invalid" should not be opened');
    }

    expect(mockTaskRepository.getTaskCalls, isEmpty);
  });
}
