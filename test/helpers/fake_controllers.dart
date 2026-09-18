/// Stand-in controllers for page tests.
///
/// A page test is about wiring: which controller method a tap reaches, what the
/// page renders for a given state, which snackbar or route follows. The
/// controllers' own logic is covered in `test/presentation/manager/`, so these
/// fakes short-circuit it and record the calls instead.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/project_page_model.dart';
import 'package:vikunja_app/domain/entities/project_list_model.dart';
import 'package:vikunja_app/domain/entities/settings_page_state.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';

/// Shared record of what a page asked its controller to do.
class ControllerCalls {
  final List<String> methods = [];
  final List<Task> addedTasks = [];
  final List<Task> updatedTasks = [];
  final List<Task> doneTasks = [];
  final List<int> deletedTaskIds = [];
  final List<Project> createdProjects = [];
  final List<Project> updatedProjects = [];
  final List<Bucket> addedBuckets = [];
  final List<Bucket> updatedBuckets = [];
  final List<Bucket> deletedBuckets = [];
  final List<bool> displayDoneTaskChanges = [];
  final List<bool> onlyDueDateChanges = [];
  final List<int> viewIndexes = [];
  final List<String> addedComments = [];
  final List<int> deletedCommentIds = [];
  final List<(TaskComment, String)> updatedComments = [];
  final List<({List<int> order, int movedTaskId, double newPosition})>
  reorders = [];
  final List<({int taskId, int toBucketId, double position})> moves = [];

  void record(String method) => methods.add(method);

  bool called(String method) => methods.contains(method);
}

/// Controls whether the fake reports success or failure back to the page.
class FakeOutcome {
  bool succeeds = true;
}

class FakeTaskPageController extends TaskPageController {
  FakeTaskPageController(this.model, this.calls, this.outcome);

  final TaskPageModel model;
  final ControllerCalls calls;
  final FakeOutcome outcome;

  @override
  Future<TaskPageModel> build() async => model;

  @override
  void reload() => calls.record('reload');

  @override
  Future<void> loadNextPage() async => calls.record('loadNextPage');

  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool newValue) async {
    calls.record('setLandingPageOnlyDueDateTasks');
    calls.onlyDueDateChanges.add(newValue);
  }

  @override
  Future<bool> addTask(int projectId, Task task) async {
    calls.record('addTask');
    calls.addedTasks.add(task);
    return outcome.succeeds;
  }

  @override
  Future<bool> deleteTask(int id) async {
    calls.record('deleteTask');
    calls.deletedTaskIds.add(id);
    return outcome.succeeds;
  }

  @override
  Future<bool> updateTask(Task task) async {
    calls.record('updateTask');
    calls.updatedTasks.add(task);
    return outcome.succeeds;
  }

  @override
  Future<bool> markAsDone(Task task) async {
    calls.record('markAsDone');
    calls.doneTasks.add(task);
    return outcome.succeeds;
  }
}

class FakeProjectsController extends ProjectsController {
  FakeProjectsController(this.model, this.calls);

  final ProjectListModel model;
  final ControllerCalls calls;

  @override
  Future<ProjectListModel> build() async => model;

  @override
  void reload() => calls.record('reload');

  @override
  Future<void> loadNextPage() async => calls.record('loadNextPage');

  @override
  void create(Project project) {
    calls.record('create');
    calls.createdProjects.add(project);
  }
}

class FakeProjectController extends ProjectController {
  FakeProjectController(this.model, this.calls, this.outcome);

  final ProjectPageModel model;
  final ControllerCalls calls;
  final FakeOutcome outcome;

  @override
  Future<ProjectPageModel> build(Project project) async => model;

  /// Replaces what the page shows, the way a reload would.
  void emit(ProjectPageModel next) => state = AsyncData(next);

  @override
  void reload() => calls.record('reload');

  @override
  Future<void> loadNextPage() async => calls.record('loadNextPage');

  @override
  Future<void> loadForView(Project project, int viewIndex) async {
    calls.record('loadForView');
    calls.viewIndexes.add(viewIndex);
  }

  @override
  Future<bool> addTask(Project project, Task newTask) async {
    calls.record('addTask');
    calls.addedTasks.add(newTask);
    return outcome.succeeds;
  }

  @override
  Future<bool> markAsDone(Task task) async {
    calls.record('markAsDone');
    calls.doneTasks.add(task);
    return outcome.succeeds;
  }

  @override
  Future<bool> updateProject(Project project) async {
    calls.record('updateProject');
    calls.updatedProjects.add(project);
    return outcome.succeeds;
  }

  @override
  Future<bool> setDisplayDoneTasks(bool displayDoneTasks) async {
    calls.record('setDisplayDoneTasks');
    calls.displayDoneTaskChanges.add(displayDoneTasks);
    return outcome.succeeds;
  }

  @override
  Future<bool> addBucket({
    required Bucket newBucket,
    required Project project,
    required int viewId,
  }) async {
    calls.record('addBucket');
    calls.addedBuckets.add(newBucket);
    return outcome.succeeds;
  }

  @override
  Future<bool> updateBucket({
    required Bucket bucket,
    required Project project,
  }) async {
    calls.record('updateBucket');
    calls.updatedBuckets.add(bucket);
    return outcome.succeeds;
  }

  @override
  Future<bool> deleteBucket({
    required Bucket bucket,
    required Project project,
  }) async {
    calls.record('deleteBucket');
    calls.deletedBuckets.add(bucket);
    return outcome.succeeds;
  }

  @override
  Future<bool> updateDoneBucket(
    Project project,
    int bucketId,
    isDoneColumn,
  ) async {
    calls.record('updateDoneBucket');
    return outcome.succeeds;
  }

  @override
  Future<bool> selectDefaultBucket(
    Project project,
    int bucketId,
    isDefaultColumn,
  ) async {
    calls.record('selectDefaultBucket');
    return outcome.succeeds;
  }

  @override
  Future<bool> moveTask(
    Project project,
    Task task,
    Bucket bucket,
    double position,
  ) async {
    calls.record('moveTask');
    calls.moves.add((
      taskId: task.id,
      toBucketId: bucket.id,
      position: position,
    ));
    return outcome.succeeds;
  }

  @override
  Future<bool> reorderTasks({
    required Project project,
    required List<Task> newOrderedTasks,
    required int movedTaskId,
    required double newPosition,
  }) async {
    calls.record('reorderTasks');
    calls.reorders.add((
      order: newOrderedTasks.map((t) => t.id).toList(),
      movedTaskId: movedTaskId,
      newPosition: newPosition,
    ));
    return outcome.succeeds;
  }
}

class FakeTaskCommentsController extends TaskCommentsController {
  FakeTaskCommentsController(this.comments, this.calls, this.outcome);

  final List<TaskComment> comments;
  final ControllerCalls calls;
  final FakeOutcome outcome;

  @override
  Future<List<TaskComment>> build(int taskId) async => comments;

  @override
  Future<void> reload() async => calls.record('reload');

  @override
  Future<bool> addComment(String text) async {
    calls.record('addComment');
    calls.addedComments.add(text);
    return outcome.succeeds;
  }

  @override
  Future<bool> updateComment(TaskComment comment, String text) async {
    calls.record('updateComment');
    calls.updatedComments.add((comment, text));
    return outcome.succeeds;
  }

  @override
  Future<bool> deleteComment(int commentId) async {
    calls.record('deleteComment');
    calls.deletedCommentIds.add(commentId);
    return outcome.succeeds;
  }
}

class FakeSettingsController extends SettingsController {
  FakeSettingsController(this.pageState, this.calls);

  final SettingsPageState pageState;
  final ControllerCalls calls;

  final List<Object?> setValues = [];

  @override
  Future<SettingsPageState> build() async => pageState;

  @override
  Future<void> refresh() async => calls.record('refresh');

  @override
  Future<void> setThemeMode(mode) async {
    calls.record('setThemeMode');
    setValues.add(mode);
  }

  @override
  Future<void> setDynamicColors(bool dynamicColors) async {
    calls.record('setDynamicColors');
    setValues.add(dynamicColors);
  }

  @override
  Future<void> setSentryEnabled(bool value) async {
    calls.record('setSentryEnabled');
    setValues.add(value);
  }

  @override
  Future<void> setIgnoreCertificates(bool value) async {
    calls.record('setIgnoreCertificates');
    setValues.add(value);
  }

  @override
  Future<void> setRefreshInterval(int minutes) async {
    calls.record('setRefreshInterval');
    setValues.add(minutes);
  }

  @override
  Future<void> setVersionNotifications(bool value) async {
    calls.record('setVersionNotifications');
    setValues.add(value);
  }

  @override
  void setDefaultProject(int value) {
    calls.record('setDefaultProject');
    setValues.add(value);
  }
}

/// A controller whose build never completes, so the page shows its loader.
class PendingTaskPageController extends TaskPageController {
  @override
  Future<TaskPageModel> build() => Completer<TaskPageModel>().future;
}

class PendingProjectsController extends ProjectsController {
  @override
  Future<ProjectListModel> build() => Completer<ProjectListModel>().future;
}

class PendingProjectController extends ProjectController {
  @override
  Future<ProjectPageModel> build(Project project) =>
      Completer<ProjectPageModel>().future;
}

class PendingSettingsController extends SettingsController {
  @override
  Future<SettingsPageState> build() => Completer<SettingsPageState>().future;
}

/// A controller that fails to build, so the page shows its error view.
class FailingTaskPageController extends TaskPageController {
  FailingTaskPageController([this.error = 'boom']);

  final Object error;

  @override
  Future<TaskPageModel> build() async => throw error;
}

class FailingProjectsController extends ProjectsController {
  FailingProjectsController([this.error = 'boom']);

  final Object error;

  @override
  Future<ProjectListModel> build() async => throw error;
}

class FailingProjectController extends ProjectController {
  FailingProjectController([this.error = 'boom']);

  final Object error;

  @override
  Future<ProjectPageModel> build(Project project) async => throw error;
}

class FailingSettingsController extends SettingsController {
  FailingSettingsController([this.error = 'boom']);

  final Object error;

  @override
  Future<SettingsPageState> build() async => throw error;
}

class FailingTaskCommentsController extends TaskCommentsController {
  @override
  Future<List<TaskComment>> build(int taskId) async => throw 'boom';
}

/// Convenience overrides so a page test reads as one line per provider.
Override taskPageOverride(
  TaskPageModel model,
  ControllerCalls calls,
  FakeOutcome outcome,
) => taskPageControllerProvider.overrideWith(
  () => FakeTaskPageController(model, calls, outcome),
);

Override projectsOverride(ProjectListModel model, ControllerCalls calls) =>
    projectsControllerProvider.overrideWith(
      () => FakeProjectsController(model, calls),
    );

Override projectOverride(
  Project project,
  ProjectPageModel model,
  ControllerCalls calls,
  FakeOutcome outcome,
) => projectControllerProvider(
  project,
).overrideWith(() => FakeProjectController(model, calls, outcome));

Override commentsOverride(
  int taskId,
  List<TaskComment> comments,
  ControllerCalls calls,
  FakeOutcome outcome,
) => taskCommentsControllerProvider(
  taskId,
).overrideWith(() => FakeTaskCommentsController(comments, calls, outcome));

Override settingsOverride(SettingsPageState state, ControllerCalls calls) =>
    settingsControllerProvider.overrideWith(
      () => FakeSettingsController(state, calls),
    );

Override taskPageControllerProviderOverridePending() =>
    taskPageControllerProvider.overrideWith(PendingTaskPageController.new);

Override taskPageControllerProviderOverrideFailing([Object error = 'boom']) =>
    taskPageControllerProvider.overrideWith(
      () => FailingTaskPageController(error),
    );

Override projectsControllerProviderOverridePending() =>
    projectsControllerProvider.overrideWith(PendingProjectsController.new);

Override projectsControllerProviderOverrideFailing([Object error = 'boom']) =>
    projectsControllerProvider.overrideWith(
      () => FailingProjectsController(error),
    );

Override projectControllerProviderOverridePending(Project project) =>
    projectControllerProvider(
      project,
    ).overrideWith(PendingProjectController.new);

Override projectControllerProviderOverrideFailing(
  Project project, [
  Object error = 'boom',
]) => projectControllerProvider(
  project,
).overrideWith(() => FailingProjectController(error));

Override settingsControllerProviderOverridePending() =>
    settingsControllerProvider.overrideWith(PendingSettingsController.new);

Override settingsControllerProviderOverrideFailing([Object error = 'boom']) =>
    settingsControllerProvider.overrideWith(
      () => FailingSettingsController(error),
    );

Override commentsControllerProviderOverrideFailing(int taskId) =>
    taskCommentsControllerProvider(
      taskId,
    ).overrideWith(FailingTaskCommentsController.new);

/// A task page model with sensible defaults for page tests.
TaskPageModel buildTaskPageModel(
  List<Task> tasks, {
  bool onlyDueDate = false,
  int defaultProjectId = 4,
  bool isLoadingNextPage = false,
}) => TaskPageModel(
  List.of(tasks),
  onlyDueDate,
  defaultProjectId,
  isLoadingNextPage,
);

/// A project page model with sensible defaults for page tests.
ProjectPageModel buildProjectPageModel(
  Project project, {
  List<Task> tasks = const [],
  List<Bucket> buckets = const [],
  int viewIndex = 0,
  bool displayDoneTask = false,
  bool isLoadingNextPage = false,
}) => ProjectPageModel(
  project,
  viewIndex,
  List.of(tasks),
  List.of(buckets),
  displayDoneTask,
  isLoadingNextPage,
);

/// A settings page state with sensible defaults for page tests.
SettingsPageState buildSettingsState({
  required User user,
  List<Project> projects = const [],
  bool ignoreCertificates = false,
  bool sentryEnabled = false,
  bool versionNotifications = false,
  int refreshInterval = 0,
  FlutterThemeMode? themeMode,
  bool dynamicColors = false,
  Version? currentVersion,
}) => SettingsPageState(
  user,
  projects,
  ignoreCertificates,
  sentryEnabled,
  versionNotifications,
  refreshInterval,
  themeMode ?? FlutterThemeMode.system,
  dynamicColors,
  currentVersion,
);
