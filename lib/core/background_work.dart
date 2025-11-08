import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:vikunja_app/core/network/client.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/data_sources/task_data_source.dart';
import 'package:vikunja_app/data/data_sources/user_data_source.dart';
import 'package:vikunja_app/data/repositories/task_repository_impl.dart';
import 'package:vikunja_app/domain/repositories/task_repository.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/widget_controller.dart';
import 'package:workmanager/workmanager.dart';

@pragma("vm:entry-point")
Future<void> widgetCallback(Uri? uri) async {
  if (uri?.host == "completetask") {
    completeTask();
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) {
    return;
  }
  Workmanager().executeTask((task, inputData) async {
    developer.log("Native called background task: $task");

    switch (task) {
      case "update-tasks":
        return updateTasks();
      case "refresh-token":
        return refreshToken();
      default:
        return Future.value(true);
    }
  });
}

/// Loads all tasks from the server to update the widget
/// and schedule notifications for due tasks
///
/// We do need this here too for tasks that are created on the server
/// and were not yet loaded in the app
Future<bool> updateTasks() async {
  var datasource = SettingsDatasource(FlutterSecureStorage());
  var token = await datasource.getUserToken();
  var base = await datasource.getServer();

  if (token == null || base == null) {
    return Future.value(true);
  }

  Client client = Client(token: token, base: base);
  tz.initializeTimeZones();

  var ignoreCertificates = await datasource.getIgnoreCertificates();
  client.setIgnoreCerts(ignoreCertificates);

  TaskRepository taskService = TaskRepositoryImpl(TaskDataSource(client));

  updateWidget();

  NotificationHandler notificationHandler = NotificationHandler();
  await notificationHandler.initNotifications();
  await notificationHandler.scheduleDueNotifications(taskService);

  return Future.value(true);
}

/// load new token from server to avoid expiration
Future<bool> refreshToken() async {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  var settingsDatasource = SettingsDatasource(storage);

  var token = await settingsDatasource.getUserToken();
  var base = await settingsDatasource.getServer();

  if (token == null || base == null) {
    return Future.value(true);
  }

  Client client = Client(base: base, token: token);

  var ignoreCertificates = await settingsDatasource.getIgnoreCertificates();
  client.setIgnoreCerts(ignoreCertificates);

  Response<String> newToken = await UserDataSource(client).getToken();
  if (newToken.isSuccessful) {
    settingsDatasource.saveUserToken(newToken.toSuccess().body);
  }
  return Future.value(true);
}
