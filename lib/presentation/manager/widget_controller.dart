import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';

List<Task> filterForTodayTasks(List<Task> tasks) {
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
        "due_date > 0001-01-01 00:00 && done = false",
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
  var todayTasks = filterForTodayTasks(tasklist);

  // Set the number of tasks
  HomeWidget.saveWidgetData('numTasks', todayTasks.length);
  DateFormat timeFormat = DateFormat("HH:mm");
  var num = 0;
  for (var task in todayTasks) {
    num++;
    var widgetTask = [timeFormat.format(task.dueDate!), task.title];
    final jsonString = jsonEncode(widgetTask);
    HomeWidget.saveWidgetData(num.toString(), jsonString);
  }

  // Update the widget
  HomeWidget.updateWidget(
    name: 'AppWidget',
    qualifiedAndroidName: 'io.vikunja.flutteringvikunja.AppWidgetReciever',
  );
}
