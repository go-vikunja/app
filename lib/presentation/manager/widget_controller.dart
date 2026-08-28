import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/widget_task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

Future<void> completeTask(String taskID) async {
  if (taskID == "null") {
    developer.log("Tried to complete an empty task");
    return;
  }

  var datasource = SettingsDatasource(FlutterSecureStorage());
  var base = await datasource.getServer();
  var refreshToken = await datasource.getRefreshToken();

  if (refreshToken != null && base != null) {
    Client client = Client(base: base);
    tz.initializeTimeZones();

    var ignoreCertificates = await datasource.getIgnoreCertificates();
    client.setIgnoreCerts(ignoreCertificates);

    TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
    var taskResponse = await taskService.getTask(int.parse(taskID));
    var task = taskResponse.toSuccess().body;
    await taskService.update(task.copyWith(done: true));

    // Local refresh: remove completed task from cached widget data immediately
    await _removeCompletedTaskFromWidget(taskID);
    // Then do a full server sync in the background
    updateWidget();
  } else {
    developer.log("There was an error initialising the client");
  }
}

/// Remove a completed task from the local widget data and re-render
Future<void> _removeCompletedTaskFromWidget(String taskID) async {
  try {
    String? data = await HomeWidget.getWidgetData<String>("WidgetTasks");
    if (data != null) {
      List<dynamic> tasks = jsonDecode(data);
      tasks.removeWhere((t) => t['id'].toString() == taskID);
      await HomeWidget.saveWidgetData("WidgetTasks", jsonEncode(tasks));
      await reRenderWidget();
    }
  } catch (e) {
    developer.log("Error removing task from widget: $e");
  }
}

WidgetTask? convertTask(Task task) {
  final dueDate = task.dueDate;
  if (dueDate == null) {
    // Tasks without a due date aren't shown in the widget
    return null;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Task is "today" if due date is within today (same day)
  bool wgToday =
      dueDate.isAfter(today.subtract(Duration(days: 1))) &&
      dueDate.isBefore(today.add(Duration(days: 1)));

  WidgetTask wgTask = WidgetTask(
    id: task.id.toString(),
    title: task.title,
    dueDate: dueDate,
    today: wgToday,
  );
  return wgTask;
}

List<Task> filterForDueTasks(List<Task> tasks) {
  var todayTasks = <Task>[];
  for (var task in tasks) {
    final dueDate = task.dueDate;
    if (dueDate == null) continue;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (dueDate.isAfter(today.subtract(Duration(days: 1))) &&
        dueDate.isBefore(today.add(Duration(days: 1)))) {
      todayTasks.add(task);
    }
  }
  return todayTasks;
}

Future<void> updateWidget() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var refreshToken = await datasource.getRefreshToken();
  var base = await datasource.getServer();

  if (refreshToken != null && base != null) {
    try {
      Client client = Client(base: base);
      tz.initializeTimeZones();

      var ignoreCertificates = await datasource.getIgnoreCertificates();
      client.setIgnoreCerts(ignoreCertificates);

      TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));

      var lookaheadDays = await datasource.getWidgetLookaheadDays();
      var widgetTasks = await taskService.getByFilterString(
        "done = false && due_date < now/d+${lookaheadDays}d",
      );

      if (widgetTasks.isSuccessful) {
        await updateWidgetTasks(widgetTasks.toSuccess().body);
      }
    } catch (e, s) {
      developer.log("Update widget error:", error: e, stackTrace: s);
    }
  }
}

Future<void> updateWidgetTasks(List<Task> tasklist) async {
  var widgetTasks = tasklist
      .map((e) => convertTask(e))
      .whereType<WidgetTask>()
      .toList();
  var data = jsonEncode(widgetTasks.map((e) => e.toJSON()).toList());
  await HomeWidget.saveWidgetData("WidgetTasks", data);
  await reRenderWidget();
}

Future<void> reRenderWidget() async {
  await HomeWidget.updateWidget(
    name: 'AppWidget',
    qualifiedAndroidName: 'io.vikunja.app.widget.AppWidgetReciever',
  );
}
