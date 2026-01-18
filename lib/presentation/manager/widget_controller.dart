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

void completeTask(String taskID) async {
  if (taskID == "null") {
    developer.log("Tried to complete an empty task");
  }

  var datasource = SettingsDatasource(FlutterSecureStorage());
  var token = await datasource.getUserToken();
  var base = await datasource.getServer();

  if (token != null && base != null) {
    Client client = Client(token: token, base: base);
    tz.initializeTimeZones();

    var ignoreCertificates = await datasource.getIgnoreCertificates();
    client.setIgnoreCerts(ignoreCertificates);

    TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
    var taskResponse = await taskService.getTask(int.parse(taskID));
    var task = taskResponse.toSuccess().body;
    await taskService.update(task.copyWith(done: true));
    updateWidget();
  } else {
    developer.log("There was an error initialising the client");
  }
}

WidgetTask convertTask(Task task) {
  // Check if task is for today
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool wgToday = task.dueDate!.day == today.day ? true : false;

  WidgetTask wgTask = WidgetTask(
    id: task.id.toString(),
    title: task.title,
    dueDate: task.dueDate,
    today: wgToday,
  );
  return wgTask;
}

List<Task> filterForDueTasks(List<Task> tasks) {
  var todayTasks = <Task>[];

  for (var task in tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (task.dueDate!.day == today.day) {
      todayTasks.add(task);
    }
  }
  return todayTasks;
}

Future<void> updateWidget() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var token = await datasource.getUserToken();
  var base = await datasource.getServer();

  if (token != null && base != null) {
    Client client = Client(token: token, base: base);
    tz.initializeTimeZones();

    var ignoreCertificates = await datasource.getIgnoreCertificates();
    client.setIgnoreCerts(ignoreCertificates);

    try {
      TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));
      var widgetTasks = await taskService.getByFilterString(
        "done = false && due_date < now/d+1d",
      );
      if (widgetTasks.isSuccessful) {
        updateWidgetTasks(widgetTasks.toSuccess().body);
      }
    } catch (e, s) {
      developer.log("Update widget error:", error: e, stackTrace: s);
    }
  }
}

void updateWidgetTasks(List<Task> tasklist) async {
  var widgetTaskIDs = [];

  for (var task in tasklist) {
    widgetTaskIDs.add(task.id);
    var wgTask = convertTask(task);
    await HomeWidget.saveWidgetData(
      task.id.toString(),
      jsonEncode(wgTask.toJSON()),
    );
  }
  HomeWidget.saveWidgetData("WidgetTaskIDs", widgetTaskIDs.toString());
  reRenderWidget();
}

void reRenderWidget() {
  HomeWidget.updateWidget(
    name: 'AppWidget',
    qualifiedAndroidName:
        'io.vikunja.flutteringvikunja.widget.AppWidgetReciever',
  );
}
