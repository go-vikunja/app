import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/home_widget_store.dart';
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/widget_task.dart';
import 'package:vikunja_app/domain/entities/widget_view.dart';
import 'package:vikunja_app/domain/repositories/project_repository.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

Future<Client?> _initWidgetClient(SettingsDatasource datasource) async {
  var base = await datasource.getServer();
  var refreshToken = await datasource.getRefreshToken();
  if (refreshToken == null || base == null) return null;

  Client client = Client(base: base);
  tz.initializeTimeZones();

  var ignoreCertificates = await datasource.getIgnoreCertificates();
  client.setIgnoreCerts(ignoreCertificates);
  return client;
}

/// Saves every page of the signed-in account's projects — including saved
/// filters, which the server lists as pseudo-projects with negative ids —
/// into the widget data store for the configuration screen's pickers.
///
/// A failed fetch keeps the last good list so the pickers never go blank.
Future<void> syncWidgetProjectOptions({
  required ProjectRepository projectService,
  required HomeWidgetStore store,
}) async {
  final projects = <Project>[];
  for (var page = 1; ; page++) {
    final response = await projectService.getAll(page: page);
    if (!response.isSuccessful) return;

    final success = response.toSuccess();
    projects.addAll(success.body);

    final headers = success.headers.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    final totalPages =
        int.tryParse(headers['x-pagination-total-pages'] ?? '1') ?? 1;
    if (page >= totalPages) break;
  }

  final projectsJson = jsonEncode(
    projects.map((p) => {'id': p.id, 'title': p.title}).toList(),
  );
  await store.write('WidgetProjects', projectsJson);
}

Future<void> completeTask(String taskID) async {
  if (taskID == "null") {
    developer.log("Tried to complete an empty task");
    return;
  }

  var datasource = SettingsDatasource(FlutterSecureStorage());
  final client = await _initWidgetClient(datasource);
  if (client == null) {
    developer.log("There was an error initialising the client");
    return;
  }

  TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
  var taskResponse = await taskService.getTask(int.parse(taskID));
  var task = taskResponse.toSuccess().body;
  await taskService.update(task.copyWith(done: true));
  await updateWidget();
}

WidgetTask convertTask(Task task) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final effectiveDueDate = task.hasDueDate ? task.dueDate : null;
  final dueLocal = effectiveDueDate?.toLocal();
  bool wgToday =
      dueLocal != null &&
      dueLocal.year == today.year &&
      dueLocal.month == today.month &&
      dueLocal.day == today.day;

  return WidgetTask(
    id: task.id.toString(),
    title: task.title,
    dueDate: effectiveDueDate,
    today: wgToday,
  );
}

List<Task> filterForDueTasks(List<Task> tasks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return tasks
      .where((t) => t.dueDate != null && t.dueDate!.day == today.day)
      .toList();
}

Future<void> updateWidget() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  final client = await _initWidgetClient(datasource);
  if (client == null) return;

  try {
    final store = HomeWidgetPluginStore();
    await syncWidgetProjectOptions(
      projectService: ProjectRepositoryImpl(ProjectDataSource(client)),
      store: store,
    );

    final widgetIdsJson = await store.read<String>('WidgetIds') ?? '[]';
    final widgetIds = (jsonDecode(widgetIdsJson) as List).cast<String>();

    final taskService = TaskRepositoryImpl(TaskDataSource(client));
    for (final widgetId in widgetIds) {
      await updateWidgetInstance(
        widgetId,
        store: store,
        taskService: taskService,
      );
    }

    await store.rerenderWidget();
  } catch (e, s) {
    developer.log('Update widget error:', error: e, stackTrace: s);
  }
}

Future<void> updateWidgetForId(String? widgetId) async {
  if (widgetId == null) {
    await updateWidget();
    return;
  }

  var datasource = SettingsDatasource(FlutterSecureStorage());
  final client = await _initWidgetClient(datasource);
  if (client == null) {
    developer.log('updateWidgetForId: skipped — missing token or base URL');
    return;
  }

  try {
    final store = HomeWidgetPluginStore();
    await syncWidgetProjectOptions(
      projectService: ProjectRepositoryImpl(ProjectDataSource(client)),
      store: store,
    );

    final taskService = TaskRepositoryImpl(TaskDataSource(client));
    await updateWidgetInstance(
      widgetId,
      store: store,
      taskService: taskService,
    );
    await store.rerenderWidget();
  } catch (e, s) {
    developer.log('Update widget $widgetId error:', error: e, stackTrace: s);
  }
}

/// Fetches the tasks for one widget instance's configured view and persists
/// them for the native widget to render.
///
/// Saved filters are configured like projects (view `project` with a
/// negative project id); the server resolves the id to the filter
/// expression, and only the filter's undone tasks are rendered.
Future<void> updateWidgetInstance(
  String widgetId, {
  required HomeWidgetStore store,
  required TaskRepository taskService,
}) async {
  final rawViewStr = await store.read<String>('widget_view_$widgetId');
  final viewStr = rawViewStr ?? 'today';
  final view = WidgetView.fromString(viewStr);

  List<Task> tasks = [];
  String title = view.displayName;
  bool success = true;

  switch (view) {
    case WidgetView.inbox:
      final result = await taskService.getByFilterString('done = false');
      success = result.isSuccessful;
      if (success) tasks = result.toSuccess().body;

    case WidgetView.today:
      final result = await taskService.getByFilterString(
        'done = false && due_date < now/d+1d',
      );
      success = result.isSuccessful;
      if (success) tasks = result.toSuccess().body;

    case WidgetView.upcoming:
      final result = await taskService.getByFilterString(
        'done = false && due_date >= now/d && due_date < now/d+7d',
        {
          'filter_include_nulls': ['false'],
        },
      );
      success = result.isSuccessful;
      if (success) tasks = result.toSuccess().body;

    case WidgetView.project:
      final projectId =
          int.tryParse(
            await store.read<String>('widget_project_id_$widgetId') ?? '0',
          ) ??
          0;
      final projectName = await store.read<String>(
        'widget_project_name_$widgetId',
      );
      if (projectId != 0) {
        // A negative id is a saved filter; the server resolves it to the
        // filter expression, so the fetch is shared with real projects.
        final result = await taskService.getAllByProject(projectId);
        success = result.isSuccessful;
        if (success) {
          tasks = result.toSuccess().body.where((t) => !t.done).toList();
        }
      }
      title = projectName ?? view.displayName;
  }

  await store.write('widget_title_$widgetId', title);
  // Don't clobber a good cache with an empty list when the fetch failed.
  if (success) {
    await _saveWidgetTasks(store, widgetId, tasks);
  }
}

Future<void> _saveWidgetTasks(
  HomeWidgetStore store,
  String widgetId,
  List<Task> tasks,
) async {
  final data = jsonEncode(tasks.map((e) => convertTask(e).toJSON()).toList());
  await store.write('WidgetTasks_$widgetId', data);
}
