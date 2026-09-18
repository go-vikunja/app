/// Hand-written fakes for every domain repository.
///
/// Controller and widget tests drive these instead of a real `Client`, so no
/// test above the data layer re-exercises HTTP, JSON or DTO mapping — that is
/// covered exactly once, in `test/data/`.
///
/// Each repository that makes requests records the arguments it was called
/// with (`*Calls`) and returns a canned [Response] from its `on*` hook, so a
/// test states its intent in one line. The settings and version fakes stand in
/// for stored values instead: a test sets or reads their fields directly.
library;

import 'dart:async';

import 'package:background_downloader/background_downloader.dart'
    show TaskStatusUpdate, TaskStatus, DownloadTask;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/label_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_label_data_source.dart';
import 'package:vikunja_app/data/repositories/label_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_label_repository_impl.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_view.dart';
import 'package:vikunja_app/domain/entities/server.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/domain/entities/task_label.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/domain/repositories/bucket_repository.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/project_view_repository.dart';
import 'package:vikunja_app/domain/repositories/server_repository.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/domain/repositories/task_comment_repository.dart';
import 'package:vikunja_app/domain/repositories/task_label_bulk_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/domain/repositories/user_repository.dart';
import 'package:vikunja_app/domain/repositories/version_repository.dart';

/// Convenience constructors for the canned responses fakes hand back.
SuccessResponse<T> ok<T>(
  T body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => SuccessResponse<T>(body, status, headers);

ErrorResponse<T> err<T>({
  int status = 500,
  Map<String, dynamic> error = const {'message': 'boom'},
}) => ErrorResponse<T>(status, const {}, error);

ExceptionResponse<T> boom<T>([
  Object? exception,
  StackTrace stackTrace = StackTrace.empty,
]) => ExceptionResponse<T>(exception ?? Exception('network down'), stackTrace);

/// Headers a paginated endpoint returns, e.g. `paginationHeaders(3)`.
Map<String, String> paginationHeaders(int totalPages) => {
  'x-pagination-total-pages': '$totalPages',
};

class FakeProjectRepository implements ProjectRepository {
  FutureOr<Response<List<Project>>> Function(int page)? onGetAll;
  Response<Project> Function(Project p)? onCreate;
  Response<Project> Function(Project p)? onUpdate;

  final List<int> getAllCalls = [];
  final List<Project> createCalls = [];
  final List<Project> updateCalls = [];

  @override
  Future<Response<List<Project>>> getAll({int page = 1}) async {
    getAllCalls.add(page);
    return await onGetAll?.call(page) ?? ok<List<Project>>([]);
  }

  @override
  Future<Response<Project>> create(Project p) async {
    createCalls.add(p);
    return onCreate?.call(p) ?? ok(p);
  }

  @override
  Future<Response<Project>> update(Project p) async {
    updateCalls.add(p);
    return onUpdate?.call(p) ?? ok(p);
  }
}

class FakeTaskRepository implements TaskRepository {
  Response<List<Task>> Function(String filter, Map<String, List<String>>? q)?
  onGetByFilterString;
  Response<List<Task>> Function(int projectId, Map<String, List<String>>? q)?
  onGetAllByProject;
  FutureOr<Response<List<Task>>> Function(
    int projectId,
    int view,
    Map<String, List<String>>? q,
  )?
  onGetAllByProjectView;
  Response<Task> Function(int projectId, Task task)? onAdd;
  Response<Task> Function(Task task)? onUpdate;
  Response<Task> Function(int id)? onGetTask;
  Response<Object> Function(int taskId)? onDelete;

  final List<Task> addCalls = [];
  final List<Task> updateCalls = [];
  final List<int> deleteCalls = [];
  final List<String> filterCalls = [];
  final List<Map<String, List<String>>?> filterQueryCalls = [];
  final List<TaskAttachment> downloadCalls = [];
  final List<int> getTaskCalls = [];
  final List<({int projectId, Map<String, List<String>>? query})>
  getAllByProjectCalls = [];
  final List<({int projectId, int view, Map<String, List<String>>? query})>
  getAllByProjectViewCalls = [];

  @override
  Future<Response<Task>> add(int projectId, Task task) async {
    addCalls.add(task);
    return onAdd?.call(projectId, task) ?? ok(task);
  }

  @override
  Future<Response<Object>> delete(int taskId) async {
    deleteCalls.add(taskId);
    return onDelete?.call(taskId) ?? VoidResponse<Object>();
  }

  @override
  Future<Response<Task>> update(Task task) async {
    updateCalls.add(task);
    return onUpdate?.call(task) ?? ok(task);
  }

  @override
  Future<Response<Task>> getTask(int id) async {
    getTaskCalls.add(id);
    return onGetTask?.call(id) ?? ok(buildEmptyTask(id));
  }

  @override
  Future<Response<List<Task>>> getAllByProject(
    int projectId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    getAllByProjectCalls.add((projectId: projectId, query: queryParameters));
    return onGetAllByProject?.call(projectId, queryParameters) ??
        ok<List<Task>>([]);
  }

  @override
  Future<Response<List<Task>>> getAllByProjectView(
    int projectId,
    int view, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    getAllByProjectViewCalls.add((
      projectId: projectId,
      view: view,
      query: queryParameters,
    ));
    return await onGetAllByProjectView?.call(
          projectId,
          view,
          queryParameters,
        ) ??
        ok<List<Task>>([]);
  }

  @override
  Future<Response<List<Task>>> getByFilterString(
    String filterString, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    filterCalls.add(filterString);
    filterQueryCalls.add(queryParameters);
    return onGetByFilterString?.call(filterString, queryParameters) ??
        ok<List<Task>>([]);
  }

  @override
  Future<TaskStatusUpdate> downloadAttachment(
    int taskId,
    TaskAttachment attachment,
  ) async {
    downloadCalls.add(attachment);
    return TaskStatusUpdate(
      DownloadTask(url: 'https://example.com', filename: attachment.file.name),
      TaskStatus.complete,
    );
  }

  static Task buildEmptyTask(int id) =>
      Task(id: id, createdBy: null, projectId: 1);
}

class FakeBucketRepository implements BucketRepository {
  FutureOr<Response<List<Bucket>>> Function(
    int projectId,
    int viewId,
    int page,
  )?
  onGetAllByList;
  Response<Bucket> Function(Bucket bucket)? onAdd;
  Response<Bucket> Function(Bucket bucket)? onUpdate;
  Response<Object> Function(int bucketId)? onDelete;
  Response<Object> Function(int taskId, int viewId, double position)?
  onUpdateTaskPosition;
  Response<Object> Function(int taskId, dynamic bucketId)? onUpdateTaskBucket;

  final List<Bucket> addCalls = [];
  final List<Bucket> updateCalls = [];
  final List<int> deleteCalls = [];
  final List<({int taskId, int viewId, double position})> positionCalls = [];
  final List<({int taskId, dynamic bucketId})> taskBucketCalls = [];
  final List<({int projectId, int viewId, int page})> getAllByListCalls = [];

  @override
  Future<Response<Bucket>> add(int projectId, int viewId, Bucket bucket) async {
    addCalls.add(bucket);
    return onAdd?.call(bucket) ?? ok(bucket);
  }

  @override
  Future<Response<Object>> delete(
    int projectId,
    int viewId,
    int bucketId,
  ) async {
    deleteCalls.add(bucketId);
    return onDelete?.call(bucketId) ?? VoidResponse<Object>();
  }

  @override
  Future<Response<List<Bucket>>> getAllByList(
    int projectId,
    int viewId, [
    Map<String, List<String>>? queryParameters,
  ]) async {
    final page = int.tryParse(queryParameters?['page']?.first ?? '1') ?? 1;
    getAllByListCalls.add((projectId: projectId, viewId: viewId, page: page));
    return await onGetAllByList?.call(projectId, viewId, page) ??
        ok<List<Bucket>>([]);
  }

  @override
  Future<Response<Bucket>> update(
    int projectId,
    int viewId,
    Bucket bucket,
  ) async {
    updateCalls.add(bucket);
    return onUpdate?.call(bucket) ?? ok(bucket);
  }

  @override
  Future<Response<Object>> updateTaskBucket(
    int taskId,
    bucketId,
    projectId,
    int viewId,
  ) async {
    taskBucketCalls.add((taskId: taskId, bucketId: bucketId));
    return onUpdateTaskBucket?.call(taskId, bucketId) ?? VoidResponse<Object>();
  }

  @override
  Future<Response<Object>> updateTaskPosition(
    int taskId,
    int viewId,
    double position,
  ) async {
    positionCalls.add((taskId: taskId, viewId: viewId, position: position));
    return onUpdateTaskPosition?.call(taskId, viewId, position) ??
        VoidResponse<Object>();
  }
}

class FakeProjectViewRepository implements ProjectViewRepository {
  Response<ProjectView> Function(ProjectView view)? onUpdate;
  final List<ProjectView> updateCalls = [];

  @override
  Future<Response<ProjectView>> update(ProjectView view) async {
    updateCalls.add(view);
    return onUpdate?.call(view) ?? ok(view);
  }
}

class FakeTaskCommentRepository implements TaskCommentRepository {
  Response<List<TaskComment>> Function(int taskId)? onGetAll;
  Response<TaskComment> Function(int taskId, TaskComment c)? onCreate;
  Response<TaskComment> Function(int taskId, TaskComment c)? onUpdate;
  Response<Object> Function(int taskId, int commentId)? onDelete;

  final List<TaskComment> createCalls = [];
  final List<TaskComment> updateCalls = [];
  final List<int> deleteCalls = [];
  int getAllCount = 0;

  @override
  Future<Response<List<TaskComment>>> getAll(int taskId) async {
    getAllCount++;
    return onGetAll?.call(taskId) ?? ok<List<TaskComment>>([]);
  }

  @override
  Future<Response<TaskComment>> create(int taskId, TaskComment comment) async {
    createCalls.add(comment);
    return onCreate?.call(taskId, comment) ?? ok(comment);
  }

  @override
  Future<Response<TaskComment>> update(int taskId, TaskComment comment) async {
    updateCalls.add(comment);
    return onUpdate?.call(taskId, comment) ?? ok(comment);
  }

  @override
  Future<Response<Object>> delete(int taskId, int commentId) async {
    deleteCalls.add(commentId);
    return onDelete?.call(taskId, commentId) ?? VoidResponse<Object>();
  }
}

/// Extends the real implementation rather than the interface: the DI provider
/// is declared as returning `LabelRepositoryImpl`, so only a subclass of it can
/// be substituted. The inherited behaviour is never reached — every method is
/// overridden — so the data source it is handed is inert.
class FakeLabelRepository extends LabelRepositoryImpl {
  FakeLabelRepository() : super(LabelDataSource(Client(base: '')));

  Response<List<Label>> Function(String? query)? onGetAll;
  Response<Label> Function(Label label)? onCreate;

  final List<String?> getAllCalls = [];
  final List<Label> createCalls = [];

  @override
  Future<Response<Label>> create(Label label) async {
    createCalls.add(label);
    return onCreate?.call(label) ?? ok(label);
  }

  @override
  Future<Response<List<Label>>> getAll({String? query}) async {
    getAllCalls.add(query);
    return onGetAll?.call(query) ?? ok<List<Label>>([]);
  }
}

class FakeTaskLabelBulkRepository implements TaskLabelBulkRepository {
  Response<List<Label>> Function(Task task, List<Label> labels)? onUpdate;
  final List<List<Label>> updateCalls = [];

  @override
  Future<Response<List<Label>>> update(Task task, List<Label> labels) async {
    updateCalls.add(labels);
    return onUpdate?.call(task, labels) ?? ok(labels);
  }
}

/// Extends the real implementation for the same reason as
/// [FakeLabelRepository]: the provider's declared type is the concrete class.
class FakeTaskLabelRepository extends TaskLabelRepositoryImpl {
  FakeTaskLabelRepository() : super(TaskLabelDataSource(Client(base: '')));

  Response<Label> Function(LabelTask lt)? onDelete;
  final List<LabelTask> deleteCalls = [];

  @override
  Future<Response<Label>> delete(LabelTask lt) async {
    deleteCalls.add(lt);
    return onDelete?.call(lt) ?? ok(lt.label);
  }
}

class FakeUserRepository implements UserRepository {
  Response<User> Function()? onGetCurrentUser;
  Response<UserSettings> Function(UserSettings s)? onSetSettings;

  final List<UserSettings> settingsCalls = [];
  int getCurrentUserCount = 0;

  @override
  Future<Response<User>> getCurrentUser() async {
    getCurrentUserCount++;
    return onGetCurrentUser?.call() ?? ok(User(username: 'testuser'));
  }

  @override
  Future<Response<UserSettings>> setCurrentUserSettings(
    UserSettings userSettings,
  ) async {
    settingsCalls.add(userSettings);
    return onSetSettings?.call(userSettings) ?? ok(userSettings);
  }
}

class FakeServerRepository implements ServerRepository {
  Response<Server> Function()? onGetInfo;
  int getInfoCount = 0;

  @override
  Future<Response<Server>> getInfo() async {
    getInfoCount++;
    return onGetInfo?.call() ??
        ok(
          Server(
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            'v1.0.0',
          ),
        );
  }
}

class FakeVersionRepository implements VersionRepository {
  Version? latest;
  Version? current = Version(0, 1, 8, 'beta');
  int latestCalls = 0;

  @override
  Future<Version?> getLatestVersionTag() async {
    latestCalls++;
    return latest;
  }

  @override
  Future<Version?> getCurrentVersionTag() async => current;
}

/// In-memory [SettingsRepository]. Every setter writes to a public field so a
/// test can assert on persisted state without a storage plugin.
class FakeSettingsRepository implements SettingsRepository {
  bool ignoreCertificates = false;
  bool sentryEnabled = false;
  bool versionNotifications = false;
  int refreshInterval = 0;
  FlutterThemeMode themeMode = FlutterThemeMode.system;
  bool dynamicColors = false;
  bool landingPageOnlyDueDateTasks = false;
  bool sentryDialogShown = true;
  String? server = 'https://vikunja.example.com';
  String? userToken = 'token';
  String? refreshToken = 'refresh';
  String? localeOverride;
  List<String> pastServers = [];
  final Map<int, bool> displayDoneTasks = {};

  @override
  Future<bool> getIgnoreCertificates() async => ignoreCertificates;
  @override
  Future<void> setIgnoreCertificates(bool value) async =>
      ignoreCertificates = value;
  @override
  Future<bool> getSentryEnabled() async => sentryEnabled;
  @override
  Future<void> setSentryEnabled(bool value) async => sentryEnabled = value;
  @override
  Future<bool> getVersionNotifications() async => versionNotifications;
  @override
  Future<void> setVersionNotifications(bool value) async =>
      versionNotifications = value;
  @override
  Future<int> getRefreshInterval() async => refreshInterval;
  @override
  Future<void> setRefreshInterval(int minutes) async =>
      refreshInterval = minutes;
  @override
  Future<FlutterThemeMode> getThemeMode() async => themeMode;
  @override
  Future<void> setThemeMode(FlutterThemeMode newMode) async =>
      themeMode = newMode;
  @override
  Future<void> setDynamicColors(bool value) async => dynamicColors = value;
  @override
  Future<bool> getDynamicColors() async => dynamicColors;
  @override
  Future<bool> getLandingPageOnlyDueDateTasks() async =>
      landingPageOnlyDueDateTasks;
  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool value) async =>
      landingPageOnlyDueDateTasks = value;
  @override
  Future<bool> getDisplayDoneTasks(int projectId) async =>
      displayDoneTasks[projectId] ?? false;
  @override
  Future<void> setDisplayDoneTasks(int projectId, bool value) async =>
      displayDoneTasks[projectId] = value;
  @override
  Future<List<String>> getPastServers() async => pastServers;
  @override
  Future<void> setPastServers(List<String> value) async => pastServers = value;
  @override
  Future<bool> getSentryDialogShown() async => sentryDialogShown;
  @override
  Future<void> setSentryDialogShown(bool value) async =>
      sentryDialogShown = value;
  @override
  Future<String?> getServer() async => server;
  @override
  Future<void> saveServer(String? value) async => server = value;
  @override
  Future<String?> getUserToken() async => userToken;
  @override
  Future<void> saveUserToken(String? token) async => userToken = token;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<void> saveRefreshToken(String? token) async => refreshToken = token;
  @override
  Future<String?> getLocaleOverride() async => localeOverride;
  @override
  Future<void> setLocaleOverride(String? localeCode) async =>
      localeOverride = localeCode;
}
