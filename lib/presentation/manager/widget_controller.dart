import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/project_data_source.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/project_repository_impl.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/widget_task.dart';
import 'package:vikunja_app/domain/entities/widget_view.dart';
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

// Save project list for the widget config activity to read
Future<void> _syncWidgetProjects(Client client) async {
  final projectService = ProjectRepositoryImpl(ProjectDataSource(client));
  final projectsResponse = await projectService.getAll();
  if (projectsResponse.isSuccessful) {
    final projects = projectsResponse.toSuccess().body;
    final projectsJson = jsonEncode(
      projects.map((p) => {'id': p.id, 'title': p.title}).toList(),
    );
    await HomeWidget.saveWidgetData('WidgetProjects', projectsJson);
  }
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
  bool wgToday = dueLocal != null &&
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
    await _syncWidgetProjects(client);

    final widgetIdsJson =
        await HomeWidget.getWidgetData<String>('WidgetIds') ?? '[]';
    final widgetIds = (jsonDecode(widgetIdsJson) as List).cast<String>();

    final taskService = TaskRepositoryImpl(TaskDataSource(client));
    for (final widgetId in widgetIds) {
      await _updateWidgetId(widgetId, taskService);
    }

    await reRenderWidget();
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
    await _syncWidgetProjects(client);

    final taskService = TaskRepositoryImpl(TaskDataSource(client));
    await _updateWidgetId(widgetId, taskService);
    await reRenderWidget();
  } catch (e, s) {
    developer.log('Update widget $widgetId error:', error: e, stackTrace: s);
  }
}

Future<void> _updateWidgetId(
  String widgetId,
  TaskRepositoryImpl taskService,
) async {
  final rawViewStr = await HomeWidget.getWidgetData<String>('widget_view_$widgetId');
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
        {'filter_include_nulls': ['false']},
      );
      success = result.isSuccessful;
      if (success) tasks = result.toSuccess().body;

    case WidgetView.project:
      final projectId =
          int.tryParse(
            await HomeWidget.getWidgetData<String>(
                  'widget_project_id_$widgetId',
                ) ??
                '0',
          ) ??
          0;
      final projectName =
          await HomeWidget.getWidgetData<String>('widget_project_name_$widgetId');
      if (projectId != 0) {
        final result = await taskService.getAllByProject(projectId);
        success = result.isSuccessful;
        if (success) {
          tasks = result.toSuccess().body.where((t) => !t.done).toList();
        }
      }
      title = projectName ?? view.displayName;
  }

  await HomeWidget.saveWidgetData('widget_title_$widgetId', title);
  // Don't clobber a good cache with an empty list when the fetch failed.
  if (success) {
    await _saveWidgetTasks(widgetId, tasks);
  }
}

Future<void> _saveWidgetTasks(String widgetId, List<Task> tasks) async {
  final data = jsonEncode(tasks.map((e) => convertTask(e).toJSON()).toList());
  await HomeWidget.saveWidgetData('WidgetTasks_$widgetId', data);
}

Future<void> reRenderWidget() async {
  await HomeWidget.updateWidget(
    name: 'AppWidget',
    qualifiedAndroidName: 'io.vikunja.app.widget.AppWidgetReciever',
  );
}
