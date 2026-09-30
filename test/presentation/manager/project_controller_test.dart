import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/di/widget_refresher_provider.dart';
import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate;
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';

class MockTaskRepository implements TaskRepository {
  Future<Response<Task>> Function(Task task)? updateStub;
  Future<Response<Task>> Function(int projectId, Task task)? addStub;
  Future<Response<Task>> Function(int id)? getTaskStub;
  Future<Response<List<Task>>> Function(String filterString)?
  getByFilterStringStub;
  Future<Response<List<Task>>> Function(
    int projectId,
    Map<String, List<String>>? queryParameters,
  )?
  getAllByProjectStub;
  Future Function(int taskId)? deleteStub;

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
    return getByFilterStringStub!(filterString);
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) {
    throw UnimplementedError();
  }
}

class MockSettingsRepository implements SettingsRepository {
  bool landingPageOnlyDueDateTasks = false;
  bool displayDoneTasks = false;

  @override
  Future<bool> getLandingPageOnlyDueDateTasks() async {
    return landingPageOnlyDueDateTasks;
  }

  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool value) async {}

  @override
  Future<bool> getDisplayDoneTasks(int projectId) async {
    return displayDoneTasks;
  }

  @override
  Future<bool> getIgnoreCertificates() {
    throw UnimplementedError();
  }

  @override
  Future<void> setIgnoreCertificates(bool value) {
    throw UnimplementedError();
  }

  @override
  Future<bool> getSentryEnabled() {
    throw UnimplementedError();
  }

  @override
  Future<void> setSentryEnabled(bool value) {
    throw UnimplementedError();
  }

  @override
  Future<bool> getVersionNotifications() {
    throw UnimplementedError();
  }

  @override
  Future<void> setVersionNotifications(bool value) {
    throw UnimplementedError();
  }

  @override
  Future<int> getRefreshInterval() {
    throw UnimplementedError();
  }

  @override
  Future<void> setRefreshInterval(int minutes) {
    throw UnimplementedError();
  }

  @override
  Future<FlutterThemeMode> getThemeMode() {
    throw UnimplementedError();
  }

  @override
  Future<void> setThemeMode(FlutterThemeMode newMode) {
    throw UnimplementedError();
  }

  @override
  Future<void> setDynamicColors(bool dynamicColors) {
    throw UnimplementedError();
  }

  @override
  Future<bool> getDynamicColors() {
    throw UnimplementedError();
  }

  @override
  Future<void> setDisplayDoneTasks(int projectId, bool value) {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getPastServers() {
    throw UnimplementedError();
  }

  @override
  Future<void> setPastServers(List<String> server) {
    throw UnimplementedError();
  }

  @override
  Future<bool> getSentryDialogShown() {
    throw UnimplementedError();
  }

  @override
  Future<void> setSentryDialogShown(bool value) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveUserToken(String? token) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getUserToken() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveRefreshToken(String? token) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getRefreshToken() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveServer(String? server) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getServer() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getLocaleOverride() {
    throw UnimplementedError();
  }

  @override
  Future<void> setLocaleOverride(String? localeCode) {
    throw UnimplementedError();
  }
}

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockSettingsRepository mockSettingsRepository;
  int refresherCalls = 0;

  final project = Project(id: 1, title: 'Project', views: []);

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
    mockSettingsRepository = MockSettingsRepository();
    refresherCalls = 0;
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(mockTaskRepository),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
        widgetRefresherProvider.overrideWithValue(() async {
          refresherCalls++;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProjectController> buildController(ProviderContainer container) async {
    final controller = container.read(
      projectControllerProvider(project).notifier,
    );
    container.listen(projectControllerProvider(project), (_, _) {});
    await container.read(projectControllerProvider(project).future);
    return controller;
  }

  test('markAsDone refreshes the home-screen widget after success', () async {
    final task = buildTask();
    mockTaskRepository.getAllByProjectStub =
        (projectId, queryParameters) async => SuccessResponse([task], 200, {});
    mockTaskRepository.updateStub = (t) async => SuccessResponse(t, 200, {});

    final container = createContainer();
    final controller = await buildController(container);

    final result = await controller.markAsDone(task);

    expect(result, isTrue);
    expect(refresherCalls, 1);
  });

  test(
    'markAsDone refreshes the widget even before the page state loaded',
    () async {
      final task = buildTask();
      // Keep the page build pending so state.value is still null.
      final buildCompleter = Completer<void>();
      mockTaskRepository.getAllByProjectStub =
          (projectId, queryParameters) async {
            await buildCompleter.future;
            return SuccessResponse(<Task>[], 200, {});
          };
      mockTaskRepository.updateStub = (t) async => SuccessResponse(t, 200, {});

      final container = createContainer();
      final controller = container.read(
        projectControllerProvider(project).notifier,
      );
      container.listen(projectControllerProvider(project), (_, _) {});

      final result = await controller.markAsDone(task);
      buildCompleter.complete();

      expect(result, isTrue);
      expect(refresherCalls, 1);
    },
  );

  test('addTask refreshes the home-screen widget after success', () async {
    final newTask = buildTask();
    mockTaskRepository.getAllByProjectStub =
        (projectId, queryParameters) async =>
            SuccessResponse(<Task>[], 200, {});
    mockTaskRepository.addStub = (projectId, task) async =>
        SuccessResponse(task, 200, {});

    final container = createContainer();
    final controller = await buildController(container);

    final result = await controller.addTask(project, newTask);

    expect(result, isTrue);
    expect(refresherCalls, 1);
  });
}
