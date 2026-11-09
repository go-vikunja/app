import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/trash_repository.dart';

/// The server's trash as both fakes hold it, in [trashedTasks] and
/// [trashedProjects], newest deletion first as the server lists them. Each
/// call is added to [calls] first (`tasks`, `taskCount`, `emptyTasks`,
/// `deleteTaskForever 41`, …); [beforeCall] can hold it, and the entry of
/// [failures] for the method name is thrown instead while set, with nothing
/// changed. Deleting an item forever removes it; emptying the tasks removes
/// those with `canDeletePermanently`, emptying the projects every project.
mixin _TrashContents {
  List<TrashedTask> trashedTasks = [];
  List<TrashedProject> trashedProjects = [];

  /// What `taskCount` answers; by default the trashed tasks with
  /// `canDeletePermanently`, none of them by others.
  TrashCount? taskCountAnswer;

  /// What `projectCount` answers; by default every trashed project, none
  /// of them by others.
  TrashCount? projectCountAnswer;

  final Map<String, Object> failures = {};
  final List<String> calls = [];
  Future<void> Function(String call)? beforeCall;

  Future<void> _call(String method, [String detail = '']) async {
    calls.add(detail.isEmpty ? method : '$method $detail');
    await beforeCall?.call(calls.last);
    if (failures[method] case final failure?) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
  }

  Future<List<TrashedTask>> tasks() async {
    await _call('tasks');
    return List.unmodifiable(trashedTasks);
  }

  Future<List<TrashedProject>> projects() async {
    await _call('projects');
    return List.unmodifiable(trashedProjects);
  }

  Future<TrashCount> taskCount() async {
    await _call('taskCount');
    return taskCountAnswer ??
        TrashCount(
          total: trashedTasks.where((item) => item.canDeletePermanently).length,
          byOthers: 0,
        );
  }

  Future<TrashCount> projectCount() async {
    await _call('projectCount');
    return projectCountAnswer ??
        TrashCount(total: trashedProjects.length, byOthers: 0);
  }

  Future<void> deleteTaskForever(int taskId) async {
    await _call('deleteTaskForever', '$taskId');
    trashedTasks = [
      for (final item in trashedTasks)
        if (item.task.id != taskId) item,
    ];
  }

  Future<void> deleteProjectForever(int projectId) async {
    await _call('deleteProjectForever', '$projectId');
    trashedProjects = [
      for (final item in trashedProjects)
        if (item.project.id != projectId) item,
    ];
  }

  void _emptyTasks() => trashedTasks = [
    for (final item in trashedTasks)
      if (!item.canDeletePermanently) item,
  ];

  /// The trashed task with [taskId], taken out of the trash; null when
  /// there is none.
  Task? takeTask(int taskId) {
    final item = trashedTasks
        .where((item) => item.task.id == taskId)
        .firstOrNull;
    if (item == null) return null;
    trashedTasks = [
      for (final other in trashedTasks)
        if (other != item) other,
    ];
    return item.task;
  }

  /// The trashed project with [projectId], taken out of the trash; null
  /// when there is none.
  TrashedProject? takeProject(int projectId) {
    final item = trashedProjects
        .where((item) => item.project.id == projectId)
        .firstOrNull;
    if (item == null) return null;
    trashedProjects = [
      for (final other in trashedProjects)
        if (other != item) other,
    ];
    return item;
  }
}

/// The bin page's trash, see [_TrashContents]. The account's task and
/// project fakes take their restores out of it.
final class FakeTrashRepository with _TrashContents implements TrashRepository {
  @override
  Future<void> emptyTasks() async {
    await _call('emptyTasks');
    _emptyTasks();
  }

  @override
  Future<void> emptyProjects() async {
    await _call('emptyProjects');
    trashedProjects = [];
  }
}

/// The trash routes for repository tests, see [_TrashContents]; an empty
/// is recorded with its flag, as `emptyTasks includeOthers: true`. A
/// restore answers [restoredTasks] or [restoredProjects] and takes the item
/// out of the trash; otherwise it throws `NotFound` code 4002 for a task,
/// 3001 for a project.
final class FakeTrashPort with _TrashContents implements TrashPort {
  final Map<int, Task> restoredTasks = {};
  final Map<int, Project> restoredProjects = {};

  @override
  Future<void> emptyTasks({bool includeOthers = true}) async {
    await _call('emptyTasks', 'includeOthers: $includeOthers');
    _emptyTasks();
  }

  @override
  Future<void> emptyProjects({bool includeOthers = true}) async {
    await _call('emptyProjects', 'includeOthers: $includeOthers');
    trashedProjects = [];
  }

  @override
  Future<Task> restoreTask(int id) async {
    await _call('restoreTask', '$id');
    final task = restoredTasks[id] ?? (throw const NotFound(code: 4002));
    takeTask(id);
    return task;
  }

  @override
  Future<Project> restoreProject(int id) async {
    await _call('restoreProject', '$id');
    final project = restoredProjects[id] ?? (throw const NotFound(code: 3001));
    takeProject(id);
    return project;
  }
}
